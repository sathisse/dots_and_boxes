import 'package:flutter/material.dart';

import 'dots_and_boxes_game.dart';
import 'box.dart';

const boxMargin = 5.0;

class DrawBoxes extends StatelessWidget {
  final Set<Box> boxes;

  const DrawBoxes(this.boxes, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final double width = constraints.maxWidth;
      final double height = constraints.maxHeight;
      final double boxWidth = width / dotsHorizontal;
      final double boxHeight = height / dotsVertical;

      return Stack(children: <Widget>[
        for (final box in boxes)
          Positioned(
            left: boxWidth * box.position.$1 + boxWidth / 2,
            top: boxHeight * box.position.$2 + boxHeight / 2,
            width: boxWidth,
            height: boxHeight,
            child: CustomPaint(
                size: Size(boxWidth, boxHeight),
                painter: BoxPainter(Size(boxWidth, boxHeight), box)),
          )
      ]);
    });
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
        ..moveTo(0 + boxMargin, 0 + boxMargin)
        ..lineTo(size.width - boxMargin, 0 + boxMargin)
        ..lineTo(size.width - boxMargin, size.height - boxMargin)
        ..lineTo(0 + boxMargin, size.height - boxMargin)
        ..lineTo(0 + boxMargin, 0 + boxMargin);

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
