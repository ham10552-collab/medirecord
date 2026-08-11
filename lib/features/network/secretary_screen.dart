import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:file_selector/file_selector.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/app_storage.dart';
import '../../core/providers/license_provider.dart';
import '../../core/network/patient_client.dart';
import '../../core/network/patient_server.dart';
import '../../core/network/queue_status.dart';
import '../../core/network/pharmacy_notifications.dart';
import '../../core/database/database_helper.dart';
import '../../shared/models/patient.dart';
import '../../shared/widgets/patient_card.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/luxury_figures.dart';

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
  final _searchReturningCtrl = TextEditingController();

  bool _connected = false;
  bool _checking = false;
  bool _sending = false;
  String _statusMsg = '';
  bool _isFollowUp = false;
  Patient? _selectedReturningPatient;

  List<Patient> _localPatients = [];
  List<Patient> _filteredPatients = [];
  List<Patient> _returningSearchResults = [];
  bool _loadingPatients = true;
  String _searchQuery = '';
  bool _showForm = true;

  final List<Map<String, dynamic>> _queueEntries = [];
  final Map<String, Map<String, dynamic>> _queueStatus = {};
  Timer? _queueTimer;
  bool _showQueue = false;
  bool _queueOffline = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPatients();
    _loadQueue();
    _queueTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollQueue());
  }

  Future<void> _loadQueue() async {
    final entries = await QueueStatus.readSecretaryQueue();
    if (mounted) setState(() {
      _queueEntries
        ..clear()
        ..addAll(entries);
    });
  }

  Future<void> _pollQueue() async {
    final ip = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9876;
    final statuses = <String, dynamic>{};
    bool networkFailed = false;
    if (ip.isNotEmpty) {
      final fetched = await PatientClient.fetchQueueStatus(ip, port);
      networkFailed = fetched == null;
      if (fetched != null) statuses.addAll(fetched);
    }

    // When the doctor server runs on this same machine (trial on one PC),
    // merge its statuses locally so the waiting room stays live.
    final localServer = ref.read(patientServerProvider);
    if (localServer.state == ServerState.running) {
      final local = await QueueStatus.readDoctorQueue();
      local.forEach((id, entry) {
        statuses[id] = {
          'name': _queueEntries
                  .where((e) => (e['id'] as String? ?? '') == id)
                  .map((e) => e['name'] ?? '')
                  .firstOrNull ??
              '',
          'status': entry['status'] ?? QueueStatus.statusWaiting,
          'at': entry['at'] ?? '',
        };
      });
    }

    if (!mounted) return;
    if (networkFailed && statuses.isEmpty) {
      if (_queueEntries.isNotEmpty) {
        setState(() => _queueOffline = true);
      }
      return;
    }
    setState(() {
      _queueOffline = networkFailed && statuses.isEmpty;
      statuses.forEach((id, entry) {
        final map = (entry as Map).cast<String, dynamic>();
        final status = map['status'] as String? ?? QueueStatus.statusWaiting;
        final prev = _queueStatus[id];
        final notifyOn = prev != null && prev['status'] != status &&
            (status == QueueStatus.statusWithDoctor || status == QueueStatus.statusDone);
        if (notifyOn) {
          final name = map['name'] as String? ?? '';
          notifySecretaryStatus(id, name.isEmpty ? 'Patient' : name, status);
        }
        _queueStatus[id] = {'status': status, 'at': map['at'] ?? ''};
      });
      // Patients not in the doctor's status list yet are still "waiting".
      for (final e in _queueEntries) {
        _queueStatus.putIfAbsent(e['id'] as String, () => {'status': QueueStatus.statusWaiting, 'at': ''});
      }
    });
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

  Future<void> _loadPatients() async {
    if (!mounted) return;
    setState(() => _loadingPatients = true);
    try {
      final patients = await DatabaseHelper().getAllPatients();
      if (!mounted) return;
      setState(() {
        _localPatients = patients;
        _filteredPatients = _searchQuery.isEmpty ? List.from(patients) : _filteredPatients;
        _loadingPatients = false;
      });
      if (_searchQuery.isNotEmpty) _onSearchChanged(_searchQuery);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPatients = false);
    }
  }

  void _onSearchChanged(String value) {
    if (!mounted) return;
    final q = value.toLowerCase();
    setState(() {
      _searchQuery = value;
      _filteredPatients = q.isEmpty
          ? List.from(_localPatients)
          : _localPatients.where((p) =>
              p.firstName.toLowerCase().contains(q) ||
              p.lastName.toLowerCase().contains(q) ||
              (p.phone?.toLowerCase().contains(q) ?? false)).toList();
    });
  }

  void _onReturningSearchChanged(String value) {
    final q = value.toLowerCase();
    setState(() {
      _returningSearchResults = q.isEmpty
          ? []
          : _localPatients.where((p) =>
              p.firstName.toLowerCase().contains(q) ||
              p.lastName.toLowerCase().contains(q) ||
              (p.phone?.toLowerCase().contains(q) ?? false)).take(10).toList();
    });
  }

  void _selectReturningPatient(Patient patient) {
    setState(() {
      _selectedReturningPatient = patient;
      _firstName = patient.firstName;
      _lastName = patient.lastName;
      _phone = patient.phone ?? '';
      _address = patient.address ?? '';
      _emergencyName = patient.emergencyContactName ?? '';
      _emergencyPhone = patient.emergencyContactPhone ?? '';
      _age = patient.age.toString();
      _gender = patient.gender;
      _bloodGroup = patient.bloodGroup;
      _isFollowUp = true;
      _returningSearchResults = [];
      _searchReturningCtrl.text = '${patient.fullName} (${patient.phone ?? patient.age.toString()})';
    });
  }

  Future<void> _savePatientLocally() async {
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

    final inserted = await DatabaseHelper().insertPatient(patient);
    if (inserted == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trial limit reached (70 patients). Activate a license to continue.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }
    await _loadPatients();
    _clearForm();

    if (!mounted) return;

    final dir = await getDirectoryPath(
      confirmButtonText: 'Save Here',
    );

    if (dir != null) {
      try {
        final fileName = '${patient.fullName.replaceAll(' ', '_')}_${patient.id.substring(0, 8)}.json';
        final filePath = '$dir\\$fileName';
        await File(filePath).writeAsString(const JsonEncoder.withIndent('  ').convert(patient.toMap()));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Patient saved to $filePath')),
          );
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save file: $e'), backgroundColor: AppTheme.errorColor),
          );
        }
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient saved locally'), backgroundColor: Colors.green),
      );
    }
  }

  void _clearForm() {
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
      _isFollowUp = false;
      _selectedReturningPatient = null;
      _searchReturningCtrl.text = '';
      _returningSearchResults = [];
    });
  }

  Map<String, dynamic> _buildPatientData() {
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
    final data = patient.toMap();
    data['visit_type'] = _isFollowUp ? 'follow_up' : 'first_visit';
    if (_selectedReturningPatient != null) {
      data['original_patient_id'] = _selectedReturningPatient!.id;
    }
    return data;
  }

  Future<void> _sendPatient() async {
    final ip = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9876;
    if (ip.isEmpty) {
      setState(() => _statusMsg = 'Enter doctor IP address first');
      return;
    }

    setState(() { _sending = true; _statusMsg = ''; });
    final data = _buildPatientData();
    final result = await PatientClient.sendPatient(data, ip, port);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _statusMsg = result['status'] == 'ok' ? 'Patient sent successfully!' : 'Error: ${result['message']}';
    });

    if (result['status'] == 'ok') {
      final sentName = '${data['first_name']} ${data['last_name'] ?? ''}'.trim();
      await QueueStatus.addSecretaryEntry(data['id'] as String, sentName);
      if (mounted) {
        setState(() {
          _queueEntries.add({'id': data['id'], 'name': sentName, 'sentAt': DateTime.now().toIso8601String()});
          _queueStatus[data['id'] as String] = {'status': QueueStatus.statusWaiting, 'at': ''};
          _showQueue = true;
          _showForm = false;
        });
      }
      _clearForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient sent to doctor - appears in the waiting room'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _sendExistingPatient(Patient patient) async {
    final ip = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9876;
    if (ip.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connect to doctor first'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final data = patient.toMap();
    data['visit_type'] = 'follow_up';
    final result = await PatientClient.sendPatient(data, ip, port);
    if (!mounted) return;
    if (result['status'] == 'ok') {
      await QueueStatus.addSecretaryEntry(data['id'] as String, patient.fullName);
      if (mounted) {
        setState(() {
          _queueEntries.add({'id': data['id'], 'name': patient.fullName, 'sentAt': DateTime.now().toIso8601String()});
          _queueStatus[data['id'] as String] = {'status': QueueStatus.statusWaiting, 'at': ''};
          _showQueue = true;
          _showForm = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${patient.fullName} sent as follow-up - in the waiting room'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${result['message']}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _queueTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: (_showQueue || _showForm)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () => setState(() {
                  _showQueue = false;
                  _showForm = false;
                }),
              )
            : null,
        title: const Row(
          children: [
            MedicalCrossFigure(size: 16),
            SizedBox(width: 10),
            Text('MediRecord - Secretary'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_connected ? Icons.wifi : Icons.wifi_off,
                color: _connected ? Colors.green : Colors.red),
            tooltip: _connected ? 'Connected' : 'Disconnected',
            onPressed: _testConnection,
          ),
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Waiting Room',
            onPressed: () => setState(() {
              _showQueue = !_showQueue;
              if (_showQueue) _loadQueue();
            }),
          ),
          IconButton(
            icon: Icon(_showForm ? Icons.list : Icons.add),
            tooltip: _showForm ? 'View Patients' : 'Add Patient',
            onPressed: () => setState(() => _showForm = !_showForm),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Bookings',
            onPressed: () => context.push('/bookings'),
          ),
          // Hidden once licensed: one role per computer, only the doctor
          // machine can switch roles.
          if (ref.watch(licenseStatusProvider) == LicenseStatus.trial)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              tooltip: 'Logout',
              onPressed: () async {
                // Logout = switch role only. The device license stays bound.
                await AppStorage.delete('medirecord_role');
                if (context.mounted) context.go('/role');
              },
            ),
        ],
      ),
      body: _showQueue ? _buildQueue() : (_showForm ? _buildForm() : _buildPatientList()),
      drawer: const AppDrawer(),
    );
  }

  Widget _buildQueue() {
    final entries = List<Map<String, dynamic>>.from(_queueEntries.reversed);
    final waiting = entries.where((e) {
      final s = _queueStatus[e['id']]?['status'] ?? QueueStatus.statusWaiting;
      return s == QueueStatus.statusWaiting;
    }).length;
    final inProgress = entries.length - waiting;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      SparkleFigure(size: 12),
                      SizedBox(width: 8),
                      Text('Waiting Room', style: TextStyle(fontSize: 18, fontFamily: AppTheme.displayFont, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _showQueue = false;
                      _showForm = false;
                    }),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back to main list'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.goldColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.4)),
                      ),
                      child: Text('$waiting waiting',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.goldDeep)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.35)),
                      ),
                      child: Text('$inProgress with doctor / done',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.successColor)),
                    ),
                  ),
                ],
              ),
              if (_queueOffline)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, size: 13, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text('Doctor PC not reachable - statuses will update when it reconnects',
                          style: TextStyle(fontSize: 11, color: Colors.orange[800])),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const MedicalCrossFigure(size: 30, gold: false),
                      const SizedBox(height: 16),
                      Text('No patients in the queue yet', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                      const SizedBox(height: 8),
                      Text('Patients you send to the doctor\nwill appear here with live status',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final id = e['id'] as String? ?? '';
                    final name = e['name'] as String? ?? 'Patient';
                    final st = _queueStatus[id]?['status'] ?? QueueStatus.statusWaiting;
                    final (Color color, IconData icon, String label) = switch (st) {
                      QueueStatus.statusDone => (AppTheme.successColor, Icons.check_circle, 'Visit finished'),
                      QueueStatus.statusWithDoctor => (AppTheme.goldDeep, Icons.healing, 'With the doctor'),
                      _ => (Colors.grey, Icons.schedule, 'Waiting'),
                    };
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
                      ),
                      child: ListTile(
                        onTap: () => _openQueuePatient(id, name, st),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(icon, color: color),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Sent: ${(e['sentAt'] as String? ?? '').length >= 16 ? '${(e['sentAt'] as String).substring(0, 10)} ${(e['sentAt'] as String).substring(11, 16)}' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(label,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                              tooltip: 'Remove from queue',
                              onPressed: () async {
                                await QueueStatus.removeSecretaryEntry(id);
                                _loadQueue();
                                if (mounted) setState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPatientList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  SparkleFigure(size: 12),
                  SizedBox(width: 8),
                  Text('Patient Records', style: TextStyle(fontSize: 18, fontFamily: AppTheme.displayFont, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search patients...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _onSearchChanged(''))
                      : null,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingPatients
              ? const Center(child: CircularProgressIndicator())
              : _filteredPatients.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const MedicalCrossFigure(size: 30, gold: false),
                          const SizedBox(height: 16),
                          const SparkleFigure(size: 12),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty ? 'No patients yet' : 'No patients match',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => setState(() => _showForm = true),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Patient'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPatients,
                      child: ListView.builder(
                        itemCount: _filteredPatients.length,
                        itemBuilder: (context, i) {
                          final patient = _filteredPatients[i];
                          return PatientCard(
                            patient: patient,
                            onTap: () => _showPatientDetail(patient),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  void _showPatientDetail(Patient patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      '${patient.firstName[0]}${patient.lastName.isNotEmpty ? patient.lastName[0] : ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patient.fullName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${patient.age} yrs | ${patient.gender}',
                            style: const TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  if (_connected)
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.green),
                      tooltip: 'Send to doctor',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sendExistingPatient(patient);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (patient.phone != null) ...[
                _detailRow(Icons.phone, 'Phone', patient.phone!),
                const SizedBox(height: 8),
              ],
              if (patient.address != null) ...[
                _detailRow(Icons.location_on, 'Address', patient.address!),
                const SizedBox(height: 8),
              ],
              if (patient.bloodGroup != null) ...[
                _detailRow(Icons.bloodtype, 'Blood Group', patient.bloodGroup!),
                const SizedBox(height: 8),
              ],
              if (patient.emergencyContactName != null) ...[
                _detailRow(Icons.emergency, 'Emergency Contact', patient.emergencyContactName!),
                const SizedBox(height: 8),
              ],
              if (patient.emergencyContactPhone != null) ...[
                _detailRow(Icons.phone_in_talk, 'Emergency Phone', patient.emergencyContactPhone!),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              Text('ID: ${patient.id}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Created: ${patient.createdAt.substring(0, 10)}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to list'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
        Expanded(child: Text(value)),
      ],
    );
  }

  Future<void> _openQueuePatient(String id, String name, String status) async {
    final patient = await DatabaseHelper().getPatient(id);
    if (!mounted) return;
    if (patient != null) {
      _showPatientDetail(patient);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyDeep,
        title: const Text('Waiting room patient', style: TextStyle(color: AppTheme.champagneLight)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Status: ${switch (status) {
                QueueStatus.statusDone => 'Visit finished',
                QueueStatus.statusWithDoctor => 'With the doctor',
                _ => 'Waiting',
              }}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            const Text(
              'The full record of this patient is on the doctor\'s computer.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back', style: TextStyle(color: AppTheme.champagne)),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('New Patient',
                  style: TextStyle(fontSize: 18, fontFamily: AppTheme.displayFont, fontWeight: FontWeight.w700)),
              TextButton.icon(
                onPressed: () => setState(() {
                  _showForm = false;
                  _showQueue = false;
                }),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back to main list'),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
                          decoration: const InputDecoration(
                              labelText: 'Doctor IP', hintText: '192.168.1.5', isDense: true),
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
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
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
                          style: TextStyle(fontSize: 12,
                              color: _connected ? Colors.green : Colors.red)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Returning Patient', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchReturningCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search existing patient...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _selectedReturningPatient != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearForm,
                            )
                          : null,
                    ),
                    onChanged: _onReturningSearchChanged,
                  ),
                  if (_returningSearchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView(
                        shrinkWrap: true,
                        children: _returningSearchResults.map((p) => ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text('${p.firstName[0]}${p.lastName.isNotEmpty ? p.lastName[0] : ''}',
                                style: const TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                          title: Text(p.fullName, style: const TextStyle(fontSize: 13)),
                          subtitle: Text('${p.age} yrs | ${p.gender}${p.phone != null ? ' | ${p.phone}' : ''}',
                              style: const TextStyle(fontSize: 11)),
                          onTap: () => _selectReturningPatient(p),
                        )).toList(),
                      ),
                    ),
                  if (_isFollowUp)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.repeat, size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text('Follow-up visit', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('First Visit'),
                  selected: !_isFollowUp,
                  onSelected: (_) => setState(() => _isFollowUp = false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Follow-up'),
                  selected: _isFollowUp,
                  selectedColor: Colors.orange.shade100,
                  onSelected: (_) => setState(() => _isFollowUp = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Patient Information',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(
                decoration: const InputDecoration(
                    labelText: 'First Name', prefixIcon: Icon(Icons.person)),
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
                decoration: const InputDecoration(
                    labelText: 'Age', prefixIcon: Icon(Icons.cake)),
                keyboardType: TextInputType.number,
                onChanged: (v) => _age = v,
              )),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    _genderButton('Male'),
                    const SizedBox(width: 8),
                    _genderButton('Female'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
                labelText: 'Phone', prefixIcon: Icon(Icons.phone)),
            keyboardType: TextInputType.phone,
            onChanged: (v) => _phone = v,
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
                labelText: 'Address', prefixIcon: Icon(Icons.location_on)),
            maxLines: 2,
            onChanged: (v) => _address = v,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _bloodGroup,
            decoration: const InputDecoration(
                labelText: 'Blood Group', prefixIcon: Icon(Icons.bloodtype)),
            items: AppConstants.bloodGroups
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) => setState(() => _bloodGroup = v),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
                labelText: 'Emergency Contact Name',
                prefixIcon: Icon(Icons.emergency)),
            onChanged: (v) => _emergencyName = v,
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(labelText: 'Emergency Contact Phone'),
            keyboardType: TextInputType.phone,
            onChanged: (v) => _emergencyPhone = v,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _savePatientLocally,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Locally'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _sendPatient,
                    icon: _sending
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(_isFollowUp ? Icons.repeat : Icons.send),
                    label: Text(_sending ? 'Sending...' : (_isFollowUp ? 'Send as Follow-up' : 'Send to Doctor')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _connected ? (_isFollowUp ? Colors.orange : AppTheme.primaryColor) : Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _genderButton(String gender) {
    final selected = _gender == gender;
    final male = gender == 'Male';
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = gender),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: selected ? AppTheme.goldColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.goldDeep : AppTheme.goldColor,
              width: 1.3,
            ),
            boxShadow: selected
                ? [BoxShadow(color: AppTheme.goldColor.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                male ? Icons.male : Icons.female,
                size: 18,
                color: selected ? AppTheme.navyDeep : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                gender,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppTheme.navyDeep : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
