import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_storage.dart';

class LicenseScreen extends StatefulWidget {
  final Widget child;

  const LicenseScreen({super.key, required this.child});

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _keyCtrl = TextEditingController();
  bool _checking = true;
  bool _isLicensed = false;
  bool _error = false;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    try {
      final activated = await AppStorage.read('medirecord_licensed');
      if (activated == 'true') {
        setState(() => _isLicensed = true);
      }
    } catch (_) {}
    setState(() => _checking = false);
  }

  bool _isValidKey(String key) {
    final cleaned = key.trim().toUpperCase().replaceAll(' ', '');
    if (cleaned.length != 20) return false;
    if (!RegExp(r'^[A-Z0-9]{20}$').hasMatch(cleaned)) return false;

    int sum = 0;
    for (int i = 0; i < cleaned.length; i++) {
      sum += cleaned.codeUnitAt(i);
    }
    return sum % 7 == 0 && cleaned[4] == cleaned[9] && cleaned[14] == cleaned[19];
  }

  Future<void> _activate() async {
    final key = _keyCtrl.text.trim();
    if (!_isValidKey(key)) {
      setState(() => _error = true);
      return;
    }
    setState(() { _activating = true; _error = false; });
    try {
      await AppStorage.write('medirecord_licensed', 'true');
      setState(() => _isLicensed = true);
    } catch (_) {
      setState(() => _error = true);
    } finally {
      setState(() => _activating = false);
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isLicensed) return widget.child;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.medical_services, size: 72, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              const Text('MediRecord', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Patient Medical Records System', style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 40),
              const Text('Enter License Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Format: XXXXX-XXXXX-XXXXX-XXXXX', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 20),
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
