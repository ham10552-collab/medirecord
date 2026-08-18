class PatientClient {
  static Future<Map<String, dynamic>> testConnection(String ip, int port) async {
    return {'status': 'error', 'message': 'LAN client not available on web'};
  }

  static Future<Map<String, dynamic>> sendPatient(Map<String, dynamic> patientData, String ip, int port) async {
    return {'status': 'error', 'message': 'LAN client not available on web'};
  }

  static Future<Map<String, dynamic>> requestSeat(String key, String machineId, String ip, int port) async {
    return {'status': 'error', 'message': 'LAN client not available on web'};
  }

  static Future<(List<dynamic>, String?)> fetchPharmacy(String ip, int port, {int timeoutSec = 8}) async {
    return (const [], 'LAN client not available on web');
  }

  static Future<Map<String, dynamic>> pharmacyAction(String id, String action, String who, String ip, int port) async {
    return {'status': 'error', 'message': 'LAN client not available on web'};
  }

  static Future<Map<String, dynamic>?> fetchQueueStatus(String ip, int port) async {
    return null;
  }

  static Future<(List<dynamic>, String?)> fetchLabTests(String ip, int port,
      {int timeoutSec = 8}) async {
    return (const [], 'LAN client not available on web');
  }

  static Future<Map<String, dynamic>> sendLabResult(
      Map<String, dynamic> request, String ip, int port) async {
    return {'status': 'error', 'message': 'LAN client not available on web'};
  }
}
