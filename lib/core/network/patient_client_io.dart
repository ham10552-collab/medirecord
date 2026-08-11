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

  static String? _extractError(dynamic e) {
    final s = e.toString();
    final start = s.indexOf('message: ');
    if (start < 0) return s;
    final end = s.indexOf('}', start);
    return s.substring(start + 9, end < 0 ? s.length : end).trim();
  }

  /// Fetches the pharmacy queue from the doctor's install.
  static Future<(List<dynamic>, String?)> fetchPharmacy(String ip, int port, {int timeoutSec = 8}) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: timeoutSec);
      final request = await client.getUrl(Uri.parse('http://$ip:$port/api/pharmacy/prescriptions'));
      final response = await request.close();
      final body = await response.cast<List<int>>().transform(utf8.decoder).join();
      client.close();
      if (response.statusCode != 200) {
        return (const [], 'Response ${response.statusCode}');
      }
      final decoded = json.decode(body);
      if (decoded is List) return (decoded, null);
      return (const [], 'Unexpected response');
    } catch (e) {
      return (const [], _extractError(e) ?? 'Could not reach the doctor app');
    }
  }

  /// Sends a dispense action back to the doctor's install.
  static Future<Map<String, dynamic>> pharmacyAction(
    String id,
    String action,
    String who,
    String ip,
    int port,
  ) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.postUrl(
        Uri.parse('http://$ip:$port/api/pharmacy/$action'),
      );
      request.headers.contentType = ContentType.json;
      request.write(json.encode({'id': id, 'dispensedBy': who}));
      final response = await request.close();
      final body = await response.cast<List<int>>().transform(utf8.decoder).join();
      client.close();
      final decoded = json.decode(body) as Map<String, dynamic>;
      return {'status': response.statusCode == 200 ? 'ok' : 'error', ...decoded};
    } catch (e) {
      return {'status': 'error', 'message': 'Could not reach the doctor app over the network: $e'};
    }
  }

  /// Fetches the doctor's queue statuses (waiting / with doctor / done) for
  /// the patients the secretary sent. Returns null when the doctor PC cannot
  /// be reached, an (possibly empty) map on success.
  static Future<Map<String, dynamic>?> fetchQueueStatus(String ip, int port) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final request = await client.getUrl(Uri.parse('http://$ip:$port/api/queue/status'));
      final response = await request.close();
      final body = await response.cast<List<int>>().transform(utf8.decoder).join();
      client.close();
      if (response.statusCode != 200) return null;
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return null;
    }
  }
}
