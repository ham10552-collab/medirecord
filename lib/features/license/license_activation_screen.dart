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
  String _device = 'doctor'; // 'doctor' | 'secretary' | 'pharmacist' | 'lab'
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
    } else if (_device == 'pharmacist') {
      // The pharmacy works with ALL doctors in the system - the doctor
      // addresses are added later in the pharmacy screen (Manage doctors).
      setState(() { _activating = true; _message = ''; });
      final machineId = await DeviceIdentity.fingerprint();
      final result = await LicenseManager.activateSecondary(key, machineId);
      setState(() => _activating = false);
      if (!result.ok) {
        setState(() { _error = true; _message = result.message; });
        return;
      }
      setState(() => _message = result.message);
    } else if (_device == 'lab') {
      // Lab technician: activates locally exactly like the pharmacist -
      // no single doctor IP needed, the lab then pulls from ALL doctors
      // added in the Lab screen.
      setState(() { _activating = true; _message = ''; });
      final machineId = await DeviceIdentity.fingerprint();
      final result = await LicenseManager.activateSecondary(key, machineId);
      setState(() => _activating = false);
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
        onBack: () {
          if (context.canPop()) {
            Navigator.pop(context);
          } else {
            context.go('/role');
          }
        },
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
                    _deviceOption(
                      device: 'doctor',
                      icon: Icons.medical_services_outlined,
                      title: 'Doctor',
                      subtitle: 'Device 1 - main computer with the license key',
                    ),
                    const SizedBox(height: 8),
                    _deviceOption(
                      device: 'secretary',
                      icon: Icons.supervisor_account_outlined,
                      title: 'Secretary',
                      subtitle: 'Device 2 - connects to the doctor over the network',
                    ),
                    const SizedBox(height: 8),
                    _deviceOption(
                      device: 'pharmacist',
                      icon: Icons.local_pharmacy_outlined,
                      title: 'Pharmacist',
                      subtitle: 'Device 3 - connects to all doctors',
                    ),
                    const SizedBox(height: 8),
                    _deviceOption(
                      device: 'lab',
                      icon: Icons.science_outlined,
                      title: 'Lab Technician',
                      subtitle: 'Device 4 - connects to all doctors',
                    ),
                    if (_device == 'secretary') ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Enter the IP of the doctor that owns this license key. The seat is claimed once over the network (LAN/Wi-Fi); afterwards this machine works with the configured doctor PC.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
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
                    ] else if (_device == 'pharmacist' || _device == 'lab') ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.goldColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _device == 'pharmacist' ? Icons.local_pharmacy : Icons.biotech,
                              size: 18,
                              color: AppTheme.goldDeep,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _device == 'pharmacist'
                                    ? 'The pharmacy connects to all doctors - add each doctor IP later from the Pharmacy screen (Manage doctors).'
                                    : 'The lab connects to all doctors - no single doctor IP needed. Add each doctor later from the Lab screen (Manage doctors).',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                              ),
                            ),
                          ],
                        ),
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

  Widget _deviceOption({
    required String device,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _device == device;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _device = device),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.goldColor.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.goldColor : AppTheme.dividerColor,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.goldColor.withValues(alpha: 0.15)
                      : AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: selected ? AppTheme.goldDeep : AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.navy),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? AppTheme.goldDeep : AppTheme.dividerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}