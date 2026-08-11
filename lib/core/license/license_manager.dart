import 'dart:convert';
import '../utils/app_storage.dart';
import '../utils/constants.dart';
import 'device_fingerprint.dart';

/// Result of attempting to activate a license key.
class ActivationResult {
  final bool ok;
  final String message;

  const ActivationResult.ok(this.message) : ok = true;
  const ActivationResult.fail(this.message) : ok = false;
}

/// License state persisted on this device.
class LicenseRecord {
  final String keyHash;
  final String machineId;
  final DateTime activatedAt;
  final List<String> seats;

  const LicenseRecord({
    required this.keyHash,
    required this.machineId,
    required this.activatedAt,
    required this.seats,
  });

  Map<String, dynamic> toJson() => {
        'keyHash': keyHash,
        'machineId': machineId,
        'activatedAt': activatedAt.toIso8601String(),
        'seats': seats,
      };

  static LicenseRecord fromJson(Map<String, dynamic> json) => LicenseRecord(
        keyHash: json['keyHash'] as String,
        machineId: json['machineId'] as String,
        activatedAt: DateTime.tryParse(json['activatedAt'] as String? ?? '') ??
            DateTime.now(),
        seats: (json['seats'] as List? ?? const []).cast<String>(),
      );
}

/// Central licensing service.
///
/// A license key (legacy 20-char format, keeping the stock you already
/// printed) is *bound to its activation device*. This device's license lives
/// in OS-protected storage (not inside the portable app folder), so copying
/// the folder to another PC does not carry the license.
///
/// Seat model:
///  - The first device that activates a key is its PRIMARY (doctor). It binds
///    seat #1 with no network requirement.
///  - The clinic's secretary device requests the key's remaining seat from the
///    primary over the existing HTTP channel (works over LAN or Wi-Fi). The
///    primary grants a seat only up to 3 machines total (doctor + secretary +
///    pharmacist).
///  - All roles on a given machine share that machine's license.
class LicenseManager {
  LicenseManager._();

  static const _recordKey = 'medirecord_license';

  /// True if the key passes the legacy MediRecord checksum format.
  static bool isValidKey(String key) {
    final cleaned = normalizeKey(key);
    if (cleaned.length != 20) return false;
    if (!RegExp(r'^[A-Z0-9]{20}$').hasMatch(cleaned)) return false;
    var sum = 0;
    for (var i = 0; i < cleaned.length; i++) {
      sum += cleaned.codeUnitAt(i);
    }
    return sum % 7 == 0 &&
        cleaned[4] == cleaned[9] &&
        cleaned[14] == cleaned[19];
  }

  static String normalizeKey(String key) {
    return key.trim().toUpperCase().replaceAll(' ', '').replaceAll('-', '');
  }

  static Future<LicenseRecord?> readRecord() async {
    final raw = await AppStorage.read(_recordKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return LicenseRecord.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isLicensedOnDevice() async {
    // Legacy installs that were already activated keep working.
    final legacy = await AppStorage.read('medirecord_licensed');
    if (legacy == 'true') return true;
    return (await readRecord()) != null;
  }

  /// Activates as the key's PRIMARY device (doctor). No network required.
  /// Binds seat #1 to this machine.
  static Future<ActivationResult> activatePrimary(String key) async {
    final cleaned = normalizeKey(key);
    if (!isValidKey(cleaned)) {
      return const ActivationResult.fail(
          'Invalid license key. Check the key and try again.');
    }
    final machineId = await DeviceIdentity.fingerprint();
    final hash = DeviceIdentity.keyHash(cleaned);

    final existing = await readRecord();
    if (existing != null && existing.machineId == machineId) {
      return const ActivationResult.ok('License already active on this device');
    }
    if (existing != null && !existing.seats.contains(machineId)) {
      // Device changed while the key was bound elsewhere on this install.
    }

    final record = LicenseRecord(
      keyHash: hash,
      machineId: machineId,
      activatedAt: DateTime.now(),
      seats: existing == null
          ? [machineId]
          : (existing.seats.contains(machineId)
              ? existing.seats
              : [...existing.seats, machineId]),
    );
    await AppStorage.write(_recordKey, json.encode(record.toJson()));
    await AppStorage.write('medirecord_licensed', 'true');
    return const ActivationResult.ok('License activated');
  }

  /// Secondary (secretary) seat grant. The primary's server validated this
  /// key on the doctor's install and authorized this machine's seat, so we
  /// persist the grant here.
  static Future<ActivationResult> activateSecondary(
    String key,
    String grantedMachineId,
  ) async {
    final cleaned = normalizeKey(key);
    if (!isValidKey(cleaned)) {
      return const ActivationResult.fail(
          'Invalid license key. Check the key and try again.');
    }
    final machineId = await DeviceIdentity.fingerprint();
    final hash = DeviceIdentity.keyHash(cleaned);
    final record = LicenseRecord(
      keyHash: hash,
      machineId: machineId,
      activatedAt: DateTime.now(),
      seats: [machineId],
    );
    await AppStorage.write(_recordKey, json.encode(record.toJson()));
    await AppStorage.write('medirecord_licensed', 'true');
    return const ActivationResult.ok('License activated (second seat)');
  }

  /// Server-side authorization for a secondary device.
  /// The doctor's install calls this when a secretary requests a seat.
  /// The requesting key must be the same key this device is bound to, and the
  /// key is not honored unless this device holds an active license.
  static Future<ActivationResult> grantSeat({
    required String key,
    required String requestingMachineId,
  }) async {
    final cleaned = normalizeKey(key);
    if (!isValidKey(cleaned)) {
      return const ActivationResult.fail('Invalid license key.');
    }
    final primary = await readRecord();
    final legacyLicensed = await AppStorage.read('medirecord_licensed');
    final deviceLicensed = legacyLicensed == 'true' || primary != null;
    if (!deviceLicensed) {
      return const ActivationResult.fail(
          'This device is not the primary licensee for that key.');
    }

    final machineId = await DeviceIdentity.fingerprint();

    // The requesting key must be the same key this primary device is bound to.
    if (primary != null && primary.keyHash != DeviceIdentity.keyHash(cleaned)) {
      return const ActivationResult.fail(
          'This license key does not match the key active on this device.');
    }

    // Legacy primary installs (activated before this build) have no seat
    // record yet. Seal the key onto this device so seats can be tracked.
    if (primary == null) {
      final record = LicenseRecord(
        keyHash: DeviceIdentity.keyHash(cleaned),
        machineId: machineId,
        activatedAt: DateTime.now(),
        seats: [machineId, requestingMachineId],
      );
      await AppStorage.write(_recordKey, json.encode(record.toJson()));
      await AppStorage.write('medirecord_licensed', 'true');
      return const ActivationResult.ok('Seat granted');
    }

    final seats = List<String>.from(primary.seats);
    if (seats.contains(requestingMachineId)) {
      return const ActivationResult.ok('Seat already granted');
    }

    if (seats.length >= AppConstants.maxLicenseSeats) {
      return const ActivationResult.fail(
          'License seats exhausted (maximum 3 machines per key).');
    }

    seats.add(requestingMachineId);
    final updated = LicenseRecord(
      keyHash: primary.keyHash,
      machineId: primary.machineId,
      activatedAt: primary.activatedAt,
      seats: seats,
    );
    await AppStorage.write(_recordKey, json.encode(updated.toJson()));
    return const ActivationResult.ok('Seat granted');
  }

  /// Number of seats currently bound to the key on this device.
  static Future<List<String>> currentSeats() async {
    final record = await readRecord();
    if (record == null) return [];
    return List<String>.from(record.seats);
  }
}