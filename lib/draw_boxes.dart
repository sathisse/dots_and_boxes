import 'dart:math';

import 'package:flutter/material.dart';

import 'dots_and_boxes_game.dart';
import 'box.dart';

class DrawBoxes extends StatelessWidget {
  final double width;
  final double height;
  final Set<Box> boxes;

  late final double boxWidth;
  late final double boxHeight;
  late final double halfDotSize;

  DrawBoxes(this.width, this.height, this.boxes, {super.key}) {
    boxWidth = width / dotsHorizontal;
    boxHeight = height / dotsVertical;
    halfDotSize = min(boxWidth, boxHeight) * halfDotSizeFactor;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: <Widget>[
      for (final box in boxes)
        Positioned(
          left: boxWidth * (box.position.$1 + 0.4) + halfDotSize,
          top: boxHeight * (box.position.$2 + 0.4) + halfDotSize,
          width: boxWidth,
          height: boxHeight,
          child: CustomPaint(
              size: Size(boxWidth, boxHeight), painter: BoxPainter(Size(boxWidth, boxHeight), box)),
        )
    ]);
  }
}

class BoxPainter extends CustomPainter {
  final Box box;

  BoxPainter(Size size, this.box);

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in box.lines.entries) {
      late (double, double) start;
      late (double, double) end;

      switch (line.value) {
        case Direction.n:
          start = (0, 0);
          end = (size.width, 0);
          break;
        case Direction.e:
          start = (size.width, 0);
          end = (size.width, size.height);
          break;
        case Direction.s:
          start = (size.width, size.height);
          end = (0, size.height);
          break;
        case Direction.w:
          start = (0, size.height);
          end = (0, 0);
          break;
      }

      Path linePath = Path()
        ..moveTo(start.$1, start.$2)
        ..lineTo(end.$1, end.$2);

      Paint borderPaint = Paint()
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..color = players[line.key.drawer]!.color;
      canvas.drawPath(linePath, borderPaint);
    }

    if (box.isClosed()) {
      final Path boxPath = Path()
        ..moveTo(0 + 5, 0 + 5)
        ..lineTo(size.width - 5, 0 + 5)
        ..lineTo(size.width - 5, size.height - 5)
        ..lineTo(0 + 5, size.height - 5)
        ..lineTo(0 + 5, 0 + 5);

      Paint fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = players[box.closer]!.color;
      canvas.drawPath(boxPath, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
