import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/app_storage.dart';
import '../../core/network/patient_client.dart';
import '../../shared/models/patient.dart';

class SecretaryScreen extends ConsumerStatefulWidget {
  const SecretaryScreen({super.key});

  @override
  ConsumerState<SecretaryScreen> createState() => _SecretaryScreenState();
}

class _SecretaryScreenState extends ConsumerState<SecretaryScreen> {
  String _firstName = '';
  String _lastName = '';
  String _phone = '';
  String _address = '';
  String _emergencyName = '';
  String _emergencyPhone = '';
  String _age = '';
  String _gender = 'Male';
  String? _bloodGroup;
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController();

  bool _connected = false;
  bool _checking = false;
  bool _sending = false;
  String _statusMsg = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final ip = await AppStorage.read('doctor_ip') ?? '';
    final port = await AppStorage.read('doctor_port') ?? '9876';
    if (mounted) {
      setState(() {
        _ipCtrl.text = ip;
        _portCtrl.text = port;
      });
    }
    if (ip.isNotEmpty) _testConnection();
  }

  Future<void> _saveSettings() async {
    await AppStorage.write('doctor_ip', _ipCtrl.text.trim());
    await AppStorage.write('doctor_port', _portCtrl.text.trim());
  }

  Future<void> _testConnection() async {
    final ip = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9876;
    if (ip.isEmpty) return;

    setState(() { _checking = true; _connected = false; _statusMsg = ''; });
    final result = await PatientClient.testConnection(ip, port);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _connected = result['status'] == 'ok';
      _statusMsg = _connected ? 'Connected' : 'Connection failed';
    });
    if (_connected) await _saveSettings();
  }

  Future<void> _sendPatient() async {
    final ip = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9876;
    if (ip.isEmpty) {
      setState(() => _statusMsg = 'Enter doctor IP address first');
      return;
    }

    setState(() { _sending = true; _statusMsg = ''; });

    final patient = Patient(
      id: const Uuid().v4(),
      firstName: _firstName.trim().isEmpty ? 'Unknown' : _firstName.trim(),
      lastName: _lastName.trim().isEmpty ? '' : _lastName.trim(),
      age: int.tryParse(_age) ?? 0,
      gender: _gender,
      phone: _phone.trim().isEmpty ? null : _phone.trim(),
      address: _address.trim().isEmpty ? null : _address.trim(),
      bloodGroup: _bloodGroup,
      emergencyContactName: _emergencyName.trim().isEmpty ? null : _emergencyName.trim(),
      emergencyContactPhone: _emergencyPhone.trim().isEmpty ? null : _emergencyPhone.trim(),
      photoUrl: null,
      createdBy: 'secretary',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    final result = await PatientClient.sendPatient(patient.toMap(), ip, port);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _statusMsg = result['status'] == 'ok' ? 'Patient sent successfully!' : 'Error: ${result['message']}';
    });

    if (result['status'] == 'ok') {
      setState(() {
        _firstName = '';
        _lastName = '';
        _phone = '';
        _address = '';
        _emergencyName = '';
        _emergencyPhone = '';
        _age = '';
        _gender = 'Male';
        _bloodGroup = null;
      });
    }
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediRecord - Secretary'),
        actions: [
          IconButton(
            icon: Icon(_connected ? Icons.wifi : Icons.wifi_off, color: _connected ? Colors.green : Colors.red),
            tooltip: _connected ? 'Connected' : 'Disconnected',
            onPressed: _testConnection,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Logout',
            onPressed: () async {
              await AppStorage.delete('medirecord_role');
              await AppStorage.delete('medirecord_licensed');
              await AppStorage.delete('medirecord_trial');
              if (context.mounted) context.go('/splash');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Doctor Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ipCtrl,
                            decoration: const InputDecoration(labelText: 'Doctor IP', hintText: '192.168.1.5', isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _portCtrl,
                            decoration: const InputDecoration(labelText: 'Port', isDense: true),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: _checking
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.wifi_find),
                          tooltip: 'Test connection',
                          onPressed: _checking ? null : _testConnection,
                        ),
                      ],
                    ),
                    if (_statusMsg.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_statusMsg,
                            style: TextStyle(fontSize: 12, color: _connected ? Colors.green : Colors.red)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Patient Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(
                  decoration: const InputDecoration(labelText: 'First Name', prefixIcon: Icon(Icons.person)),
                  onChanged: (v) => _firstName = v,
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  onChanged: (v) => _lastName = v,
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(
                  decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.cake)),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _age = v,
                )),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc)),
                    items: AppConstants.genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone)),
              keyboardType: TextInputType.phone,
              onChanged: (v) => _phone = v,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on)),
              maxLines: 2,
              onChanged: (v) => _address = v,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _bloodGroup,
              decoration: const InputDecoration(labelText: 'Blood Group', prefixIcon: Icon(Icons.bloodtype)),
              items: AppConstants.bloodGroups.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (v) => setState(() => _bloodGroup = v),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Emergency Contact Name', prefixIcon: Icon(Icons.emergency)),
              onChanged: (v) => _emergencyName = v,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Emergency Contact Phone'),
              keyboardType: TextInputType.phone,
              onChanged: (v) => _emergencyPhone = v,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _sendPatient,
                icon: _sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_sending ? 'Sending...' : 'Send to Doctor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _connected ? AppTheme.primaryColor : Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
