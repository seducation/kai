import 'dart:math';
import 'package:flutter/material.dart';

/// Renders a rotating 3D wireframe object
class ExperientialRenderer extends CustomPainter {
  final double animationValue;
  final Color color;

  ExperientialRenderer({
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width * 0.3;

    final paint = Paint()
      ..color = color.withAlpha(100)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Define vertices for a simple 3D shape (Icosahedron-ish)
    // We project 3D points (x,y,z) to 2D (x,y)
    final points = <_Point3D>[];
    for (var i = 0; i < 8; i++) {
      final theta = (i / 8) * pi * 2 + animationValue * 2 * pi;
      final phi = (i / 8) * pi + animationValue * pi;

      points.add(_Point3D(
        x: radius * cos(theta) * sin(phi),
        y: radius * sin(theta) * sin(phi),
        z: radius * cos(phi),
      ));
    }

    // Connect vertices
    for (var i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length]; // Connect ring
      final p3 = points[(i + 3) % points.length]; // Cross connections

      _drawLine(canvas, centerX, centerY, p1, p2, paint);
      _drawLine(canvas, centerX, centerY, p1, p3, paint);
    }

    // Draw outer ring
    canvas.drawCircle(
        Offset(centerX, centerY), radius * 1.2, paint..strokeWidth = 0.5);
  }

  void _drawLine(Canvas canvas, double cx, double cy, _Point3D p1, _Point3D p2,
      Paint paint) {
    // Simple perspective projection: x' = x / (z + camera_dist)
    const cameraDist = 400.0;

    final scale1 = cameraDist / (cameraDist - p1.z);
    final scale2 = cameraDist / (cameraDist - p2.z);

    final x1 = cx + p1.x * scale1;
    final y1 = cy + p1.y * scale1;
    final x2 = cx + p2.x * scale2;
    final y2 = cy + p2.y * scale2;

    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
  }

  @override
  bool shouldRepaint(covariant ExperientialRenderer oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color;
  }
}

class _Point3D {
  final double x, y, z;
  _Point3D({required this.x, required this.y, required this.z});
}
