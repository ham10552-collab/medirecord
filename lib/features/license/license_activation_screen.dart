import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/license_provider.dart';
import '../../core/utils/app_storage.dart';

class LicenseActivationScreen extends ConsumerStatefulWidget {
  const LicenseActivationScreen({super.key});

  @override
  ConsumerState<LicenseActivationScreen> createState() => _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends ConsumerState<LicenseActivationScreen> {
  final _keyCtrl = TextEditingController();
  bool _error = false;
  bool _activating = false;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  bool _isValidKey(String key) {
    final cleaned = key.trim().toUpperCase().replaceAll(' ', '').replaceAll('-', '');
    if (cleaned.length != 20) return false;
    if (!RegExp(r'^[A-Z0-9]{20}$').hasMatch(cleaned)) return false;
    int sum = 0;
    for (int i = 0; i < cleaned.length; i++) sum += cleaned.codeUnitAt(i);
    return sum % 7 == 0 && cleaned[4] == cleaned[9] && cleaned[14] == cleaned[19];
  }

  Future<void> _activate() async {
    final key = _keyCtrl.text.trim();
    if (!_isValidKey(key)) { setState(() => _error = true); return; }
    setState(() { _activating = true; _error = false; });
    try {
      await AppStorage.write('medirecord_licensed', 'true');
      ref.read(licenseStatusProvider.notifier).state = LicenseStatus.licensed;
      if (mounted) context.push('/role');
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activate License')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.vpn_key, size: 72, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              const Text('Enter License Key', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Format: XXXXX-XXXXX-XXXXX-XXXXX', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 24),
              TextField(
                controller: _keyCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'XXXXX-XXXXX-XXXXX-XXXXX',
                  prefixIcon: const Icon(Icons.vpn_key),
                  errorText: _error ? 'Invalid license key' : null,
                ),
                onChanged: (_) => setState(() => _error = false),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _activating ? null : _activate,
                  child: _activating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Activate'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
