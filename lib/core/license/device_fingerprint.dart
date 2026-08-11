import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../utils/app_storage.dart';

/// Returns a stable device identifier for this installation.
///
/// On Windows desktop we read the machine's `MachineGuid` (unique per OS
/// install) and hash it together with a random per-install id, so even
/// computers that were duplicated from the same system image get different
/// device IDs. On other platforms / web we fall back to the stored random id.
class DeviceIdentity {
  static String? _cache;

  static Future<String> fingerprint() async {
    if (_cache != null) return _cache!;
    var installId = await AppStorage.read('medirecord_install_id');
    if (installId == null || installId.isEmpty) {
      final random = Random.secure();
      installId = 'inst-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}'
          '-${random.nextInt(0xFFFFFF).toRadixString(16)}';
      await AppStorage.write('medirecord_install_id', installId);
    }
    var raw = await _readMachineGuid();
    if (raw == null || raw.isEmpty) {
      raw = installId;
    }
    _cache = _hash('$raw|$installId');
    return _cache!;
  }

  static Future<String?> _readMachineGuid() async {
    if (kIsWeb) return null;
    if (!Platform.isWindows) return null;
    try {
      final result = await Process.run(
        'reg',
        const ['query', r'HKLM\SOFTWARE\Microsoft\Cryptography', '/v', 'MachineGuid'],
      );
      if (result.exitCode != 0) return null;
      final out = result.stdout.toString();
      final match = RegExp(r'\{?([0-9a-fA-F\-]{36})\}?').firstMatch(out);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  static String _hash(String input) {
    var len = input.length;
    var a = 0x811c9dc5;
    for (var i = 0; i < len; i++) {
      a ^= input.codeUnitAt(i);
      a = (a * 0x01000193) & 0xFFFFFFFF;
    }
    final hex = _toHex(a);
    return 'MD-${hex.substring(0, 4).toUpperCase()}-${hex.substring(4, 8).toUpperCase()}';
  }

  static String _toHex(int v) {
    final s = v.toRadixString(16).toUpperCase();
    return s.padLeft(8, '0');
  }

  /// Stable hash of the normalized license key (used to key binding records).
  static String keyHash(String normalizedKey) {
    final bytes = utf8.encode(normalizedKey);
    var hash = 0;
    for (final b in bytes) {
      hash = (hash * 31 + b) & 0x7FFFFFFF;
    }
    return hash.toRadixString(16).toUpperCase().padLeft(8, '0');
  }
}