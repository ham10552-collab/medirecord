import 'dart:convert';
import 'dart:io';

class PatientClient {
  static Future<Map<String, dynamic>> testConnection(String ip, int port) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse('http://$ip:$port/api/health'));
      final response = await request.close();
      final body = await response.cast<List<int>>().transform(utf8.decoder).join();
      client.close();
      return json.decode(body) as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sendPatient(Map<String, dynamic> patientData, String ip, int port) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.postUrl(Uri.parse('http://$ip:$port/api/patient'));
      request.headers.contentType = ContentType.json;
      request.write(json.encode(patientData));
      final response = await request.close();
      final body = await response.cast<List<int>>().transform(utf8.decoder).join();
      client.close();
      return json.decode(body) as Map<String, dynamic>;
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Requests a license seat from the primary (doctor) device over the
  /// existing HTTP channel. Works over LAN or Wi-Fi identically.
  static Future<Map<String, dynamic>> requestSeat(
    String key,
    String machineId,
    String ip,
    int port,
  ) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.postUrl(Uri.parse('http://$ip:$port/api/license/seat'));
      request.headers.contentType = ContentType.json;
      request.write(
        json.encode({'key': key, 'machineId': machineId}),
      );
      final response = await request.close();
      final body = await response.cast<List<int>>().transform(utf8.decoder).join();
      client.close();
      final decoded = json.decode(body) as Map<String, dynamic>;
      return {'status': response.statusCode == 200 ? 'ok' : 'error', ...decoded};
    } catch (e) {
      return {'status': 'error', 'message': 'Could not reach the doctor app over the network: $e'};
    }
  }
}
