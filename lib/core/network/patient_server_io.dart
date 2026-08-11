import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../license/license_manager.dart';
import '../../shared/models/patient.dart';
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

      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _state = ServerState.running;
      notifyListeners();

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
          await recordIncomingAlert(patient.id, patient.fullName);
          notifyIncomingPatient(patient.fullName);
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
