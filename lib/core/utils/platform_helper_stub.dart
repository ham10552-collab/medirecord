import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';

class PlatformHelper {
  static Future<String> savePdf(Uint8List bytes, String fileName) async {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..target = '_blank'
      ..download = fileName;
    anchor.click();
    html.Url.revokeObjectUrl(url);
    return fileName;
  }

  static Future<void> openFile(String path) async {}

  static Future<String> saveImageBytes(Uint8List bytes, String id, String ext) async {
    final base64Str = base64Encode(bytes);
    return 'data:image/$ext;base64,$base64Str';
  }

  static Uint8List? loadImageBytes(String identifier) {
    if (identifier.startsWith('data:')) {
      final parts = identifier.split(',');
      if (parts.length > 1) return base64Decode(parts[1]);
    }
    return null;
  }

  static Future<String?> readCustomDrugs() async {
    return html.window.localStorage['custom_drugs_v2'];
  }

  static Future<void> writeCustomDrugs(String content) async {
    html.window.localStorage['custom_drugs_v2'] = content;
  }

  static Future<void> downloadBytes(Uint8List bytes, String fileName) async {
    final blob = html.Blob([bytes], 'application/octet-stream');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..target = '_blank'
      ..download = fileName;
    anchor.click();
    html.Url.revokeObjectUrl(url);
  }

  static Future<void> openWhatsApp(String number, String message) async {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final url = 'https://wa.me/$digits?text=${Uri.encodeComponent(message)}';
    html.window.open(url, '_blank');
  }
}
