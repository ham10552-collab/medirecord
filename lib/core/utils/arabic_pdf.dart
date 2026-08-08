/// Presentation form codepoints for Arabic letters.
/// Mapping: base letter -> [isolated, final, initial, medial]
const Map<int, List<int>> _arabicForms = <int, List<int>>{
  0x0622: [0xFE81, 0xFE82], // Alef madda
  0x0623: [0xFE83, 0xFE84], // Alef hamza above
  0x0624: [0xFE85, 0xFE86], // Waw hamza
  0x0625: [0xFE87, 0xFE88], // Alef hamza below
  0x0626: [0xFE89, 0xFE8A, 0xFE8B, 0xFE8C], // Yeh hamza
  0x0627: [0xFE8D, 0xFE8E], // Alef
  0x0628: [0xFE8F, 0xFE90, 0xFE91, 0xFE92], // Beh
  0x0629: [0xFE93, 0xFE94], // Teh marbuta
  0x062A: [0xFE95, 0xFE96, 0xFE97, 0xFE98], // Teh
  0x062B: [0xFE99, 0xFE9A, 0xFE9B, 0xFE9C], // Theh
  0x062C: [0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0], // Jeem
  0x062D: [0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4], // Hah
  0x062E: [0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8], // Khah
  0x062F: [0xFEA9, 0xFEAA], // Dal
  0x0630: [0xFEAB, 0xFEAC], // Thal
  0x0631: [0xFEAD, 0xFEAE], // Reh
  0x0632: [0xFEAF, 0xFEB0], // Zain
  0x0633: [0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4], // Seen
  0x0634: [0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8], // Sheen
  0x0635: [0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC], // Sad
  0x0636: [0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0], // Dad
  0x0637: [0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4], // Tah
  0x0638: [0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8], // Zah
  0x0639: [0xFEC9, 0xFECA, 0xFECB, 0xFECC], // Ain
  0x063A: [0xFECD, 0xFECE, 0xFECF, 0xFED0], // Ghain
  0x0641: [0xFED1, 0xFED2, 0xFED3, 0xFED4], // Feh
  0x0642: [0xFED5, 0xFED6, 0xFED7, 0xFED8], // Qaf
  0x0643: [0xFED9, 0xFEDA, 0xFEDB, 0xFEDC], // Kaf
  0x0644: [0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0], // Lam
  0x0645: [0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4], // Meem
  0x0646: [0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8], // Noon
  0x0647: [0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC], // Heh
  0x0648: [0xFEED, 0xFEEE], // Waw
  0x0649: [0xFEEF, 0xFEF0], // Alef maksura
  0x064A: [0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4], // Yeh
};

/// Lam-alef ligatures: lam + alef-family -> [isolated, final]
const Map<int, List<int>> _lamAlefForms = <int, List<int>>{
  0x0622: [0xFEF5, 0xFEF6], // Lam + Alef madda
  0x0623: [0xFEF7, 0xFEF8], // Lam + Alef hamza above
  0x0625: [0xFEF9, 0xFEFA], // Lam + Alef hamza below
  0x0627: [0xFEFB, 0xFEFC], // Lam + Alef
};

/// Letters that join only on the right side (never connect to the next glyph).
const Set<int> _rightJoining = <int>{
  0x0622, 0x0623, 0x0624, 0x0625, 0x0627, 0x0629, 0x062F, 0x0630, 0x0631,
  0x0632, 0x0648,
};

/// Dual-joining letters (connect on both sides).
const Set<int> _dualJoining = <int>{
  0x0626, 0x0628, 0x062A, 0x062B, 0x062C, 0x062D, 0x062E, 0x0633, 0x0634,
  0x0635, 0x0636, 0x0637, 0x0638, 0x0639, 0x063A, 0x0641, 0x0642, 0x0643,
  0x0644, 0x0645, 0x0646, 0x0647, 0x0649, 0x064A,
};

/// Transparent combining marks (do not affect joining decisions).
const Set<String> _transparent = <String>{
  '\u0610', '\u0611', '\u0612', '\u0613', '\u0614', '\u0615', '\u0616',
  '\u0617', '\u0618', '\u0619', '\u061A',
  '\u064B', '\u064C', '\u064D', '\u064E', '\u064F', '\u0650', '\u0651',
  '\u0652', '\u0653', '\u0654', '\u0655', '\u0656', '\u0657', '\u0658',
  '\u0659', '\u065A', '\u065B', '\u065C', '\u065D', '\u065E', '\u065F',
  '\u0670',
};

bool isArabicLetter(int cp) => cp >= 0x0600 && cp <= 0x06FF;

bool isTransparent(int cp) => _transparent.contains(String.fromCharCode(cp));

/// Shapes a logical-order Arabic string into joined presentation forms,
/// including lam-alef ligatures.
String _shapeArabic(String input) {
  final chars = input.codeUnits;
  final n = chars.length;
  final out = <int>[];

  for (var i = 0; i < n; i++) {
    final c = chars[i];
    if (!isArabicLetter(c) || isTransparent(c)) {
      out.add(c);
      continue;
    }

    // Find previous and next significant characters (skip transparent marks).
    var prevCp = -1;
    var nextCp = -1;
    var nextIdx = -1;
    for (var j = i - 1; j >= 0; j--) {
      final p = chars[j];
      if (!isArabicLetter(p)) {
        prevCp = -1;
        break;
      }
      if (isTransparent(p)) continue;
      prevCp = p;
      break;
    }
    for (var j = i + 1; j < n; j++) {
      final nx = chars[j];
      if (!isArabicLetter(nx)) {
        nextCp = -1;
        break;
      }
      if (isTransparent(nx)) continue;
      nextCp = nx;
      nextIdx = j;
      break;
    }

    final prevJoins = prevCp != -1 && _dualJoining.contains(prevCp);
    final nextJoins = nextCp != -1 &&
        (_rightJoining.contains(nextCp) || _dualJoining.contains(nextCp));

    // Lam-alef ligature: lam followed directly by an alef family letter.
    if (c == 0x0644 && nextCp != -1 && _lamAlefForms.containsKey(nextCp)) {
      final ligs = _lamAlefForms[nextCp]!;
      out.add(prevJoins ? ligs[1] : ligs[0]);
      i = nextIdx; // Skip the alef consumed by the ligature.
      continue;
    }

    final forms = _arabicForms[c];
    if (forms == null || forms.isEmpty) {
      out.add(c);
      continue;
    }

    if (_rightJoining.contains(c)) {
      // Only isolated/final forms.
      out.add(prevJoins ? forms[1] : forms[0]);
    } else {
      int idx;
      if (prevJoins && nextJoins) {
        idx = (forms.length == 4) ? 3 : 1; // medial
      } else if (prevJoins) {
        idx = 1; // final
      } else if (nextJoins) {
        idx = (forms.length == 4) ? 2 : 1; // initial
      } else {
        idx = 0; // isolated
      }
      out.add(forms[idx]);
    }
  }
  return String.fromCharCodes(out);
}

/// Returns true if the string contains Arabic letters.
bool containsArabic(String s) {
  for (final rune in s.runes) {
    if (isArabicLetter(rune) && !isTransparent(rune)) return true;
  }
  return false;
}

bool _isLatinOrDigit(int cp) {
  return (cp >= 0x30 && cp <= 0x39) || // digits
      (cp >= 0x41 && cp <= 0x5A) || // A-Z
      (cp >= 0x61 && cp <= 0x7A) || // a-z
      cp == 0x2E || cp == 0x2F || cp == 0x3A || // . / :
      cp == 0x25 || cp == 0x2D || cp == 0x2B || cp == 0x28 || cp == 0x29 ||
      cp == 0x2C; // % - + ( ) ,
}

/// Reverses a fully-shaped line for RTL display: the whole string runs in
/// reverse, but consecutive latin/digit/punct runs are re-reversed so they
/// stay in natural left-to-right order (same behaviour as pdf's bidi).
String _reorderToVisual(String s) {
  final chars = s.codeUnits;
  final n = chars.length;
  // 1. Reverse the entire line.
  final rev = chars.reversed.toList();
  // 2. Re-reverse latin/digit/punct runs so they keep LTR order.
  final out = <int>[];
  var i = 0;
  while (i < n) {
    if (_isLatinOrDigit(rev[i])) {
      final start = i;
      while (i < n && _isLatinOrDigit(rev[i])) {
        i++;
      }
      out.addAll(rev.sublist(start, i).reversed);
    } else {
      out.add(rev[i]);
      i++;
    }
  }
  return String.fromCharCodes(out);
}

/// Converts an Arabic-capable string into a PDF-safe visual string:
/// shapes the letters, then reverses it so the document's linear renderer
/// shows right-to-left Arabic correctly. Non-Arabic strings pass through.
String arabicToPdf(String text) {
  if (text.isEmpty || !containsArabic(text)) return text;
  return _reorderToVisual(_shapeArabic(text));
}