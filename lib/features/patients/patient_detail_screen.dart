import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/theme/app_theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/network/queue_status.dart';
import '../../core/utils/app_storage.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/arabic_pdf.dart';
import '../../core/utils/pdf_fonts.dart';
import '../../core/utils/platform_helper.dart';
import '../../shared/widgets/vitals_card.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/luxury_figures.dart';
import '../../shared/models/patient.dart';
import '../../shared/models/medical_history.dart';
import '../../shared/models/examination.dart';
import '../../shared/models/investigation.dart';
import '../../shared/models/medication.dart';
import '../../shared/models/allergy.dart';
import '../../shared/models/prescription.dart';
import '../prescriptions/prescription_printer.dart';
import 'patient_provider.dart';

class PatientDetailScreen extends ConsumerWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientByIdProvider(patientId));

    return patientAsync.when(
      data: (patient) {
        if (patient == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Patient Not Found')),
            body: const Center(child: Text('Patient not found')),
          );
        }
        return _PatientDetailContent(patient: patient);
      },
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Error: $error')),
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _PatientDetailContent extends ConsumerWidget {
  final Patient patient;

  const _PatientDetailContent({required this.patient});

  static final _markedWithDoctor = <String>{};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(userRoleProvider);
    final deviceRole = ref.watch(deviceRoleProvider).valueOrNull;
    final isPharmacist = deviceRole == 'pharmacist' || roleAsync.valueOrNull == 'pharmacist';
    final isSecretary = !isPharmacist &&
        (deviceRole == 'secretary' || roleAsync.valueOrNull == 'secretary');
    final isDoctorMachine = !isPharmacist && !isSecretary;
    if (isDoctorMachine && _markedWithDoctor.add(patient.id)) {
      // Tell the secretary's waiting room this patient is with the doctor.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        QueueStatus.setStatus(patient.id, QueueStatus.statusWithDoctor);
      });
    }
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(patient.fullName),
          actions: [
            if (isDoctorMachine)
              IconButton(
                icon: const Icon(Icons.done_all, color: AppTheme.successColor),
                tooltip: 'Finish visit - notify secretary',
                onPressed: () async {
                  await QueueStatus.setStatus(patient.id, QueueStatus.statusDone);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Visit finished - the secretary has been notified'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: () => _exportPatientPdf(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push('/patients/edit/${patient.id}'),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'History'),
              Tab(text: 'Exams'),
              Tab(text: 'Investigations'),
              Tab(text: 'Medications'),
              Tab(text: 'Prescriptions'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ProfileTab(patient: patient),
            _HistoryTab(patientId: patient.id),
            _ExamsTab(patientId: patient.id),
            _InvestigationsTab(patientId: patient.id),
            _MedicationsTab(patientId: patient.id),
            _PrescriptionsTab(patientId: patient.id, patient: patient),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPatientPdf(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))),
    );

    try {
      final db = DatabaseHelper();
      final p = patient;
      final history = await db.getPatientMedicalHistory(p.id);
      final surgeries = await db.getPatientSurgeries(p.id);
      final allergies = await db.getPatientAllergies(p.id);
      final exams = await db.getPatientExaminations(p.id);
      final investigations = await db.getPatientInvestigations(p.id);
      final medications = await db.getPatientMedications(p.id);
      final prescriptions = await db.getPatientPrescriptions(p.id);

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: await arabicPdfTheme(),
          header: (_) => pw.Header(
            level: 0,
            child: pw.Text('MediRecord - Patient Report',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ),
          build: (_) => [
            pw.Header(level: 1, text: arabicToPdf(p.fullName)),
            pw.Paragraph(text: 'Age: ${p.age} years | Gender: ${arabicToPdf(p.gender)} | Blood Group: ${arabicToPdf(p.bloodGroup ?? '-')}'),
            pw.Paragraph(text: 'Phone: ${arabicToPdf(p.phone ?? '-')}${p.email != null && p.email!.isNotEmpty ? ' | Email: ${arabicToPdf(p.email!)}' : ''}'),
            if (p.address != null && p.address!.isNotEmpty) pw.Paragraph(text: 'Address: ${arabicToPdf(p.address!)}'),
            if ((p.emergencyContactName ?? '').isNotEmpty)
              pw.Paragraph(text: 'Emergency Contact: ${arabicToPdf(p.emergencyContactName!)} (${arabicToPdf(p.emergencyContactPhone ?? '-')})'),
            pw.Paragraph(text: 'Patient ID: ${p.id} | Registered: ${p.createdAt.split('T').first}'),
            pw.Divider(),
            if (history.isNotEmpty) ...[
              pw.Header(level: 2, text: 'Medical History'),
              ...history.cast<MedicalHistory>().map((h) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Paragraph(text: '[${arabicToPdf(historyTypeLabel(h.historyType))}] ${arabicToPdf(h.conditionName)} (${arabicToPdf(h.status)}) - ${arabicToPdf(h.severity ?? '')}'),
                  if (h.diagnosisDate != null) pw.Paragraph(text: '  Diagnosed: ${arabicToPdf(h.diagnosisDate!)}'),
                  if (h.notes != null) pw.Paragraph(text: '  Notes: ${arabicToPdf(h.notes!)}'),
                ],
              )),
            ],
            if (allergies.isNotEmpty) ...[
              pw.Header(level: 2, text: 'Allergies'),
              ...allergies.cast<Allergy>().map((a) => pw.Paragraph(
                text: '${arabicToPdf(a.allergen)} (${arabicToPdf(a.severity)})${a.reaction != null ? ' - ${arabicToPdf(a.reaction!)}' : ''}',
              )),
            ],
            if (surgeries.isNotEmpty) ...[
              pw.Header(level: 2, text: 'Surgeries'),
              ...surgeries.cast<Map<String, dynamic>>().map((s) => pw.Paragraph(
                text: '${arabicToPdf(s['surgery_name'] ?? '')}${s['surgery_date'] != null ? ' (${arabicToPdf('${s['surgery_date']}')})' : ''}${s['hospital'] != null ? ' @ ${arabicToPdf('${s['hospital']}')}' : ''}${s['notes'] != null ? ' - ${arabicToPdf('${s['notes']}')}' : ''}',
              )),
            ],
            if (exams.isNotEmpty) ...[
              pw.Header(level: 2, text: 'Examinations'),
              ...exams.cast<Examination>().map((e) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Paragraph(text: '${e.visitDate} - Dr. ${arabicToPdf(e.doctorName)}'),
                  if (e.chiefComplaint != null && e.chiefComplaint!.isNotEmpty) pw.Paragraph(text: '  Complaint: ${arabicToPdf(e.chiefComplaint!)}'),
                  if (e.bp != null ||
                      e.heartRate != null ||
                      e.temperature != null ||
                      e.respiratoryRate != null ||
                      e.oxygenSaturation != null ||
                      e.weight != null ||
                      e.height != null)
                    pw.Paragraph(text: '  Vitals: ${[
                      if (e.bp != null) 'BP ${e.bp}',
                      if (e.heartRate != null) 'HR ${e.heartRate}',
                      if (e.temperature != null) 'Temp ${e.temperature}',
                      if (e.respiratoryRate != null) 'RR ${e.respiratoryRate}',
                      if (e.oxygenSaturation != null) 'O2 ${e.oxygenSaturation}%',
                      if (e.weight != null) 'WT ${e.weight}kg',
                      if (e.height != null) 'HT ${e.height}cm',
                    ].join(' | ')}'),
                  for (final part in {
                    'General Appearance': e.generalAppearance,
                    'Head & Neck': e.headAndNeck,
                    'Chest': e.chest,
                    'Abdomen': e.abdomen,
                    'CVS': e.cvs,
                    'CNS': e.cns,
                    'Musculoskeletal': e.musculoskeletal,
                    'Skin': e.skin,
                    'Diagnosis': e.diagnosis,
                    'Plan': e.plan,
                    'Notes': e.notes,
                  }.entries)
                    if (part.value != null && part.value!.isNotEmpty)
                      pw.Paragraph(text: '  ${part.key}: ${arabicToPdf(part.value!)}'),
                ],
              )),
            ],
            if (investigations.isNotEmpty) ...[
              pw.Header(level: 2, text: 'Investigations'),
              ...investigations.cast<Investigation>().map((i) => pw.Paragraph(
                text: '${arabicToPdf(i.testName)}: ${arabicToPdf(i.result ?? '-')} ${arabicToPdf(i.unit ?? '')} ${i.isAbnormal ? '(ABNORMAL)' : ''} (${i.investigationDate})',
              )),
            ],
            if (medications.isNotEmpty) ...[
              pw.Header(level: 2, text: 'Medications'),
              ...medications.cast<Medication>().map((m) => pw.Paragraph(
                text: '${arabicToPdf(m.drugName)} ${arabicToPdf(m.dosage)} - ${arabicToPdf(m.frequency)}${m.duration != null && m.duration!.isNotEmpty ? ' for ${arabicToPdf(m.duration!)}' : ''} (${m.isActive ? 'Active' : 'Inactive'})',
              )),
            ],
            if (prescriptions.isNotEmpty) ...[
              pw.Header(level: 2, text: 'Prescriptions'),
              ...prescriptions.cast<Prescription>().map((rx) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Paragraph(text: '${rx.createdAt.split('T').first} - Dr. ${arabicToPdf(rx.doctorName)} - ${rx.status.toUpperCase()}${rx.pharmacistName != null && rx.pharmacistName!.isNotEmpty ? ' by ${arabicToPdf(rx.pharmacistName!)}' : ''}'),
                  ...rx.items.map((i) => pw.Paragraph(
                    text: '  - ${arabicToPdf(i.medicineName)} ${arabicToPdf(i.dosage)}${i.frequency.isNotEmpty ? ' ${arabicToPdf(i.frequency)}' : ''}${i.duration.isNotEmpty ? ' (${arabicToPdf(i.duration)})' : ''}${i.instructions.isNotEmpty ? ' - ${arabicToPdf(i.instructions)}' : ''}',
                  )),
                ],
              )),
            ],
            pw.Divider(),
            pw.Paragraph(text: 'Report generated: ${DateTime.now().toIso8601String().split('T')[0]}'),
          ],
        ),
      );

      final fileName = '${p.fullName.replaceAll(' ', '_')}_report.pdf';
      await PlatformHelper.savePdf(await pdf.save(), fileName);

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved as $fileName'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}

class _ProfileTab extends StatelessWidget {
  final Patient patient;

  const _ProfileTab({required this.patient});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.goldLight.withValues(alpha: 0.55), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.navyDeep.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -18,
                  top: -22,
                  child: Icon(Icons.auto_awesome, size: 70, color: AppTheme.goldColor.withValues(alpha: 0.2)),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Transform.flip(flipY: true, child: CornerOrnament(size: 24, color: Colors.white.withValues(alpha: 0.5))),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: CornerOrnament(size: 24, color: Colors.white.withValues(alpha: 0.5)),
                ),
                Row(
                  children: [
                    const MedicalCrossFigure(size: 22),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PATIENT PROFILE', style: TextStyle(
                          color: AppTheme.goldLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3,
                        )),
                        const SizedBox(height: 2),
                        Text(
                          patient.fullName,
                          style: AppTheme.displayStyle(size: 22, color: Colors.white, gold: true),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${patient.age} yrs  •  ${patient.gender}  •  ${patient.bloodGroup ?? 'Unknown blood group'}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const LuxSectionTitle(title: 'Personal Information', icon: Icons.badge_outlined),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GoldDivider(),
                  const SizedBox(height: 12),
                  InfoRow(label: 'Name', value: patient.fullName),
                  InfoRow(label: 'Age', value: patient.age.toString()),
                  InfoRow(label: 'Gender', value: patient.gender),
                  InfoRow(label: 'Phone', value: patient.phone ?? '-'),
                  InfoRow(label: 'Email', value: patient.email ?? '-'),
                  InfoRow(label: 'Blood Group', value: patient.bloodGroup ?? '-'),
                  InfoRow(label: 'Address', value: patient.address ?? '-'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const LuxSectionTitle(title: 'Emergency Contact', icon: Icons.contact_emergency_outlined),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GoldDivider(),
                  const SizedBox(height: 12),
                  InfoRow(label: 'Name', value: patient.emergencyContactName ?? '-'),
                  InfoRow(label: 'Phone', value: patient.emergencyContactPhone ?? '-'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

String historyTypeLabel(String type) {
  return switch (type) {
    'surgical' => 'Surgical',
    'allergy' => 'Allergy',
    'other' => 'Other',
    _ => 'Medical',
  };
}

class _HistoryTab extends ConsumerWidget {
  final String patientId;

  const _HistoryTab({required this.patientId});

  IconData _typeIcon(String type) {
    return switch (type) {
      'surgical' => Icons.content_cut,
      'allergy' => Icons.warning_amber,
      'other' => Icons.more_horiz,
      _ => Icons.local_hospital,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(patientMedicalHistoryProvider(patientId));

    return Scaffold(
      body: historyAsync.when(
        data: (history) => ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: history.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.all(8),
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/patients/${patientId}/history/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add History'),
                ),
              );
            }
            final h = history[i - 1];
            final label = historyTypeLabel(h.historyType);
            return Card(
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: label == 'Allergy'
                        ? AppTheme.errorColor.withValues(alpha: 0.1)
                        : label == 'Surgical'
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : AppTheme.goldColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _typeIcon(h.historyType),
                    color: label == 'Allergy'
                        ? AppTheme.errorColor
                        : label == 'Surgical'
                            ? AppTheme.primaryColor
                            : AppTheme.goldDeep,
                    size: 20,
                  ),
                ),
                title: Text(h.conditionName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${historyTypeLabel(h.historyType)} - ${h.status}${h.severity != null ? ' - ${h.severity}' : ''}'),
                trailing: PopupMenuButton(
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                  onSelected: (v) async {
                    if (v == 'delete') {
                      await DatabaseHelper().deleteMedicalHistory(h.id);
                      ref.invalidate(patientMedicalHistoryProvider(patientId));
                    }
                  },
                ),
              ),
            );
          },
        ),
        error: (_, __) => const Center(child: Text('Error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/patients/${patientId}/history/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ExamsTab extends ConsumerWidget {
  final String patientId;

  const _ExamsTab({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(patientExaminationsProvider(patientId));

    return Scaffold(
      body: examsAsync.when(
        data: (exams) => ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: exams.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.all(8),
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/patients/${patientId}/examinations/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Examination'),
                ),
              );
            }
            final e = exams[i - 1];
            final vitals = <String>[
              if (e.bp != null) 'BP: ${e.bp}',
              if (e.heartRate != null) 'HR: ${e.heartRate}',
              if (e.temperature != null) 'Temp: ${e.temperature}',
              if (e.respiratoryRate != null) 'RR: ${e.respiratoryRate}',
              if (e.oxygenSaturation != null) 'SpO2: ${e.oxygenSaturation}',
              if (e.height != null) 'Ht: ${e.height}',
              if (e.weight != null) 'Wt: ${e.weight}',
              if (e.bmi != null) 'BMI: ${e.bmi}',
            ];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.doctorName.trim().isEmpty
                          ? e.visitDate
                          : 'Dr. ${e.doctorName} - ${e.visitDate}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (e.chiefComplaint != null) Text('Complaint: ${e.chiefComplaint}'),
                    if (vitals.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        children: vitals.map((v) => Text(v, style: const TextStyle(fontSize: 12, color: AppTheme.goldDeep, fontWeight: FontWeight.w600))).toList(),
                      ),
                    ],
                    if (e.diagnosis != null) Text('Diagnosis: ${e.diagnosis}'),
                    if (e.plan != null) Text('Plan: ${e.plan}'),
                    if (e.notes != null) Text('Notes: ${e.notes}'),
                    if (e.generalAppearance != null) Text('General: ${e.generalAppearance}'),
                  ],
                ),
              ),
            );
          },
        ),
        error: (_, __) => const Center(child: Text('Error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/patients/${patientId}/examinations/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _InvestigationsTab extends ConsumerWidget {
  final String patientId;

  const _InvestigationsTab({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investigationsAsync = ref.watch(patientInvestigationsProvider(patientId));

    return Scaffold(
      body: investigationsAsync.when(
        data: (investigations) {
          // Group by test name
          final grouped = <String, List<Investigation>>{};
          for (final inv in investigations) {
            grouped.putIfAbsent(inv.testName, () => []).add(inv);
          }
          // Sort each group by date
          for (final list in grouped.values) {
            list.sort((a, b) => b.investigationDate.compareTo(a.investigationDate));
          }

          if (investigations.isEmpty) {
            return const Center(child: Text('No investigations recorded', style: TextStyle(color: AppTheme.textSecondary)));
          }

          return ListView(
            padding: const EdgeInsets.all(8),
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/patients/${patientId}/investigations/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Investigation'),
                ),
              ),
              ...grouped.entries.map((entry) {
                final testName = entry.key;
                final results = entry.value;
                final latest = results.isNotEmpty ? results.first : null;
                // Trend: compare first two results
                final trend = <String, double>{};
                for (int i = 1; i < results.length; i++) {
                  final prev = double.tryParse(results[i].result ?? '');
                  final curr = double.tryParse(results[i - 1].result ?? '');
                  if (prev != null && curr != null) {
                    trend[results[i - 1].id] = curr - prev;
                  }
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Text(testName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          children: [
                            const Expanded(flex: 3, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppTheme.textSecondary))),
                            const Expanded(flex: 3, child: Text('Result', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppTheme.textSecondary))),
                            const Expanded(flex: 3, child: Text('Normal Range', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppTheme.textSecondary))),
                            const Expanded(flex: 1, child: Text('', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppTheme.textSecondary))),
                            const SizedBox(width: 36),
                          ],
                        ),
                      ),
                      ...results.map((r) {
                        final change = trend[r.id];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: r == latest ? AppTheme.primaryColor.withValues(alpha: 0.05) : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(r.investigationDate, style: TextStyle(fontSize: 12, fontWeight: r == latest ? FontWeight.w600 : FontWeight.normal))),
                              Expanded(flex: 3, child: Row(
                                children: [
                                  Flexible(
                                    child: Text(r.result ?? '-', style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.goldDeep,
                                    )),
                                  ),
                                  if (r.isAbnormal) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Color(0xFFFF5252).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: const Color(0xFFFF5252), width: 0.8),
                                      ),
                                      child: const Text('ABNORMAL', style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFF5252),
                                      )),
                                    ),
                                  ],
                                ],
                              )),
                              Expanded(flex: 3, child: Text(r.normalRange ?? '-', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
                              SizedBox(
                                width: 24,
                                child: change != null && change != 0
                                    ? Icon(change > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                                        size: 16, color: change > 0 ? AppTheme.errorColor : AppTheme.successColor)
                                    : null,
                              ),
                              if (r.filePath != null)
                                GestureDetector(
                                  onTap: () {
                                    final bytes = PlatformHelper.loadImageBytes(r.filePath!);
                                    if (bytes != null) {
                                      _showImageDialog(context, bytes);
                                    }
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: _imageWidget(r.filePath!),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(width: 32),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              }),
            ],
          );
        },
        error: (_, __) => const Center(child: Text('Error loading investigations')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/patients/${patientId}/investigations/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _imageWidget(String filePath) {
    final bytes = PlatformHelper.loadImageBytes(filePath);
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 16, color: AppTheme.primaryColor));
    }
    return const Icon(Icons.image, size: 16, color: AppTheme.primaryColor);
  }
}

class _MedicationsTab extends ConsumerWidget {
  final String patientId;

  const _MedicationsTab({required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicationsAsync = ref.watch(patientMedicationsProvider(patientId));

    return Scaffold(
      body: medicationsAsync.when(
        data: (medications) => ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: medications.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.all(8),
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/patients/${patientId}/medications/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Medication'),
                ),
              );
            }
            final m = medications[i - 1];
            return Card(
              child: ListTile(
                leading: Icon(m.isActive ? Icons.check_circle : Icons.cancel, color: m.isActive ? Colors.green : Colors.red),
                title: Text(m.drugName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${m.dosage ?? ''} ${m.frequency ?? ''}'),
                trailing: PopupMenuButton(
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                  onSelected: (v) async {
                    if (v == 'delete') {
                      await DatabaseHelper().deleteMedication(m.id);
                      ref.invalidate(patientMedicationsProvider(patientId));
                    }
                  },
                ),
              ),
            );
          },
        ),
        error: (_, __) => const Center(child: Text('Error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/patients/${patientId}/medications/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PrescriptionsTab extends ConsumerStatefulWidget {
  final String patientId;
  final Patient patient;

  const _PrescriptionsTab({required this.patientId, required this.patient});

  @override
  ConsumerState<_PrescriptionsTab> createState() => _PrescriptionsTabState();
}

class _PrescriptionsTabState extends ConsumerState<_PrescriptionsTab> {
  String? _patientPhone;

  String get _patientId => widget.patientId;
  Patient get patient => widget.patient;

  Future<void> _sendPrescriptionWhatsApp(Prescription rx, String phone) async {
    final items = rx.items
        .map((item) => '${item.medicineName} - ${item.dosage}${item.frequency.isNotEmpty ? ' ${item.frequency}' : ''}${item.duration.isNotEmpty ? ' (${item.duration})' : ''}')
        .join('\n');
    final message = [
      'MediRecord - Prescription',
      'Patient: ${patient.fullName}',
      'Date: ${rx.createdAt.length >= 10 ? rx.createdAt.substring(0, 10) : rx.createdAt}',
      if (rx.doctorName.isNotEmpty) 'Doctor: ${rx.doctorName}',
      if (rx.diagnosis.isNotEmpty) '',
      if (rx.diagnosis.isNotEmpty) 'Diagnosis: ${rx.diagnosis}',
      '',
      items,
      if (rx.notes.isNotEmpty) '',
      if (rx.notes.isNotEmpty) 'Notes: ${rx.notes}',
    ].join('\n');
    await PlatformHelper.openWhatsApp(phone, message);
  }

  Future<String?> _askPhoneNumber(BuildContext context) {
    final ctrl = TextEditingController(text: patient.phone ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send via WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Patient has no phone number saved. Enter one to send the prescription:'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number (with country code, e.g. 20...)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prescriptionsAsync = ref.watch(patientPrescriptionsProvider(_patientId));

    return Scaffold(
      body: prescriptionsAsync.when(
        data: (prescriptions) {
          if (prescriptions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No prescriptions', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
ElevatedButton.icon(
                    onPressed: () => context.push('/patients/${_patientId}/prescriptions/add'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Prescription'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: prescriptions.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/patients/${_patientId}/prescriptions/add'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Prescription'),
                  ),
                );
              }
              final rx = prescriptions[i - 1];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rx.createdAt.length >= 10 ? rx.createdAt.substring(0, 10) : rx.createdAt,
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('Dr. ${rx.doctorName}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, size: 20),
                            tooltip: 'View PDF',
                            onPressed: () async {
                              final path = await generatePrescriptionPdf(rx, patient);
                              if (context.mounted) await openPdfForPrint(context, path);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.print, size: 20),
                            tooltip: 'Print',
                            onPressed: () async {
                              final path = await generatePrescriptionPdf(rx, patient);
                              if (context.mounted) await printPrescriptionDirect(context, path);
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              rx.sentToPharmacy ? Icons.refresh : Icons.send,
                              size: 20,
                              color: rx.sentToPharmacy ? AppTheme.successColor : AppTheme.primaryColor,
                            ),
                            tooltip: rx.sentToPharmacy ? 'Re-send to Pharmacy (appears as pending)' : 'Send to Pharmacy',
                            onPressed: () async {
                                    var loginName = (await AppStorage.read('doctor_name'))?.trim() ?? '';
                                    if (loginName.isEmpty) {
                                      loginName = ref.read(currentUserProvider)?.displayName?.trim() ?? '';
                                    }
                                    if (loginName.isEmpty) {
                                      final saved = await AppStorage.read('last_doctor_name');
                                      loginName = saved?.trim() ?? '';
                                    }
                                    if (loginName.isNotEmpty) {
                                      await DatabaseHelper().attachDoctorName(rx.id, loginName);
                                    }
                                    final ok = rx.sentToPharmacy
                                        ? await DatabaseHelper().resendPrescription(rx.id)
                                        : await DatabaseHelper().markPrescriptionSent(rx.id);
                                    if (ok > 0) {
                                      await QueueStatus.setStatus(_patientId, QueueStatus.statusDone);
                                    }
                                    ref.invalidate(patientPrescriptionsProvider(_patientId));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok > 0
                                              ? (rx.sentToPharmacy
                                                  ? 'Re-sent to Pharmacy - it will appear as pending'
                                                  : 'Sent to Pharmacy - pharmacist will be notified')
                                              : 'Failed to send - try again'),
                                          backgroundColor: ok > 0 ? AppTheme.successColor : AppTheme.errorColor,
                                        ),
                                      );
                                    }
                                  },
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat, size: 20),
                            tooltip: 'Send via WhatsApp',
                            onPressed: _patientPhone == null
                                ? () async {
                                    final phone = await _askPhoneNumber(context);
                                    if (phone != null) {
                                      setState(() => _patientPhone = phone);
                                      _sendPrescriptionWhatsApp(rx, phone);
                                    }
                                  }
                                : () => _sendPrescriptionWhatsApp(rx, _patientPhone!),
                          ),
                        ],
                      ),
                      if (rx.diagnosis.isNotEmpty) ...[
                        const Divider(),
                        Text('Diagnosis: ${rx.diagnosis}', style: const TextStyle(fontSize: 13)),
                      ],
                      const Divider(),
                      ...rx.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.medication, size: 14, color: AppTheme.primaryColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('${item.medicineName} - ${item.dosage} ${item.frequency} (${item.duration})',
                                  style: const TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                      )),
                      if (rx.notes.isNotEmpty) ...[
                        const Divider(),
                        Text('Notes: ${rx.notes}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        error: (_, __) => const Center(child: Text('Error loading prescriptions')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/patients/${_patientId}/prescriptions/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

void _showImageDialog(BuildContext context, Uint8List imageBytes) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              imageBytes,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.black54,
                child: const Center(child: Text('Image not found', style: TextStyle(color: Colors.white))),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
