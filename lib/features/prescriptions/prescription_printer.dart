import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/utils/arabic_pdf.dart';
import '../../core/utils/pdf_fonts.dart';
import '../../core/utils/platform_helper.dart';
import '../../shared/models/prescription.dart';
import '../../shared/models/patient.dart';

const _navy = PdfColor.fromInt(0xFF0D2A5E);
const _navyDeep = PdfColor.fromInt(0xFF070F24);
const _gold = PdfColor.fromInt(0xFFD4AF37);
const _goldDeep = PdfColor.fromInt(0xFFB8860B);
const _goldLight = PdfColor.fromInt(0xFFF5E7B2);

Future<String> generatePrescriptionPdf(Prescription prescription, Patient patient) async {
  final pdf = pw.Document();

  final date = prescription.createdAt.length >= 10 ? prescription.createdAt.substring(0, 10) : prescription.createdAt;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(34),
      theme: await arabicPdfTheme(),
      build: (ctx) => [
        // Header: navy band with "Rx" seal + brand
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _goldLight,
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
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy,
                        letterSpacing: 0.4,
                      )),
                  pw.SizedBox(height: 2),
                  pw.Text('PRESCRIPTION',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _navyDeep,
                        letterSpacing: 2,
                      )),
                ],
              ),
              pw.Container(
                width: 42,
                height: 42,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: _navy, width: 2),
                ),
                alignment: pw.Alignment.center,
                child: pw.Text('Rx',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy,
                      fontStyle: pw.FontStyle.italic,
                    )),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Date: $date',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  pw.SizedBox(height: 4),
                  pw.Text('ID: ${prescription.id.substring(0, 8)}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ),
        pw.Container(
          height: 4,
          decoration: const pw.BoxDecoration(
            gradient: pw.LinearGradient(colors: [_goldDeep, _goldLight, _goldDeep]),
          ),
        ),
        pw.SizedBox(height: 16),

        // Patient info (gold hairline frame)
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _gold, width: 1.1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text('Patient:',
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _navy)),
                  pw.SizedBox(width: 6),
                  pw.Text(arabicToPdf(patient.fullName),
                      style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Text('Age: ', style: const pw.TextStyle(fontSize: 10.5)),
                  pw.Text('${patient.age}',
                      style: const pw.TextStyle(fontSize: 10.5)),
                  pw.SizedBox(width: 10),
                  pw.Text('Gender: ', style: const pw.TextStyle(fontSize: 10.5)),
                  pw.Text(patient.gender, style: const pw.TextStyle(fontSize: 10.5)),
                  if (patient.phone != null) ...[
                    pw.SizedBox(width: 10),
                    pw.Text('Phone: ', style: const pw.TextStyle(fontSize: 10.5)),
                    pw.Text(patient.phone!, style: const pw.TextStyle(fontSize: 10.5)),
                  ],
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),

        // Doctor & diagnosis
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Row(
                children: [
                  pw.Text('Doctor:',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _navy)),
                  pw.SizedBox(width: 6),
                  pw.Text(arabicToPdf(prescription.doctorName), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        if (prescription.diagnosis.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Text('Diagnosis:',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _navy)),
              pw.SizedBox(width: 6),
              pw.Expanded(child: pw.Text(arabicToPdf(prescription.diagnosis), style: const pw.TextStyle(fontSize: 12))),
            ],
          ),
        ],
        pw.SizedBox(height: 14),

        // Table header (navy)
        pw.Container(
          decoration: pw.BoxDecoration(
            gradient: const pw.LinearGradient(colors: [_navy, _navyDeep]),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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

        // Items (with alternating gold tint rows)
        ...prescription.items.asMap().entries.map((entry) {
          final item = entry.value;
          final idx = entry.key + 1;
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: pw.BoxDecoration(
              color: idx.isOdd ? PdfColors.white : PdfColor.fromInt(0xFFFBF4DC),
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey200),
                left: idx.isOdd ? pw.BorderSide(color: PdfColors.grey300, width: 0.6) : pw.BorderSide(color: _gold, width: 1),
              ),
            ),            child: pw.Row(
              children: [
                pw.Expanded(flex: 3, child: pw.Text(arabicToPdf('$idx.  ${item.medicineName}'), style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 2, child: pw.Text(arabicToPdf(item.dosage), style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(flex: 2, child: pw.Text(arabicToPdf(item.frequency), style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(flex: 2, child: pw.Text(arabicToPdf(item.duration), style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(flex: 2, child: pw.Text(arabicToPdf(item.instructions), style: const pw.TextStyle(fontSize: 10))),
              ],
            ),
          );
        }),

        // Notes
        if (prescription.notes.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Text('Notes:',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
              pw.SizedBox(width: 6),
              pw.Expanded(child: pw.Text(arabicToPdf(prescription.notes), style: const pw.TextStyle(fontSize: 10))),
            ],
          ),
        ],

        // Footer
        pw.SizedBox(height: 44),
        pw.Container(
          height: 1.2,
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(colors: [_gold, PdfColor.fromInt(0xFFF8EDC8), _gold]),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(arabicToPdf(prescription.doctorName),
                    style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Doctor Signature',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ],
            ),
            pw.Text('Generated by MediRecord Pro',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
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
