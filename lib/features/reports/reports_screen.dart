import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/arabic_pdf.dart';
import '../../core/utils/pdf_fonts.dart';
import '../../core/utils/platform_helper.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/luxury_figures.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Export')),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Row(
            children: [
              MedicalCrossFigure(size: 18),
              SizedBox(width: 10),
              Spacer(),
              SparkleFigure(size: 13),
              SizedBox(width: 6),
              SparkleFigure(size: 9),
            ],
          ),
          const SizedBox(height: 14),
          const GoldDivider(),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: AppTheme.errorColor, size: 28),
                      SizedBox(width: 12),
                      Text('PDF Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: AppTheme.displayFont)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Generate comprehensive patient reports in PDF format', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _exportAllPatientsPdf(context),
                      icon: const Icon(Icons.download),
                      label: const Text('Export All Patients as PDF'),
                    ),
                  ),
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
                  const Row(
                    children: [
                      Icon(Icons.insights, color: AppTheme.goldDeep, size: 28),
                      SizedBox(width: 12),
                      Text('Clinic Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: AppTheme.displayFont)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Daily or monthly visits, new patients, prescriptions and top diagnoses - as PDF or CSV', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showStatsDialog(context),
                      icon: const Icon(Icons.insights),
                      label: const Text('Generate Statistics Report'),
                    ),
                  ),
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
                  const Row(
                    children: [
                      Icon(Icons.table_chart, color: AppTheme.primaryColor, size: 28),
                      SizedBox(width: 12),
                      Text('CSV Export', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Export data as CSV for spreadsheet applications', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _exportPatientsCsv(context),
                      icon: const Icon(Icons.download),
                      label: const Text('Export Patients as CSV'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _exportInvestigationsCsv(context),
                      icon: const Icon(Icons.download),
                      label: const Text('Export Investigations as CSV'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAllPatientsPdf(BuildContext context) async {
    try {
      final db = DatabaseHelper();
      final patients = await db.getAllPatients();

      const navy = PdfColor.fromInt(0xFF0D2A5E);
      const navyDeep = PdfColor.fromInt(0xFF070F24);
      const gold = PdfColor.fromInt(0xFFD4AF37);
      const goldDeep = PdfColor.fromInt(0xFFB8860B);
      const goldLight = PdfColor.fromInt(0xFFF5E7B2);

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: await arabicPdfTheme(),
          build: (context) => [
            // Header band
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: goldLight,
                borderRadius: const pw.BorderRadius.only(
                  topLeft: pw.Radius.circular(8),
                  topRight: pw.Radius.circular(8),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('MediRecord',
                          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: navy, letterSpacing: 0.4)),
                      pw.SizedBox(height: 2),
                      pw.Text('PATIENT REPORT',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navyDeep, letterSpacing: 2)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Generated: ${DateTime.now().toIso8601String().split('T')[0]}',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                      pw.SizedBox(height: 4),
                      pw.Text('Total Patients: ${patients.length}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: goldDeep)),
                    ],
                  ),
                ],
              ),
            ),
            pw.Container(
              height: 4,
              decoration: const pw.BoxDecoration(
                gradient: pw.LinearGradient(colors: [goldDeep, goldLight, goldDeep]),
              ),
            ),
            pw.SizedBox(height: 16),
            ...patients.map((p) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: gold, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(arabicToPdf('${p.fullName}'),
                              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: navy)),
                          pw.SizedBox(width: 8),
                          pw.Text('(${p.age}y, ${arabicToPdf(p.gender)})',
                              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Age: ${p.age} | Blood Group: ${arabicToPdf(p.bloodGroup ?? '-')}',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Phone: ${arabicToPdf(p.phone ?? '-')} | Email: ${arabicToPdf(p.email ?? '-')}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
            )),
            pw.SizedBox(height: 20),
            pw.Container(
              height: 1.2,
              decoration: const pw.BoxDecoration(
                gradient: pw.LinearGradient(colors: [gold, goldLight, gold]),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('End of report',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                pw.Text('Generated by MediRecord Pro',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ],
            ),
          ],
        ),
      );

      final fileName = 'medirecord_patients_report.pdf';

      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF report', extensions: ['pdf']),
        ],
      );
      if (location == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Save cancelled')),
          );
        }
        return;
      }

      await File(location.path).writeAsBytes(await pdf.save());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to ${location.path}'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _exportPatientsCsv(BuildContext context) async {
    try {
      final db = DatabaseHelper();
      final patients = await db.getAllPatients();

      final rows = <List<String>>[
        ['ID', 'First Name', 'Last Name', 'Age', 'Gender', 'Phone', 'Email', 'Blood Group', 'Address'],
        ...patients.map((p) => [
          p.id,
          p.firstName,
          p.lastName,
          p.age.toString(),
          p.gender,
          p.phone ?? '',
          p.email ?? '',
          p.bloodGroup ?? '',
          p.address ?? '',
        ]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(csv.codeUnits);
      await PlatformHelper.downloadBytes(bytes, 'medirecord_patients.csv');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV downloaded'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _exportInvestigationsCsv(BuildContext context) async {
    try {
      final db = DatabaseHelper();
      final allInvestigations = <List<String>>[];

      final patients = await db.getAllPatients();
      for (final p in patients) {
        final invs = await db.getPatientInvestigations(p.id);
        for (final inv in invs) {
          allInvestigations.add([
            p.fullName,
            inv.testName,
            inv.category,
            inv.result ?? '',
            inv.normalRange ?? '',
            inv.unit ?? '',
            inv.investigationDate,
            inv.isAbnormal ? 'Yes' : 'No',
          ]);
        }
      }

      final rows = <List<String>>[
        ['Patient', 'Test Name', 'Category', 'Result', 'Normal Range', 'Unit', 'Date', 'Abnormal'],
        ...allInvestigations,
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(csv.codeUnits);
      await PlatformHelper.downloadBytes(bytes, 'medirecord_investigations.csv');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV downloaded'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _showStatsDialog(BuildContext context) async {
    String mode = 'today';
    DateTime day = DateTime.now();
    int year = DateTime.now().year;
    int month = DateTime.now().month;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          (DateTime, DateTime) range() {
            if (mode == 'yesterday') {
              final y = DateTime.now().subtract(const Duration(days: 1));
              return (y, y);
            }
            if (mode == 'day') return (day, day);
            if (mode == 'month') {
              final start = DateTime(year, month);
              final end = DateTime(year, month + 1, 0);
              return (start, end);
            }
            return (DateTime.now(), DateTime.now());
          }

          return AlertDialog(
            backgroundColor: AppTheme.navyDeep,
            title: const Text('Clinic Statistics', style: TextStyle(color: AppTheme.champagneLight)),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in const [
                        ('today', 'Today'),
                        ('yesterday', 'Yesterday'),
                        ('day', 'Pick a day'),
                        ('month', 'Pick a month'),
                      ])
                        ChoiceChip(
                          label: Text(m.$2, style: const TextStyle(color: Colors.white)),
                          selected: mode == m.$1,
                          selectedColor: AppTheme.goldColor,
                          onSelected: (_) => setDialogState(() => mode = m.$1),
                          backgroundColor: const Color(0xFF101D45),
                          labelStyle: TextStyle(color: mode == m.$1 ? Colors.black : Colors.white),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (mode == 'day')
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: day,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setDialogState(() => day = picked);
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: AppTheme.champagne),
                      ),
                    ),
                  if (mode == 'month')
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: month,
                            dropdownColor: const Color(0xFF101D45),
                            decoration: const InputDecoration(labelText: 'Month'),
                            items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(_monthName(m)))],
                            onChanged: (v) => setDialogState(() => month = v ?? month),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: year,
                            dropdownColor: const Color(0xFF101D45),
                            decoration: const InputDecoration(labelText: 'Year'),
                            items: [for (var y = DateTime.now().year; y >= 2020; y--) DropdownMenuItem(value: y, child: Text('$y'))],
                            onChanged: (v) => setDialogState(() => year = v ?? year),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              TextButton.icon(
                onPressed: () async {
                  final r = range();
                  Navigator.pop(dialogContext);
                  await _exportStats(context, r.$1, r.$2, csv: false);
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF', style: TextStyle(color: AppTheme.champagne)),
              ),
              TextButton.icon(
                onPressed: () async {
                  final r = range();
                  Navigator.pop(dialogContext);
                  await _exportStats(context, r.$1, r.$2, csv: true);
                },
                icon: const Icon(Icons.table_chart),
                label: const Text('CSV', style: TextStyle(color: AppTheme.champagne)),
              ),
            ],
          );
        },
      ),
    );
  }

  String _monthName(int m) => const [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ][m - 1];

  Future<void> _exportStats(BuildContext context, DateTime start, DateTime end, {required bool csv}) async {
    try {
      final stats = await DatabaseHelper().getClinicStats(start, end);
      if (!context.mounted) return;

      final title = '${stats['from']} to ${stats['to']}';

      if (csv) {
        final rows = <List<String>>[
          ['Metric', 'Value'],
          ['Period', title],
          ['New patients', '${stats['new_patients']}'],
          ['New male', '${stats['new_male']}'],
          ['New female', '${stats['new_female']}'],
          ['Visits (examinations)', '${stats['examinations']}'],
          ['Unique visiting patients', '${stats['unique_visits']}'],
          ['Prescriptions', '${stats['prescriptions']}'],
          ['Dispensed', '${stats['dispensed']}'],
          ['Investigations', '${stats['investigations']}'],
          ['Abnormal results', '${stats['abnormal']}'],
          [],
          ['Date', 'New patients', 'Visits', 'Unique patients', 'Prescriptions', 'Dispensed', 'Investigations'],
          ...(stats['daily'] as List).map((d) => [
            '${d['date']}',
            '${d['new_patients']}',
            '${d['visits']}',
            '${d['unique_patients']}',
            '${d['prescriptions']}',
            '${d['dispensed']}',
            '${d['investigations']}',
          ]),
          [],
          ['Top diagnosis', 'Count'],
          ...(stats['top_diagnoses'] as List).map((d) => ['${d['diagnosis']}', '${d['count']}']),
        ];
        final csvData = const ListToCsvConverter().convert(rows);
        final bytes = Uint8List.fromList(csvData.codeUnits);
        await PlatformHelper.downloadBytes(bytes, 'medirecord_stats_$title.csv');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Statistics CSV downloaded'), backgroundColor: AppTheme.successColor),
        );
        return;
      }

      const navy = PdfColor.fromInt(0xFF0D2A5E);
      const gold = PdfColor.fromInt(0xFFD4AF37);
      const goldLight = PdfColor.fromInt(0xFFF5E7B2);
      const goldSoft = PdfColor.fromInt(0xFFD4AF37);

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: await arabicPdfTheme(),
          build: (_) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: goldLight,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('MediRecord - Clinic Statistics',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: navy)),
                  pw.Text('Period: $title', style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Value'],
              data: [
                ['New patients', '${stats['new_patients']}  (M: ${stats['new_male']} / F: ${stats['new_female']})'],
                ['Visits (examinations)', '${stats['examinations']}'],
                ['Unique visiting patients', '${stats['unique_visits']}'],
                ['Prescriptions', '${stats['prescriptions']}'],
                ['Dispensed', '${stats['dispensed']}'],
                ['Investigations', '${stats['investigations']}'],
                ['Abnormal results', '${stats['abnormal']}'],
              ],
              headerStyle: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: navy),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: goldLight),
              cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft},
            ),
            if ((stats['top_diagnoses'] as List).isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text('Top diagnoses', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: navy)),
              pw.SizedBox(height: 6),
              ...(stats['top_diagnoses'] as List).map((d) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text('  ${arabicToPdf('${d['diagnosis']}')} - ${d['count']}',
                    style: const pw.TextStyle(fontSize: 10)),
              )),
            ],
            if ((stats['daily'] as List).isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text('Daily breakdown',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: navy)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'New', 'Visits', 'Unique', 'Rx', 'Disp.', 'Inv.'],
                data: (stats['daily'] as List).map((d) => [
                  '${d['date']}',
                  '${d['new_patients']}',
                  '${d['visits']}',
                  '${d['unique_patients']}',
                  '${d['prescriptions']}',
                  '${d['dispensed']}',
                  '${d['investigations']}',
                ]).toList(),
                headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navy),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: pw.BoxDecoration(color: goldSoft),
                cellAlignments: {for (var c = 0; c < 7; c++) c: pw.Alignment.centerLeft},
              ),
            ],
            pw.SizedBox(height: 16),
            pw.Divider(color: gold),
            pw.Text('Generated: ${DateTime.now().toIso8601String().split('T').first}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          ],
        ),
      );

      final fileName = 'medirecord_stats_$title.pdf';
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF report', extensions: ['pdf']),
        ],
      );
      if (location == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save cancelled')));
        }
        return;
      }
      await File(location.path).writeAsBytes(await pdf.save());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to ${location.path}'), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}
