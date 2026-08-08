import 'package:flutter/material.dart';

class AppTheme {
  // Rich navy + champagne gold luxury palette
  static const Color navyDeep = Color(0xFF070F24);
  static const Color navyDark = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF0D2A5E);
  static const Color navyMid = Color(0xFF123B8C);
  static const Color primaryColor = Color(0xFF0D2A5E);
  static const Color primaryLight = Color(0xFF1550B8);
  static const Color secondaryColor = Color(0xFF00BFA5);
  static const Color champagne = Color(0xFFD4AF37);
  static const Color champagneLight = Color(0xFFF5E7B2);
  static const Color goldColor = Color(0xFFD4AF37);
  static const Color goldDeep = Color(0xFFB8860B);
  static const Color goldLight = Color(0xFFE7C95A);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFFA726);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF6F7FB);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF141B2D);
  static const Color textSecondary = Color(0xFF5D6B87);
  static const Color dividerColor = Color(0xFFE8E9EF);

  // Royal blue gradient (hero surfaces)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyMid, navy],
  );

  static const LinearGradient royalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF153D7E), Color(0xFF0A1F44), Color(0xFF070F24)],
  );

  // Champagne gold gradient
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [champagneLight, champagne, goldDeep],
  );

  static const LinearGradient heroGradient = royalGradient;

  // Hint shimmering gold text gradient (for signatures / prime text)
  static const LinearGradient goldTextGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8E7A0), champagne, goldDeep],
  );

  // Elegant display font used for luxury headings
  static const String displayFont = 'Georgia';

  static TextStyle displayStyle({double size = 26, Color color = navy, FontWeight weight = FontWeight.w700, bool gold = false}) {
    return TextStyle(
      fontFamily: displayFont,
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: 0.4,
      shadows: gold
          ? const [Shadow(color: Color(0x33D4AF37), blurRadius: 6, offset: Offset(0, 1))]
          : const [Shadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))],
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: base.colorScheme.copyWith(
        primary: primaryColor,
        secondary: goldColor,
        error: errorColor,
        surface: surfaceColor,
        onSurface: textPrimary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: goldColor,
        linearTrackColor: Color(0x1AD4AF37),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered) ? goldDeep : goldColor.withValues(alpha: 0.65)),
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(false),
        thickness: WidgetStateProperty.all(9),
        radius: const Radius.circular(10),
        minThumbLength: 42,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          fontFamily: displayFont,
        ),
        iconTheme: IconThemeData(color: textPrimary),
        shape: Border(
          bottom: BorderSide(color: Color(0x33D4AF37), width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x140D2A5E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: dividerColor, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: goldColor,
          foregroundColor: navyDeep,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.pressed) ? navyDeep.withValues(alpha: 0.16) : goldLight.withValues(alpha: 0.35)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.pressed) ? Colors.white.withValues(alpha: 0.18) : goldColor.withValues(alpha: 0.12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: goldColor, width: 1.2),
          minimumSize: const Size(double.infinity, 50),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.pressed) ? primaryColor.withValues(alpha: 0.14) : goldColor.withValues(alpha: 0.25)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: Color(0xFF9AA5B8)),
        labelStyle: const TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: goldColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: goldColor,
        foregroundColor: navyDeep,
        elevation: 6,
      ),
      dividerTheme: const DividerThemeData(color: dividerColor, thickness: 0.8),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: goldColor.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: goldColor, width: 1),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: goldColor, width: 1.1),
        ),
      ),
      pageTransitionsTheme: _pageTransitions,
    );
  }

  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    },
  );

  static ThemeData get darkTheme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0A0F20),
      colorScheme: base.colorScheme.copyWith(
        primary: champagne,
        secondary: champagne,
        surface: const Color(0xFF11172B),
        onSurface: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: goldColor,
        linearTrackColor: Color(0x1AD4AF37),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.hovered) ? goldLight : goldColor.withValues(alpha: 0.55)),
        thumbVisibility: WidgetStateProperty.all(true),
        trackVisibility: WidgetStateProperty.all(false),
        thickness: WidgetStateProperty.all(9),
        radius: const Radius.circular(10),
        minThumbLength: 42,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: displayFont,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        shape: Border(
          bottom: BorderSide(color: Color(0x3DD4AF37), width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF11172B),
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x33000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF2A3350)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldColor,
          foregroundColor: const Color(0xFF0A0F20),
          minimumSize: const Size(double.infinity, 50),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.pressed) ? navyDeep.withValues(alpha: 0.2) : champagneLight.withValues(alpha: 0.3)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE7C87A),
          side: const BorderSide(color: champagne, width: 1.2),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.pressed) ? champagne.withValues(alpha: 0.16) : champagne.withValues(alpha: 0.25)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF11172B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2A3350)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: champagne, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2A3350), thickness: 0.8),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: champagne,
        foregroundColor: Color(0xFF0A0F20),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF11172B),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: champagne, width: 1),
        ),
      ),
      pageTransitionsTheme: _pageTransitions,
    );
  }
}

// Backwards-compatible alias for the pre-existing gold shades
abstract final class MainColors {
  static const Color champagne = AppTheme.champagne;
  static const Color champagneLight = AppTheme.champagneLight;
}