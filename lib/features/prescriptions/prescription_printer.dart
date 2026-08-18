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

/// Generates a pharmacy dispensing copy directly from the pharmacy queue row
/// (no full Patient object is available on the pharmacist device).
Future<String> generatePharmacyPdf(Map<String, dynamic> rx, String pharmacistName) async {
  final pdf = pw.Document();

  final created = (rx['created_at'] as String? ?? '');
  final date = created.length >= 10 ? created.substring(0, 10) : created;
  final items = ((rx['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
  final isDispensed = (rx['status'] as String?) == 'dispensed';
  final dispensedDisplay = rx['dispensed_at'] as String? ?? '';

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
                  pw.Text('PHARMACY DISPENSING COPY',
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
                  pw.Text('ID: ${(rx['id'] as String? ?? '').substring(0, 8)}',
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

        // Dispense stamp
        if (isDispensed)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE8F5E9),
              border: pw.Border.all(color: PdfColor.fromInt(0xFF2E7D32), width: 1.4),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              children: [
                pw.Text('DISPENSED',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF2E7D32),
                      letterSpacing: 2,
                    )),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Text(
                    'by ${(rx['pharmacist_name'] as String? ?? '').isNotEmpty ? rx['pharmacist_name'] : pharmacistName} on ${dispensedDisplay.length >= 10 ? dispensedDisplay.substring(0, 10) : dispensedDisplay}',
                    style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey800),
                  ),
                ),
              ],
            ),
          ),
        if (isDispensed) pw.SizedBox(height: 14),

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
                  pw.Text(arabicToPdf(rx['patient_name'] as String? ?? 'Unknown'),
                      style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Text('Doctor: ', style: const pw.TextStyle(fontSize: 10.5)),
                  pw.Text(arabicToPdf(rx['doctor_name'] as String? ?? '-'),
                      style: const pw.TextStyle(fontSize: 10.5)),
                  pw.SizedBox(width: 10),
                  pw.Text('Rx ID: ', style: const pw.TextStyle(fontSize: 10.5)),
                  pw.Text((rx['id'] as String? ?? '').substring(0, 8),
                      style: const pw.TextStyle(fontSize: 10.5)),
                  if ((rx['pharmacist_name'] as String? ?? '').isNotEmpty) ...[
                    pw.SizedBox(width: 10),
                    pw.Text('Pharmacist: ', style: const pw.TextStyle(fontSize: 10.5)),
                    pw.Text(arabicToPdf(rx['pharmacist_name'] as String),
                        style: const pw.TextStyle(fontSize: 10.5)),
                  ],
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 14),

        // Diagnosis
        if ((rx['diagnosis'] as String? ?? '').isNotEmpty) ...[
          pw.Row(
            children: [
              pw.Text('Diagnosis:',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _navy)),
              pw.SizedBox(width: 6),
              pw.Expanded(child: pw.Text(arabicToPdf(rx['diagnosis'] as String), style: const pw.TextStyle(fontSize: 12))),
            ],
          ),
          pw.SizedBox(height: 14),
        ],

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
        ...items.asMap().entries.map((entry) {
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
            ),
            child: pw.Row(
              children: [
                pw.Expanded(flex: 3, child: pw.Text(arabicToPdf('$idx.  ${item['medicine_name']}'), style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 2, child: pw.Text(arabicToPdf(item['dosage'] as String? ?? ''), style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(flex: 2, child: pw.Text(arabicToPdf(item['frequency'] as String? ?? ''), style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(flex: 2, child: pw.Text(arabicToPdf(item['duration'] as String? ?? ''), style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(flex: 2, child: pw.Text(arabicToPdf(item['instructions'] as String? ?? ''), style: const pw.TextStyle(fontSize: 10))),
              ],
            ),
          );
        }),

        // Notes
        if ((rx['notes'] as String? ?? '').isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Text('Notes:',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
              pw.SizedBox(width: 6),
              pw.Expanded(child: pw.Text(arabicToPdf(rx['notes'] as String), style: const pw.TextStyle(fontSize: 10))),
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
                pw.Text(arabicToPdf(pharmacistName),
                    style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text('Pharmacist Signature',
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

  final fileName = 'pharmacy_rx_${(rx['id'] as String? ?? 'rx').substring(0, 8)}.pdf';
  return await PlatformHelper.savePdf(await pdf.save(), fileName);
}

/// Daily report of everything the pharmacy dispensed. [dateLabel] is shown
/// in the header (today's date, a picked date, or 'all').
Future<String> generatePharmacyReportPdf(
    List<Map<String, dynamic>> rows, String dateLabel) async {
  final pdf = pw.Document();
  final day = dateLabel;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(34),
      theme: await arabicPdfTheme(),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: _goldLight,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MediRecord',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                  )),
              pw.SizedBox(height: 2),
              pw.Text('PHARMACY DISPENSED REPORT',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _navyDeep)),
              pw.SizedBox(height: 4),
              pw.Text('Date: $day   •   Total dispensed: ${rows.length}',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _goldDeep)),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerDecoration: const pw.BoxDecoration(color: _navy),
          headerStyle: const pw.TextStyle(
              color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headers: ['#', 'Patient', 'Doctor', 'Pharmacist', 'Time', 'Items'],
          data: [
            for (var i = 0; i < rows.length; i++)
              [
                '${i + 1}',
                arabicToPdf(rows[i]['patient_name'] as String? ?? '-'),
                arabicToPdf(rows[i]['doctor_name'] as String? ?? '-'),
                arabicToPdf(rows[i]['dispensed_by'] as String? ?? '-'),
                ((rows[i]['dispensed_at'] as String? ?? '').length >= 16)
                    ? (rows[i]['dispensed_at'] as String).substring(11, 16)
                    : '-',
                '${(rows[i]['items'] as List?)?.length ?? 0}',
              ],
          ],
          oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF4F1E6)),
        ),
        pw.SizedBox(height: 30),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(arabicToPdf('Total prescriptions dispensed: ${rows.length}'),
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
            pw.Text('Generated by MediRecord Pro',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ],
    ),
  );

  return await PlatformHelper.savePdf(
      await pdf.save(), 'pharmacy_report_$day.pdf');
}

/// Generates a printable lab result sheet from a completed lab request.
Future<String> generateLabResultPdf(Map<String, dynamic> request) async {
  final pdf = pw.Document();
  final requested = (request['requested_at'] as String? ?? '');
  final completed = (request['completed_at'] as String? ?? '');
  final reqDate = requested.length >= 10 ? requested.substring(0, 10) : requested;
  final compDate = completed.length >= 10 ? completed.substring(0, 10) : completed;
  final items = ((request['items'] as List?) ?? const [])
      .map((i) => (i as Map).cast<String, dynamic>())
      .toList();
  final id = (request['id'] as String? ?? '');

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(34),
      theme: await arabicPdfTheme(),
      build: (ctx) => [
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
                  pw.Text('LABORATORY RESULT REPORT',
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
                child: pw.Text('Lab',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: _navy,
                    )),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Completed: $compDate',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  pw.SizedBox(height: 4),
                  pw.Text('ID: ${id.length >= 8 ? id.substring(0, 8) : id}',
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
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(arabicToPdf('Patient: ${request['patient_name'] ?? 'Unknown'}'),
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _navy)),
                if ((request['patient_phone'] as String? ?? '').trim().isNotEmpty)
                  pw.Text(arabicToPdf('Phone: ${request['patient_phone']}'),
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(arabicToPdf('Doctor: ${request['doctor_name'] ?? '-'}'),
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
                pw.Text('Ordered: $reqDate',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                if (((request['lab_technician'] as String?) ?? '').isNotEmpty)
                  pw.Text(arabicToPdf('Technician: ${request['lab_technician']}'),
                      style: pw.TextStyle(fontSize: 10, color: _goldDeep, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headerDecoration: const pw.BoxDecoration(color: _navy),
          headerStyle: const pw.TextStyle(
              color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headers: ['#', 'Test', 'Result', 'Normal Range', 'Unit', 'Flag'],
          data: [
            for (var i = 0; i < items.length; i++)
              [
                '${i + 1}',
                arabicToPdf('${items[i]['test_name'] ?? '-'}'
                    '${(items[i]['note'] as String? ?? '').trim().isEmpty ? '' : ' (${items[i]['note']})'}'),
                items[i]['value'] as String? ?? '-',
                (items[i]['normal_range'] as String? ?? '') == ''
                    ? '-'
                    : arabicToPdf(items[i]['normal_range'] as String),
                (items[i]['unit'] as String? ?? '') == ''
                    ? '-'
                    : arabicToPdf(items[i]['unit'] as String),
                (items[i]['abnormal'] == true) ? 'ABNORMAL' : 'Normal',
              ],
          ],
          oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF4F1E6)),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerLeft,
            4: pw.Alignment.centerLeft,
            5: pw.Alignment.centerLeft,
          },
        ),
        pw.SizedBox(height: 24),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(arabicToPdf('Results marked ABNORMAL fall outside the reference range.'),
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('Generated by MediRecord Pro',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ],
    ),
  );

  final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
  return await PlatformHelper.savePdf(await pdf.save(), 'lab_result_$stamp.pdf');
}
