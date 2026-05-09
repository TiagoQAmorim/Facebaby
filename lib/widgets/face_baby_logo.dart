import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FaceBabyLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final String wordmark;

  const FaceBabyLogo({
    super.key,
    this.size = 40,
    this.showWordmark = true,
    this.wordmark = 'FaceBaby',
  });

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: Size.square(size),
      painter: const _FaceBabyMarkPainter(primary: AppTheme.primary, accent: AppTheme.secondary),
    );

    if (!showWordmark) return icon;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        SizedBox(width: size * 0.28),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: size * 0.70,
              height: 1.0,
              letterSpacing: -0.6,
              fontWeight: FontWeight.w900,
              color: AppTheme.text,
            ),
            children: [
              TextSpan(
                text: wordmark,
                style: const TextStyle(color: AppTheme.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FaceBabyMarkPainter extends CustomPainter {
  final Color primary;
  final Color accent;

  const _FaceBabyMarkPainter({required this.primary, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final grad = LinearGradient(
      colors: [primary, primary.withAlpha(190)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round
      ..shader = grad;

    final p1 = Path()
      ..moveTo(w * 0.16, h * 0.62)
      ..cubicTo(w * 0.30, h * 0.86, w * 0.60, h * 0.90, w * 0.86, h * 0.64);
    canvas.drawPath(p1, stroke);

    final stroke2 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.095
      ..strokeCap = StrokeCap.round
      ..shader = grad;

    final p2 = Path()
      ..moveTo(w * 0.20, h * 0.73)
      ..cubicTo(w * 0.38, h * 0.92, w * 0.62, h * 0.92, w * 0.82, h * 0.73);
    canvas.drawPath(p2, stroke2);

    final fill = Paint()
      ..shader = LinearGradient(
        colors: [accent, accent.withAlpha(210)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    final heart = Path();
    final cx = w * 0.52;
    final cy = h * 0.50;
    final s = w * 0.23;

    heart.moveTo(cx, cy + s * 0.55);
    heart.cubicTo(cx - s, cy + s * 0.10, cx - s * 0.70, cy - s * 0.70, cx, cy - s * 0.15);
    heart.cubicTo(cx + s * 0.70, cy - s * 0.70, cx + s, cy + s * 0.10, cx, cy + s * 0.55);
    canvas.drawPath(heart, fill);

    final highlight = Paint()..color = Colors.white.withAlpha(170);
    canvas.drawCircle(Offset(cx - s * 0.20, cy - s * 0.10), w * 0.045, highlight);

    final dot = Paint()..color = primary.withAlpha(110);
    canvas.drawCircle(Offset(w * 0.18, h * 0.44), w * 0.04, dot);
  }

  @override
  bool shouldRepaint(covariant _FaceBabyMarkPainter oldDelegate) {
    return oldDelegate.primary != primary || oldDelegate.accent != accent;
  }
}
