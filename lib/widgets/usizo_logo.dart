import 'package:flutter/material.dart';

/// A simple vector logo for UsizoAI — a stylised health cross with a leaf.
///
/// Uses CustomPainter so it renders at any resolution without raster assets.
class UsizoLogo extends StatelessWidget {
  const UsizoLogo({this.size = 120, this.showText = true, super.key});

  /// Diameter of the logo mark in logical pixels.
  final double size;

  /// Whether to show the "UsizoAI" text below the mark.
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: const _LogoPainter(),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.1),
          Text(
            'UsizoAI',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xff087f70),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your health companion',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}

/// Paints the UsizoAI logo mark: a rounded cross with a small leaf accent.
class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ── Background circle ──────────────────────────────────────────
    final bgPaint = Paint()
      ..color = const Color(0xff087f70)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // ── White cross ────────────────────────────────────────────────
    final crossPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final armWidth = size.width * 0.18;
    final armLength = size.width * 0.52;

    // Vertical arm
    final verticalRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: armWidth,
        height: armLength,
      ),
      Radius.circular(armWidth * 0.3),
    );
    canvas.drawRRect(verticalRect, crossPaint);

    // Horizontal arm
    final horizontalRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: armLength,
        height: armWidth,
      ),
      Radius.circular(armWidth * 0.3),
    );
    canvas.drawRRect(horizontalRect, crossPaint);

    // ── Small leaf in top-right quadrant ───────────────────────────
    final leafPaint = Paint()
      ..color = const Color(0xffa8e6cf) // light green accent
      ..style = PaintingStyle.fill;

    final leafCenter = Offset(
      center.dx + radius * 0.35,
      center.dy - radius * 0.35,
    );
    final leafSize = size.width * 0.18;

    final leafPath = Path()
      ..moveTo(leafCenter.dx, leafCenter.dy - leafSize * 0.5)
      ..quadraticBezierTo(
        leafCenter.dx + leafSize * 0.5,
        leafCenter.dy - leafSize * 0.2,
        leafCenter.dx + leafSize * 0.15,
        leafCenter.dy + leafSize * 0.5,
      )
      ..quadraticBezierTo(
        leafCenter.dx - leafSize * 0.2,
        leafCenter.dy + leafSize * 0.15,
        leafCenter.dx,
        leafCenter.dy - leafSize * 0.5,
      );
    canvas.drawPath(leafPath, leafPaint);

    // Leaf vein (thin line)
    final veinPaint = Paint()
      ..color = const Color(0xff087f70)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      leafCenter,
      Offset(leafCenter.dx + leafSize * 0.1, leafCenter.dy + leafSize * 0.35),
      veinPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
