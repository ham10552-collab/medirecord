import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../license/license_manager.dart';
import '../utils/app_storage.dart';
import '../../shared/models/patient.dart';
import 'lab_notifications.dart';
import 'pharmacy_notifications.dart';
import 'queue_status.dart';

enum ServerState { stopped, starting, running, error }

class PatientServer extends ChangeNotifier {
  HttpServer? _server;
  ServerState _state = ServerState.stopped;
  String _error = '';
  int _port = 9876;
  String _ip = '';
  String _lastPatientName = '';
  String _doctorIdentity = '';

  ServerState get state => _state;
  String get error => _error;
  int get port => _port;
  String get ip => _ip;
  String get lastPatientName => _lastPatientName;

  /// Opens TCP 9876 in Windows Firewall once so the pharmacy/secretary PCs
  /// can always reach this doctor over the LAN. Uses an elevated PowerShell
  /// one-liner (same pattern as the fixed-IP tool). Only runs on the first
  /// start so the buyer is not asked twice.
  Future<void> _ensureFirewallRule() async {
    try {
      final done = await AppStorage.read('firewall_9876_opened');
      if (done == 'true') return;
      if (await _firewallRulePresent()) {
        await AppStorage.write('firewall_9876_opened', 'true');
        return;
      }
      const cmd = 'netsh advfirewall firewall add rule '
          'name="MediRecord LAN (9876)" dir=in action=allow '
          'protocol=TCP localport=9876 profile=private,domain';
      final encoded = base64Encode(_utf16Le(cmd));
      await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Start-Process powershell -Verb RunAs -ArgumentList '
              "'-NoProfile','-EncodedCommand','$encoded' -Wait",
        ],
      );
      // Only mark as done when the rule really exists, so a refused admin
      // prompt never silently disables the firewall prompt for good.
      if (await _firewallRulePresent()) {
        await AppStorage.write('firewall_9876_opened', 'true');
      }
    } catch (_) {
      // If elevation is refused, the app still runs - the network just needs
      // the manual one-time firewall prompt accepted on first start.
    }
  }

  static Future<bool> _firewallRulePresent() async {
    try {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "if (Get-NetFirewallRule -DisplayName 'MediRecord LAN (9876)' "
            "-ErrorAction SilentlyContinue) { 'True' } else { 'False' }",
      ]);
      return r.exitCode == 0 && (r.stdout as String).trim() == 'True';
    } catch (_) {
      return false;
    }
  }

  static List<int> _utf16Le(String s) {
    final bytes = <int>[];
    for (final unit in s.codeUnits) {
      bytes.add(unit & 0xFF);
      bytes.add((unit >> 8) & 0xFF);
    }
    return bytes;
  }

  /// The logged-in doctor's name, stamped onto prescriptions that have no
  /// real doctor name so the pharmacy never sees 'Unknown'.
  void setDoctorIdentity(String name) => _doctorIdentity = name;

  Future<void> start({int port = 9876}) async {
    if (_state == ServerState.running) return;
    _port = port;
    _state = ServerState.starting;
    _error = '';
    notifyListeners();

    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            _ip = addr.address;
            break;
          }
        }
        if (_ip.isNotEmpty) break;
      }
      if (_ip.isEmpty) _ip = '127.0.0.1';

      final fixed = (await AppStorage.read('machine_fixed_ip') ?? '').trim();
      if (fixed.isNotEmpty &&
          fixed != '127.0.0.1' &&
          _ip.isNotEmpty &&
          _ip != '127.0.0.1') {
        _ip = fixed;
      }

      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _state = ServerState.running;
      notifyListeners();
      _ensureFirewallRule();

      await for (final request in _server!) {
        _handleRequest(request);
      }
    } catch (e) {
      _state = ServerState.error;
      _error = e.toString();
      notifyListeners();
    }
  }

  void _handleRequest(HttpRequest request) {
    final uri = request.uri.path;
    final method = request.method;

    if (method == 'GET' && uri == '/api/health') {
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(json.encode({'status': 'ok', 'message': 'MediRecord server running'}));
      request.response.close();
      return;
    }

    // Secondary (secretary) devices request a license seat from the primary
    // doctor over this channel. Works identically over LAN or Wi-Fi.
    if (method == 'POST' && uri == '/api/license/seat') {
      request.response.headers.contentType = ContentType.json;
      utf8.decodeStream(request).then((body) async {
        try {
          final data = json.decode(body) as Map<String, dynamic>;
          final key = data['key'] as String? ?? '';
          final machineId = data['machineId'] as String? ?? '';
          final result = await LicenseManager.grantSeat(
            key: key,
            requestingMachineId: machineId,
          );
          request.response.statusCode = result.ok ? 200 : 403;
          request.response.write(json.encode({
            'status': result.ok ? 'ok' : 'error',
            'message': result.message,
            'seats': await LicenseManager.currentSeats(),
          }));
        } catch (e) {
          request.response.statusCode = 400;
          request.response.write(json.encode({'status': 'error', 'message': e.toString()}));
        }
        request.response.close();
      });
      return;
    }

    if (method == 'POST' && uri == '/api/patient') {
      request.response.headers.contentType = ContentType.json;
      utf8.decodeStream(request).then((body) async {
        try {
          final data = json.decode(body) as Map<String, dynamic>;
          final patient = Patient.fromMap(data);
          final existing = await DatabaseHelper().getPatient(patient.id);
          final isFollowUp = existing != null;
          final inserted = await DatabaseHelper().insertPatient(patient);
          if (inserted == 0) {
            request.response.statusCode = 403;
            request.response.write(json.encode({
              'status': 'error',
              'message': 'Trial patient limit reached. Activate a license first.',
            }));
            request.response.close();
            return;
          }
          _lastPatientName = patient.fullName;
          notifyListeners();
          await recordIncomingAlert(
            patient.id,
            patient.fullName,
            type: isFollowUp ? 'followup' : 'new',
          );
          notifyIncomingPatient(
            patient.fullName,
            type: isFollowUp ? 'followup' : 'new',
          );
          await QueueStatus.setStatus(patient.id, QueueStatus.statusWaiting);
          request.response.statusCode = 201;
          request.response.write(json.encode({'status': 'ok', 'message': 'Patient saved'}));
        } catch (e) {
          request.response.statusCode = 400;
          request.response.write(json.encode({'status': 'error', 'message': e.toString()}));
        }
        request.response.close();
      });
      return;
    }

    // Secretary waiting room: the doctor's queue statuses. The secretary
    // polls this; status changes light up the waiting-room list there.
    if (method == 'GET' && uri == '/api/queue/status') {
      request.response.headers.contentType = ContentType.json;
      DatabaseHelper().getAllPatients().then((patients) async {
        final names = {for (final p in patients) p.id: p.fullName};
        final payload = await QueueStatus.buildStatusResponse(names);
        request.response.statusCode = 200;
        request.response.write(json.encode(payload));
        request.response.close();
      }).catchError((e) {
        request.response.statusCode = 500;
        request.response.write(json.encode({}));
        request.response.close();
      });
      return;
    }

    // The doctor machine marks where a visit is (with the doctor / done).
    if (method == 'POST' && uri == '/api/queue/status') {
      request.response.headers.contentType = ContentType.json;
      utf8.decodeStream(request).then((body) async {
        try {
          final data = json.decode(body) as Map<String, dynamic>;
          await QueueStatus.setStatus(
            data['patientId'] as String? ?? '',
            data['status'] as String? ?? QueueStatus.statusWithDoctor,
          );
          request.response.statusCode = 200;
          request.response.write(json.encode({'status': 'ok'}));
        } catch (e) {
          request.response.statusCode = 400;
          request.response.write(json.encode({'status': 'error', 'message': e.toString()}));
        }
        request.response.close();
      });
      return;
    }

    // Pharmacy queue: the pharmacist device pulls prescriptions sent by the
    // doctor. This also powers the doctor's own Pharmacy tab.
    if (method == 'GET' && uri == '/api/pharmacy/prescriptions') {
      request.response.headers.contentType = ContentType.json;
      final host = '$_ip:$_port';
      DatabaseHelper().getPharmacyQueue().then((queue) {
        for (final rx in queue) {
          rx['doctor_host'] = host;
          final rawDoctor = (rx['doctor_name'] as String? ?? '').trim();
          if ((rawDoctor.isEmpty || rawDoctor == 'Unknown') && _doctorIdentity.isNotEmpty) {
            rx['doctor_name'] = _doctorIdentity;
          }
        }
        request.response.statusCode = 200;
        request.response.write(json.encode(queue));
        request.response.close();
      }).catchError((e) {
        request.response.statusCode = 400;
        request.response.write(json.encode({'status': 'error', 'message': e.toString()}));
        request.response.close();
      });
      return;
    }

    // Pharmacist marks a prescription as dispensed (updates the doctor DB too).
    if (method == 'POST' && uri == '/api/pharmacy/dispense') {
      request.response.headers.contentType = ContentType.json;
      utf8.decodeStream(request).then((body) async {
        try {
          final data = json.decode(body) as Map<String, dynamic>;
          final id = data['id'] as String? ?? '';
          final dispensedBy = data['dispensedBy'] as String? ?? 'Pharmacist';
          final result = await DatabaseHelper().updatePrescriptionStatus(
            id,
            status: 'dispensed',
            dispensedBy: dispensedBy,
            dispensedAt: DateTime.now().toIso8601String(),
          );
          request.response.statusCode = result > 0 ? 200 : 404;
          request.response.write(json.encode({'status': result > 0 ? 'ok' : 'error'}));
        } catch (e) {
          request.response.statusCode = 400;
          request.response.write(json.encode({'status': 'error', 'message': e.toString()}));
        }
        request.response.close();
      });
      return;
    }

    // Back to pending (undo dispense).
    if (method == 'POST' && uri == '/api/pharmacy/pending') {
      request.response.headers.contentType = ContentType.json;
      utf8.decodeStream(request).then((body) async {
        try {
          final data = json.decode(body) as Map<String, dynamic>;
          final id = data['id'] as String? ?? '';
          final result = await DatabaseHelper().updatePrescriptionStatus(id, status: 'pending');
          request.response.statusCode = result > 0 ? 200 : 404;
          request.response.write(json.encode({'status': result > 0 ? 'ok' : 'error'}));
        } catch (e) {
          request.response.statusCode = 400;
          request.response.write(json.encode({'status': 'error', 'message': e.toString()}));
        }
        request.response.close();
      });
      return;
    }

    // Lab queue: the lab device pulls pending lab requests ordered by the
    // doctor. Same pattern as the pharmacy queue.
    if (method == 'GET' && uri == '/api/lab/tests') {
      request.response.headers.contentType = ContentType.json;
      final host = '$_ip:$_port';
      DatabaseHelper().getLabQueue().then((queue) async {
        for (final r in queue) {
          r['doctor_host'] = host;
          final rawDoctor = (r['doctor_name'] as String? ?? '').trim();
          if ((rawDoctor.isEmpty || rawDoctor == 'Unknown') && _doctorIdentity.isNotEmpty) {
            r['doctor_name'] = _doctorIdentity;
          }
        }
        request.response.statusCode = 200;
        request.response.write(json.encode(queue));
        request.response.close();
      }).catchError((e) {
        request.response.statusCode = 400;
        request.response.write(json.encode({'status': 'error', 'message': e.toString()}));
        request.response.close();
      });
      return;
    }

    // The lab returns completed results to the requesting doctor. The
    // request object is stored as-is so patient data stays consistent.
    if (method == 'POST' && uri == '/api/lab/result') {
      request.response.headers.contentType = ContentType.json;
      utf8.decodeStream(request).then((body) async {
        try {
          final data = json.decode(body) as Map<String, dynamic>;
          final id = data['id'] as String? ?? '';
          final status = data['status'] as String? ?? 'completed';
          final result = await DatabaseHelper().completeLabRequest(
            id,
            request: {...data, 'status': status},
          );
          if (result > 0 && status == 'completed') {
            notifyLabResult(data);
          }
          request.response.statusCode = result > 0 ? 200 : 404;
          request.response.write(json.encode({'status': result > 0 ? 'ok' : 'error'}));
        } catch (e) {
          request.response.statusCode = 400;
          request.response.write(json.encode({'status': 'error', 'message': e.toString()}));
        }
        request.response.close();
      });
      return;
    }

    request.response.statusCode = 404;
    request.response.write('Not found');
    request.response.close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _state = ServerState.stopped;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

final patientServerProvider = ChangeNotifierProvider<PatientServer>((ref) {
  final server = PatientServer();
  ref.onDispose(() => server.dispose());
  return server;
});
