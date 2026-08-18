import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ServerState { stopped, starting, running, error }

class PatientServer extends ChangeNotifier {
  ServerState _state = ServerState.stopped;
  final String _error = '';
  final int _port = 9876;
  final String _ip = '';
  final String _lastPatientName = '';

  ServerState get state => _state;
  String get error => _error;
  int get port => _port;
  String get ip => _ip;
  String get lastPatientName => _lastPatientName;

  /// Required to match the real server API; the stub never stamps names.
  void setDoctorIdentity(String name) {}

  Future<void> start({int port = 9876}) async {
    _state = ServerState.stopped;
    notifyListeners();
  }

  Future<void> stop() async {
    _state = ServerState.stopped;
    notifyListeners();
  }
}

final patientServerProvider = ChangeNotifierProvider<PatientServer>((ref) {
  final server = PatientServer();
  ref.onDispose(() => server.dispose());
  return server;
});
