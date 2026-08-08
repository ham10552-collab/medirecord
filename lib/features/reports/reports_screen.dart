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
}
