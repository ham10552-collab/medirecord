class PatientClient {
  static Future<Map<String, dynamic>> testConnection(String ip, int port) async {
    return {'status': 'error', 'message': 'LAN client not available on web'};
  }

  static Future<Map<String, dynamic>> sendPatient(Map<String, dynamic> patientData, String ip, int port) async {
    return {'status': 'error', 'message': 'LAN client not available on web'};
  }
}
