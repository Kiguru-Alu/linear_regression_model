import 'package:flutter/material.dart';

import '../theme.dart';

// Soft rolling hills behind the result card, fading into the page
class FieldHorizon extends StatelessWidget {
  const FieldHorizon({super.key, this.height = 150});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _HillsPainter()),
    );
  }
}

class _HillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void hill(double top, List<double> crests, Color near, Color far) {
      final path = Path()..moveTo(0, h);
      path.lineTo(0, top + crests.first * h);
      final step = w / (crests.length - 1);
      for (var i = 1; i < crests.length; i++) {
        final x0 = step * (i - 1);
        final x1 = step * i;
        path.cubicTo(
          x0 + step / 2,
          top + crests[i - 1] * h,
          x1 - step / 2,
          top + crests[i] * h,
          x1,
          top + crests[i] * h,
        );
      }
      path
        ..lineTo(w, h)
        ..close();
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [far, near, Palette.canvas],
          stops: const [0, 0.55, 1],
        ).createShader(Offset.zero & size);
      canvas.drawPath(path, paint);
    }

    hill(h * 0.08, [0.30, 0.12, 0.26, 0.06, 0.22], const Color(0xFFC9DDC3), const Color(0xFFDCE9D6));
    hill(h * 0.30, [0.20, 0.34, 0.14, 0.30, 0.18], const Color(0xFF9CC79A), const Color(0xFFB9D8B3));
    hill(h * 0.52, [0.16, 0.04, 0.20, 0.10, 0.24], const Color(0xFF7DB47F), const Color(0xFF94C493));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
