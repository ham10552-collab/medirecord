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
}
