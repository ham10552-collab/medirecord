import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

pw.Font? _arabicRegular;
pw.Font? _arabicBold;

Future<pw.Font> _load(String path) async {
  final ByteData data = await rootBundle.load(path);
  return pw.Font.ttf(data);
}

Future<pw.Font> arabicRegular() async =>
    _arabicRegular ??= await _load('assets/fonts/Amiri-Regular.ttf');
Future<pw.Font> arabicBold() async =>
    _arabicBold ??= await _load('assets/fonts/Amiri-Bold.ttf');

/// Returns a theme where both Latin and Arabic text render correctly.
/// Amiri contains Latin + Arabic glyphs with full Arabic shaping support
/// (connected letters, ligatures) handled by the pdf package.
Future<pw.ThemeData> arabicPdfTheme() async {
  final regular = await arabicRegular();
  final bold = await arabicBold();
  return pw.ThemeData.withFont(
    base: regular,
    bold: bold,
    fontFallback: [regular, bold],
  );
}