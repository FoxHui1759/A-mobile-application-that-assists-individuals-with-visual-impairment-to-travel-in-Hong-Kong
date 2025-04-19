import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<DetectedObject> detectedObjects;

  BoundingBoxPainter({required this.detectedObjects});

  @override
  void paint(Canvas canvas, Size size) {
    int id = 0;
    for (final detectedObject in detectedObjects) {
      final boundingBox = detectedObject.boundingBox;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      switch (id % 4) {
        case 0:
          paint.color = Colors.red;
          break;
        case 1:
          paint.color = Colors.green;
          break;
        case 2:
          paint.color = Colors.blue;
          break;
        default:
          paint.color = Colors.yellow;
          break;
      }

      id++;

      canvas.drawRect(
        Rect.fromLTWH(
          boundingBox.left * 0.75,
          boundingBox.top * 0.5,
          boundingBox.width * 0.75,
          boundingBox.height * 0.75,
        ),
        paint,
      );

      if (detectedObject.labels.isEmpty) {
        continue;
      }

      final label = detectedObject.labels[0];
      final textPainter = TextPainter(
        text: TextSpan(
          text:
              '${label.text} (${(label.confidence * 100).toStringAsFixed(1)}%)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.0,
            backgroundColor: paint.color,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          boundingBox.left,
          boundingBox.top - textPainter.height,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
