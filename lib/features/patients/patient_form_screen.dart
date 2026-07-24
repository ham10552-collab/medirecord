import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/utils/app_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/database_provider.dart';
import '../../core/utils/constants.dart';
import '../../shared/models/patient.dart';

class PatientFormScreen extends ConsumerStatefulWidget {
  final String? patientId;
  final String? patientFirstName;
  final String? patientLastName;
  final String? patientPhone;
  final int? patientAge;
  final String? patientGender;
  final String? patientBloodGroup;
  final String? patientAddress;
  final String? patientEmergencyContactName;
  final String? patientEmergencyContactPhone;

  const PatientFormScreen({
    super.key,
    this.patientId,
    this.patientFirstName,
    this.patientLastName,
    this.patientPhone,
    this.patientAge,
    this.patientGender,
    this.patientBloodGroup,
    this.patientAddress,
    this.patientEmergencyContactName,
    this.patientEmergencyContactPhone,
  });

  bool get isEditing => patientId != null;

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  String _firstName = '';
  String _lastName = '';
  String _phone = '';
  String _address = '';
  String _emergencyName = '';
  String _emergencyPhone = '';
  String _age = '';
  String _gender = 'Male';
  String? _bloodGroup;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _firstName = widget.patientFirstName ?? '';
      _lastName = widget.patientLastName ?? '';
      _phone = widget.patientPhone ?? '';
      _address = widget.patientAddress ?? '';
      _emergencyName = widget.patientEmergencyContactName ?? '';
      _emergencyPhone = widget.patientEmergencyContactPhone ?? '';
      _age = widget.patientAge?.toString() ?? '';
      _gender = widget.patientGender ?? 'Male';
      _bloodGroup = widget.patientBloodGroup;
    }
  }

  Future<void> _save() async {
    if (!widget.isEditing) {
      final trial = await AppStorage.read('medirecord_trial');
      if (trial == 'true') {
        final licensed = await AppStorage.read('medirecord_licensed');
        if (licensed != 'true') {
          final count = await DatabaseHelper().getPatientCount();
          if (count >= 70) {
            if (mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Trial Limit Reached'),
                  content: const Text('You have reached the 70-patient limit for the free trial.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/license');
                      },
                      child: const Text('Activate License'),
                    ),
                  ],
                ),
              );
            }
            setState(() => _isLoading = false);
            return;
          }
        }
      }
    }

    setState(() => _isLoading = true);

    try {
      final db = DatabaseHelper();
      final now = DateTime.now().toIso8601String();
      String userId = 'offline';
      try { userId = FirebaseAuth.instance.currentUser?.uid ?? 'offline'; } catch (_) {}

      final patientId = widget.patientId ?? const Uuid().v4();
      final patient = Patient(
        id: patientId,
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
        createdBy: userId,
        createdAt: widget.patientId != null
            ? (await db.getPatient(widget.patientId!))?.createdAt ?? now
            : now,
        updatedAt: now,
      );

      if (widget.isEditing) {
        await db.updatePatient(patient);
      } else {
        await db.insertPatient(patient);
      }

      if (mounted) {
        ref.invalidate(patientCountProvider);
        ref.invalidate(allPatientsProvider);
        if (widget.isEditing) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient updated')));
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient added')));
          context.replace('/patients/$patientId');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Patient' : 'Add Patient')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.isEditing ? 'Update Patient' : 'Save Patient'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
