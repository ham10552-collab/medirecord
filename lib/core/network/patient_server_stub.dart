import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ServerState { stopped, starting, running, error }

class PatientServer extends ChangeNotifier {
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
    _state = ServerState.stopped;
    notifyListeners();
  }

  Future<void> stop() async {
    _state = ServerState.stopped;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}

final patientServerProvider = ChangeNotifierProvider<PatientServer>((ref) {
  final server = PatientServer();
  ref.onDispose(() => server.dispose());
  return server;
});
