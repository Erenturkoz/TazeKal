import 'package:flutter/material.dart';

/// Small vector still life, painted locally; no network images or font icons.
class PantryArt extends StatelessWidget {
  const PantryArt({super.key, required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 126,
      height: 130,
      child: CustomPaint(painter: _PantryPainter(accent)),
    ),
  );
}

class _PantryPainter extends CustomPainter {
  _PantryPainter(this.accent);
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 140, size.height / 145);
    final paint = Paint();
    canvas.drawCircle(
      const Offset(73, 73),
      62,
      paint..color = Colors.white.withValues(alpha: .08),
    );
    canvas.drawOval(
      const Rect.fromLTWH(11, 123, 124, 12),
      paint..color = Colors.black.withValues(alpha: .12),
    );
    // Milk bottle.
    final bottle = Path()
      ..moveTo(24, 50)
      ..lineTo(24, 38)
      ..quadraticBezierTo(24, 34, 29, 34)
      ..lineTo(43, 34)
      ..quadraticBezierTo(48, 34, 48, 38)
      ..lineTo(48, 50)
      ..lineTo(57, 65)
      ..lineTo(57, 122)
      ..quadraticBezierTo(57, 128, 51, 128)
      ..lineTo(21, 128)
      ..quadraticBezierTo(15, 128, 15, 122)
      ..lineTo(15, 65)
      ..close();
    canvas.drawPath(bottle, paint..color = const Color(0xfff5f0db));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(23, 28, 26, 9),
        const Radius.circular(3),
      ),
      paint..color = const Color(0xffe2b86d),
    );
    canvas.drawRect(
      const Rect.fromLTWH(15, 78, 42, 31),
      paint..color = const Color(0xffb9cfa8),
    );
    // Preserving jar.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(68, 70, 53, 58),
        const Radius.circular(10),
      ),
      paint..color = const Color(0xffdfa556),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(66, 62, 57, 12),
        const Radius.circular(4),
      ),
      paint..color = const Color(0xfff2d5a3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(77, 88, 35, 24),
        const Radius.circular(5),
      ),
      paint..color = const Color(0xfffaf2db),
    );
    // Fresh leaves.
    canvas.drawPath(
      Path()
        ..moveTo(95, 61)
        ..quadraticBezierTo(65, 55, 75, 20)
        ..quadraticBezierTo(105, 28, 95, 61),
      paint..color = const Color(0xffa9c782),
    );
    canvas.drawPath(
      Path()
        ..moveTo(96, 58)
        ..quadraticBezierTo(94, 26, 127, 26)
        ..quadraticBezierTo(130, 57, 96, 58),
      paint..color = const Color(0xffc7db94),
    );
    paint
      ..color = accent
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(95, 66)
        ..quadraticBezierTo(94, 43, 80, 30)
        ..moveTo(96, 59)
        ..lineTo(119, 35),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PantryPainter oldDelegate) =>
      oldDelegate.accent != accent;
}
