import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/theme/app_theme.dart';
import '../../core/utils/platform_helper.dart';
import '../../shared/models/prescription.dart';
import '../../shared/models/patient.dart';
import '../../core/database/database_helper.dart';

const _accentColor = PdfColor.fromInt(0xFF1565C0);

Future<String> generatePrescriptionPdf(Prescription prescription, Patient patient) async {
  final pdf = pw.Document();

  final date = prescription.createdAt.length >= 10 ? prescription.createdAt.substring(0, 10) : prescription.createdAt;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        // Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('MediRecord', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _accentColor)),
                pw.Text('Prescription', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
              ],
            ),
            pw.Text('Date: $date', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Divider(color: _accentColor, thickness: 1.5),
        pw.SizedBox(height: 12),

        // Patient info
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Patient: ${patient.fullName}', style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Age: ${patient.age}  |  Gender: ${patient.gender}'),
              if (patient.phone != null) pw.Text('Phone: ${patient.phone}'),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // Doctor & diagnosis
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text('Doctor: ${prescription.doctorName}', style: const pw.TextStyle(fontSize: 12)),
            ),
          ],
        ),
        if (prescription.diagnosis.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text('Diagnosis: ${prescription.diagnosis}', style: const pw.TextStyle(fontSize: 12)),
        ],
        pw.SizedBox(height: 16),

        // Rx symbol
        pw.Text('Rx', style: pw.TextStyle(
          fontSize: 22,
          fontWeight: pw.FontWeight.bold,
          color: _accentColor,
          fontStyle: pw.FontStyle.italic,
        )),
        pw.SizedBox(height: 8),

        // Table header
        pw.Container(
          decoration: pw.BoxDecoration(
            color: _accentColor,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Row(
            children: [
              pw.Expanded(flex: 3, child: pw.Text('#  Medicine', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 2, child: pw.Text('Dosage', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 2, child: pw.Text('Frequency', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 2, child: pw.Text('Duration', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 2, child: pw.Text('Instructions', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
            ],
          ),
        ),
        pw.SizedBox(height: 2),

        // Items
        ...prescription.items.asMap().entries.map((entry) {
          final item = entry.value;
          final idx = entry.key + 1;
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(flex: 3, child: pw.Text('$idx.  ${item.medicineName}', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 2, child: pw.Text(item.dosage, style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(flex: 2, child: pw.Text(item.frequency, style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(flex: 2, child: pw.Text(item.duration, style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(flex: 2, child: pw.Text(item.instructions, style: const pw.TextStyle(fontSize: 10))),
              ],
            ),
          );
        }),

        // Notes
        if (prescription.notes.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Notes:', style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(prescription.notes, style: const pw.TextStyle(fontSize: 10)),
        ],

        // Footer
        pw.SizedBox(height: 40),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Doctor Signature: ___________________', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.Text('Generated by MediRecord', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
          ],
        ),
      ],
    ),
  );

  final fileName = '${patient.fullName.replaceAll(' ', '_')}_prescription_${prescription.id.substring(0, 8)}.pdf';
  return await PlatformHelper.savePdf(await pdf.save(), fileName);
}

Future<void> openPdfForPrint(BuildContext context, String filePath) async {
  await PlatformHelper.openFile(filePath);
}

Future<void> printPrescriptionDirect(BuildContext context, String filePath) async {
  await PlatformHelper.openFile(filePath);
}
