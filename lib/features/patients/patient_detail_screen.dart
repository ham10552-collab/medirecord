import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/platform_helper.dart';
import '../../shared/widgets/vitals_card.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(patient.fullName),
          actions: [
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

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (_) => pw.Header(
            level: 0,
            child: pw.Text('MediRecord - Patient Report',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ),
          build: (_) => [
            pw.Header(level: 1, text: p.fullName),
            pw.Paragraph(text: 'Age: ${p.age} years | Gender: ${p.gender}'),
            pw.Paragraph(text: 'Blood Group: ${p.bloodGroup ?? '-'} | Phone: ${p.phone ?? '-'}'),
            if (p.address != null) pw.Paragraph(text: 'Address: ${p.address}'),
            pw.Divider(),
            if (history.isNotEmpty) ...[
              pw.Header(level: 2, text: 'Medical History'),
              ...history.cast<MedicalHistory>().map((h) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Paragraph(text: '${h.conditionName} (${h.status}) - ${h.severity ?? ''}'),
                  if (h.diagnosisDate != null) pw.Paragraph(text: '  Diagnosed: ${h.diagnosisDate}'),
                  if (h.notes != null) pw.Paragraph(text: '  Notes: ${h.notes}'),
                ],
              )),
            ],
            if (surgeries.isNotEmpty) ...[
              pw.Header(level: 2, text: 'Surgeries'),
              ...surgeries.cast<Map<String, dynamic>>().map((s) => pw.Paragraph(
                text: '${s['surgery_name']}${s['surgery_date'] != null ? ' (${s['surgery_date']})' : ''}${s['hospital'] != null ? ' @ ${s['hospital']}' : ''}',
              )),
            ],
            if (allergies.isNotEmpty) ...[
              pw.Header(level: 2, text: 'Allergies'),
              ...allergies.cast<Allergy>().map((a) => pw.Paragraph(
                text: '${a.allergen} (${a.severity})${a.reaction != null ? ' - ${a.reaction}' : ''}',
              )),
            ],
            if (exams.isNotEmpty) ...[
              pw.Header(level: 2, text: 'Examinations'),
              ...exams.cast<Examination>().map((e) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Paragraph(text: '${e.visitDate} - Dr. ${e.doctorName}'),
                  if (e.chiefComplaint != null) pw.Paragraph(text: '  Complaint: ${e.chiefComplaint}'),
                  if (e.diagnosis != null) pw.Paragraph(text: '  Diagnosis: ${e.diagnosis}'),
                  if (e.plan != null) pw.Paragraph(text: '  Plan: ${e.plan}'),
                ],
              )),
            ],
            if (investigations.isNotEmpty) ...[
              pw.Header(level: 2, text: 'Investigations'),
              ...investigations.cast<Investigation>().map((i) => pw.Paragraph(
                text: '${i.testName}: ${i.result ?? '-'} ${i.unit ?? ''} ${i.isAbnormal ? '(ABNORMAL)' : ''} (${i.investigationDate})',
              )),
            ],
            if (medications.isNotEmpty) ...[
              pw.Header(level: 2, text: 'Medications'),
              ...medications.cast<Medication>().map((m) => pw.Paragraph(
                text: '${m.drugName} ${m.dosage} - ${m.frequency} (${m.isActive ? 'Active' : 'Inactive'})',
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Emergency Contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
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

class _HistoryTab extends ConsumerWidget {
  final String patientId;

  const _HistoryTab({required this.patientId});

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
                  label: const Text('Add Medical History'),
                ),
              );
            }
            final h = history[i - 1];
            return Card(
              child: ListTile(
                title: Text(h.conditionName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${h.status} - ${h.severity ?? ''}'),
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
                  onPressed: () => context.push('/patients/${patientId}/exams/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Examination'),
                ),
              );
            }
            final e = exams[i - 1];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr. ${e.doctorName} - ${e.visitDate}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (e.chiefComplaint != null) Text('Complaint: ${e.chiefComplaint}'),
                    if (e.diagnosis != null) Text('Diagnosis: ${e.diagnosis}'),
                    if (e.plan != null) Text('Plan: ${e.plan}'),
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
        onPressed: () => context.push('/patients/${patientId}/exams/add'),
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
                              Expanded(flex: 3, child: Text(r.result ?? '-', style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: r.isAbnormal ? AppTheme.errorColor : AppTheme.textPrimary,
                              ))),
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

class _PrescriptionsTab extends ConsumerWidget {
  final String patientId;
  final Patient patient;

  const _PrescriptionsTab({required this.patientId, required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptionsAsync = ref.watch(patientPrescriptionsProvider(patientId));

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
                    onPressed: () => context.push('/patients/${patientId}/prescriptions/add'),
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
                    onPressed: () => context.push('/patients/${patientId}/prescriptions/add'),
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
        onPressed: () => context.push('/patients/${patientId}/prescriptions/add'),
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
