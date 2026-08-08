import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_helper.dart';
import '../license/license_manager.dart';
import '../license/device_fingerprint.dart';
import '../../shared/models/patient.dart';

enum ServerState { stopped, starting, running, error }

class PatientServer extends ChangeNotifier {
  HttpServer? _server;
  ServerState _state = ServerState.stopped;
  String _error = '';
  int _port = 9876;
  String _ip = '';
  String _lastPatientName = '';

  ServerState get state => _state;
  String get error => _error;
  int get port => _port;
  String get ip => _ip;
  String get lastPatientName => _lastPatientName;

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
