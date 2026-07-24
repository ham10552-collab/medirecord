import 'package:local_auth/local_auth.dart';
import '../utils/app_storage.dart';

class BiometricAuth {
  final LocalAuthentication _localAuth;

  BiometricAuth({
    LocalAuthentication? localAuth,
  })  : _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access MediRecord',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final value = await AppStorage.read('biometric_enabled');
    return value == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await AppStorage.write('biometric_enabled', 'true');
    } else {
      await AppStorage.delete('biometric_enabled');
    }
  }

  String get biometricTypeName {
    return 'Biometric';
  }
}
