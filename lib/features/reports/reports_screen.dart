import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/platform_helper.dart';
import '../../shared/widgets/app_drawer.dart';

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
                      Text('PDF Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => pw.Header(
            level: 0,
            child: pw.Text('MediRecord - Patient Report',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ),
          build: (context) => [
            pw.Paragraph(text: 'Generated: ${DateTime.now().toIso8601String().split('T')[0]}'),
            pw.Paragraph(text: 'Total Patients: ${patients.length}'),
            pw.SizedBox(height: 20),
            ...patients.map((p) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 2, text: '${p.fullName} (${p.age}y, ${p.gender})'),
                pw.Paragraph(text: 'Age: ${p.age} | Blood Group: ${p.bloodGroup ?? '-'}'),
                pw.Paragraph(text: 'Phone: ${p.phone ?? '-'} | Email: ${p.email ?? '-'}'),
                pw.Divider(),
                pw.SizedBox(height: 12),
              ],
            )),
          ],
        ),
      );

      final fileName = 'medirecord_patients_report.pdf';
      await PlatformHelper.savePdf(await pdf.save(), fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved as $fileName'), backgroundColor: AppTheme.successColor),
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
}
