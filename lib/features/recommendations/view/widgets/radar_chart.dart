import 'dart:math' as math;

import 'package:flutter/material.dart';

class RadarAxis {
  final String label;

  /// 0–1.
  final double value;
  const RadarAxis({required this.label, required this.value});
}

/// Small N-axis radar/spider chart — no charting package needed for one
/// specific shape. Used to show the traveller's category-weight
/// distribution on the Travel Pulse screen.
class RadarChart extends StatelessWidget {
  final List<RadarAxis> axes;
  final double size;
  final Color color;

  const RadarChart({super.key, required this.axes, this.size = 260, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RadarChartPainter(axes: axes, color: color),
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<RadarAxis> axes;
  final Color color;
  _RadarChartPainter({required this.axes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (axes.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 28;
    final n = axes.length;
    final angleStep = (2 * math.pi) / n;

    Offset pointFor(int i, double fraction) {
      final angle = -math.pi / 2 + angleStep * i;
      return Offset(
        center.dx + radius * fraction * math.cos(angle),
        center.dy + radius * fraction * math.sin(angle),
      );
    }

    final gridPaint = Paint()
      ..color = Colors.grey.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final ring in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = pointFor(i, ring);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, pointFor(i, 1.0), gridPaint);
    }

    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final p = pointFor(i, axes[i].value.clamp(0, 1));
      if (i == 0) {
        dataPath.moveTo(p.dx, p.dy);
      } else {
        dataPath.lineTo(p.dx, p.dy);
      }
    }
    dataPath.close();

    canvas.drawPath(dataPath, Paint()..color = color.withAlpha(60));
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );

    for (var i = 0; i < n; i++) {
      final p = pointFor(i, axes[i].value.clamp(0, 1));
      canvas.drawCircle(p, 3.5, Paint()..color = color);
    }

    for (var i = 0; i < n; i++) {
      final labelPoint = pointFor(i, 1.18);
      final percent = (axes[i].value * 100).round();
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${axes[i].label}\n($percent%)',
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 90);
      textPainter.paint(canvas, labelPoint - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) =>
      oldDelegate.axes != axes || oldDelegate.color != color;
}
