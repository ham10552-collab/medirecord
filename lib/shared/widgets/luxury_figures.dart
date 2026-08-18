import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Ornate gold medical cross figure used as the brand emblem.
class MedicalCrossFigure extends StatelessWidget {
  final double size;
  final bool gold;
  const MedicalCrossFigure({super.key, this.size = 22, this.gold = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.9,
      height: size * 1.9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gold ? AppTheme.goldGradient : AppTheme.heroGradient,
        border: Border.all(color: gold ? AppTheme.goldLight : Colors.white, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: (gold ? AppTheme.goldColor : AppTheme.primaryColor).withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _CrossPainter(color: gold ? AppTheme.navyDeep : Colors.white)),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  final Color color;
  const _CrossPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final bar = size.width * 0.3;
    final rect = Offset.zero & size;
    canvas.drawRect(Rect.fromCenter(center: rect.center, width: bar, height: size.height), paint);
    canvas.drawRect(Rect.fromCenter(center: rect.center, width: size.width, height: bar), paint);
  }

  @override
  bool shouldRepaint(covariant _CrossPainter oldDelegate) => oldDelegate.color != color;
}

/// Decorative sparkling star figure.
class SparkleFigure extends StatelessWidget {
  final double size;
  final Color color;
  const SparkleFigure({super.key, this.size = 16, this.color = AppTheme.champagne});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SparklePainter(color: color),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;
  const _SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), paint);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), paint);
    final sr = r * 0.42;
    canvas.drawLine(Offset(c.dx - sr, c.dy - sr), Offset(c.dx + sr, c.dy + sr), paint);
    canvas.drawLine(Offset(c.dx + sr, c.dy - sr), Offset(c.dx - sr, c.dy + sr), paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) => oldDelegate.color != color;
}

/// Ornamental divider: gold line with diamond + sparkles in the middle.
class GoldDivider extends StatelessWidget {
  final String? label;
  final double thickness;
  const GoldDivider({super.key, this.label, this.thickness = 1.2});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: thickness,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, AppTheme.goldColor.withValues(alpha: 0.7)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: label == null
              ? Transform.rotate(angle: 0.785, child: Icon(Icons.square_rounded, size: 9, color: AppTheme.goldColor))
              : Text(label!, style: AppTheme.displayStyle(size: 15, color: AppTheme.navy)),
        ),
        Expanded(
          child: Container(
            height: thickness,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.goldColor.withValues(alpha: 0.7), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Corner flourish ornament drawn on card corners (top-left style).
class CornerOrnament extends StatelessWidget {
  final double size;
  final Color color;
  const CornerOrnament({super.key, this.size = 26, this.color = AppTheme.champagne});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CornerPainter(color: color),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final s = size.width;
    // Right angle brace
    final path = Path()
      ..moveTo(s, 0)
      ..lineTo(s * 0.62, 0)
      ..lineTo(s * 0.62, s * 0.38)
      ..lineTo(s, s * 0.38);
    canvas.drawPath(path, paint);
    // Inner small diamond
    final d = Paint()..color = color;
    final c = Offset(s * 0.62, s * 0.38);
    canvas.drawCircle(c, 1.6, d);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(0.785);
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 7, height: 7), d..style = PaintingStyle.stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) => oldDelegate.color != color;
}

/// Full luxury card with gold hairline border, soft shadow and optional corner ornaments.
class LuxuryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final bool ornaments;
  final EdgeInsetsGeometry margin;
  const LuxuryCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor = AppTheme.goldColor,
    this.ornaments = false,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withValues(alpha: 0.35), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.navy.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (ornaments)
            Positioned(
              top: 6,
              left: 6,
              child: Transform.flip(
                flipY: true,
                child: CornerOrnament(size: 24, color: AppTheme.champagne.withValues(alpha: 0.8)),
              ),
            ),
          if (ornaments)
            Positioned(
              bottom: 6,
              right: 6,
              child: CornerOrnament(size: 24, color: AppTheme.champagne.withValues(alpha: 0.8)),
            ),
          child,
        ],
      ),
    );
  }
}

/// Section header with a small gold figure + sparkles.
class LuxSectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final double fontSize;
  const LuxSectionTitle({super.key, required this.title, this.icon, this.fontSize = 17});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon!, size: fontSize + 3, color: AppTheme.goldColor),
            const SizedBox(width: 8),
          ],
          Text(title, style: AppTheme.displayStyle(size: fontSize, color: AppTheme.navy)),
          const SizedBox(width: 8),
          const SparkleFigure(size: 13),
        ],
      ),
    );
  }
}

/// Faint luxury background pattern (diagonal sheen + corner sparkles).
class LuxBackground extends StatelessWidget {
  final Widget child;
  const LuxBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, AppTheme.backgroundColor],
              ),
            ),
            child: CustomPaint(painter: _LuxPatternPainter()),
          ),
        ),
        child,
      ],
    );
  }
}

class _LuxPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = AppTheme.goldColor.withValues(alpha: 0.05);
    const spacing = 34.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.3, dot);
      }
    }
    // soft radial sheen top-right
    final sheen = Paint()
      ..shader = RadialGradient(
        colors: [AppTheme.champagne.withValues(alpha: 0.05), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.85, 0), radius: size.width * 0.5));
    canvas.drawRect(Offset.zero & size, sheen);
  }

  @override
  bool shouldRepaint(covariant _LuxPatternPainter oldDelegate) => false;
}

/// Brand emblem block for navy intro screens: gold cross + serif wordmark.
class LuxBrandHeader extends StatelessWidget {
  final String title;
  final String? tagline;
  final double crossSize;
  const LuxBrandHeader({super.key, this.title = 'MediRecord', this.tagline, this.crossSize = 34});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MedicalCrossFigure(size: crossSize),
        const SizedBox(height: 18),
        Text(
          title,
          style: AppTheme.displayStyle(
            size: 34,
            color: Colors.white,
            weight: FontWeight.w800,
          ),
        ),
        if (tagline != null) ...[
          const SizedBox(height: 8),
          Text(
            tagline!,
            style: const TextStyle(
              color: AppTheme.goldLight,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}

/// Full navy royal-gradient backdrop with gold hairline frame + ornaments.
class LuxNavyBackdrop extends StatelessWidget {
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;
  const LuxNavyBackdrop({
    super.key,
    required this.child,
    this.showBack = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.4), width: 1.4),
                  ),
                ),
              ),
            ),
            const Positioned(top: 28, right: 30, child: SparkleFigure(size: 14)),
            const Positioned(bottom: 70, left: 34, child: SparkleFigure(size: 10)),
            Positioned(
              top: 12,
              left: 12,
              child: Transform.flip(flipY: true, child: CornerOrnament(size: 30, color: AppTheme.goldLight.withValues(alpha: 0.6))),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: CornerOrnament(size: 30, color: AppTheme.goldLight.withValues(alpha: 0.6)),
            ),
            Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: child)),
            if (showBack)
              Positioned(
                top: 26,
                left: 26,
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.7), width: 1.3),
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onBack ?? () => Navigator.maybePop(context),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: AppTheme.champagneLight,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small decorative 4-point sparkle dot (lighter than full SparkleFigure).
class SparkleStar extends StatelessWidget {
  final double size;
  final Color color;
  const SparkleStar({super.key, this.size = 12, this.color = AppTheme.goldColor});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _SparkleDotPainter(color));
  }
}

class _SparkleDotPainter extends CustomPainter {
  final Color color;
  _SparkleDotPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.14
      ..strokeCap = StrokeCap.round;
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), p);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), p);
  }

  @override
  bool shouldRepaint(covariant _SparkleDotPainter oldDelegate) => oldDelegate.color != color;
}

/// Gold gradient action button (primary CTA on navy screens).
class GoldButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final bool outlined;
  const GoldButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 50,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: height,
        decoration: BoxDecoration(
          gradient: outlined ? null : AppTheme.goldGradient,
          color: outlined ? Colors.transparent : null,
          borderRadius: BorderRadius.circular(14),
          border: outlined ? Border.all(color: AppTheme.goldColor, width: 1.4) : null,
          boxShadow: outlined
              ? null
              : [BoxShadow(color: AppTheme.goldDeep.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Desktop hover polish: subtle gold glow + slight lift while the pointer is over.
class LuxHover extends StatefulWidget {
  final Widget child;
  final double scale;
  final VoidCallback? onTap;
  const LuxHover({super.key, required this.child, this.scale = 1.015, this.onTap});

  @override
  State<LuxHover> createState() => _LuxHoverState();
}

class _LuxHoverState extends State<LuxHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppTheme.goldColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : const [],
          ),
          child: GestureDetector(
            onTap: widget.onTap,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
