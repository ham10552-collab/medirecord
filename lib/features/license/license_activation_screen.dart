import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/license_provider.dart';
import '../../core/license/license_manager.dart';
import '../../core/license/device_fingerprint.dart';
import '../../core/network/patient_client.dart';
import '../../core/utils/app_storage.dart';
import '../../shared/widgets/luxury_figures.dart';

class LicenseActivationScreen extends ConsumerStatefulWidget {
  const LicenseActivationScreen({super.key});

  @override
  ConsumerState<LicenseActivationScreen> createState() => _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends ConsumerState<LicenseActivationScreen> {
  final _keyCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  String _device = 'doctor'; // 'doctor' | 'secretary' | 'pharmacist'
  bool _error = false;
  String _message = '';
  bool _activating = false;
  String _machineId = '...';

  @override
  void initState() {
    super.initState();
    _portCtrl.text = '9876';
    _loadDoctorIp();
    DeviceIdentity.fingerprint().then((id) {
      if (mounted) setState(() => _machineId = id);
    });
  }

  Future<void> _loadDoctorIp() async {
    final ip = await AppStorage.read('doctor_ip') ?? '';
    final port = await AppStorage.read('doctor_port') ?? '9876';
    if (mounted) {
      _ipCtrl.text = ip;
      _portCtrl.text = port;
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _keyCtrl.text.trim();

    if (_device == 'doctor') {
      final result = await LicenseManager.activatePrimary(key);
      if (!result.ok) {
        setState(() { _error = true; _message = result.message; });
        return;
      }
      setState(() => _message = result.message);
    } else {
      // Secondary: request a seat from the doctor's install over LAN/Wi-Fi.
      final ip = _ipCtrl.text.trim();
      final port = int.tryParse(_portCtrl.text.trim()) ?? 9876;
      if (ip.isEmpty) {
        setState(() {
          _error = true;
          _message = 'Enter the Doctor app IP address (same network).';
        });
        return;
      }
      setState(() { _activating = true; _message = ''; });
      final machineId = await DeviceIdentity.fingerprint();
      final res = await PatientClient.requestSeat(key, machineId, ip, port);
      if (res['status'] != 'ok') {
        setState(() {
          _activating = false;
          _error = true;
          _message = 'Seat request failed. ${res['message'] ?? 'Doctor app unreachable.'}';
        });
        return;
      }
      final grantMachine = res['machineId']?.toString() ?? machineId;
      final result = await LicenseManager.activateSecondary(key, grantMachine);
      await AppStorage.write('doctor_ip', ip);
      await AppStorage.write('doctor_port', '$port');
      setState(() => _activating = false);
      if (!result.ok) {
        setState(() { _error = true; _message = result.message; });
        return;
      }
      setState(() => _message = result.message);
    }

    ref.read(licenseStatusProvider.notifier).state = LicenseStatus.licensed;
    if (!mounted) return;
    context.pushReplacement('/role');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LuxNavyBackdrop(
        showBack: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LuxBrandHeader(
                title: 'MediRecord',
                tagline: 'ACTIVATE YOUR LICENSE',
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.navy.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fingerprint, size: 18, color: AppTheme.goldColor),
                    const SizedBox(width: 8),
                    Text(
                      'Device ID: $_machineId',
                      style: const TextStyle(
                        color: AppTheme.champagneLight,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LuxuryCard(
                ornaments: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.vpn_key, size: 20, color: AppTheme.goldDeep),
                        SizedBox(width: 8),
                        Text(
                          'Enter License Key',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.navy),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Format: XXXXX-XXXXX-XXXXX-XXXXX',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _keyCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'XXXXX-XXXXX-XXXXX-XXXXX',
                        prefixIcon: const Icon(Icons.vpn_key),
                        errorText: _error ? (_message.isNotEmpty ? _message : 'Invalid license key') : null,
                      ),
                      onChanged: (_) => setState(() { _error = false; _message = ''; }),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Doctor\n(device 1)'),
                            selected: _device == 'doctor',
                            onSelected: (_) => setState(() => _device = 'doctor'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Secretary\n(device 2)'),
                            selected: _device == 'secretary',
                            onSelected: (_) => setState(() => _device = 'secretary'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Pharmacist\n(device 3)'),
                            selected: _device == 'pharmacist',
                            onSelected: (_) => setState(() => _device = 'pharmacist'),
                          ),
                        ),
                      ],
                    ),
                    if (_device != 'doctor') ...[
                      const SizedBox(height: 14),
                      Text(
                        'This device must be on the same network as the doctor app (LAN or Wi-Fi) to claim a seat.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _ipCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Doctor IP',
                                hintText: '192.168.1.10',
                                prefixIcon: const Icon(Icons.lan),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _portCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Port',
                                prefixIcon: Icon(Icons.numbers),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    GoldButton(
                      onPressed: _activating ? null : _activate,
                      child: _activating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navyDeep),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.verified_user, size: 19, color: AppTheme.navyDeep),
                                SizedBox(width: 8),
                                Text(
                                  'Activate',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.navyDeep,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (_message.isNotEmpty && !_error) ...[
                      const SizedBox(height: 10),
                      Text(
                        _message,
                        style: const TextStyle(color: AppTheme.successColor, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}