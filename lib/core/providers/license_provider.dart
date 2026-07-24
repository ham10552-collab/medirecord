import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LicenseStatus { uninitialized, trial, licensed }

final licenseStatusProvider = StateProvider<LicenseStatus>((ref) => LicenseStatus.uninitialized);
