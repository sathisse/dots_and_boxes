import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dot.dart';
import 'dots_and_boxes_game.dart';

class DrawDots extends StatelessWidget {
  final double width;
  final double height;
  final Set<Dot> dots;

  late final double boxWidth;
  late final double boxHeight;
  late final double dotSize;

  DrawDots(this.width, this.height, this.dots, {super.key}) {
    boxWidth = width / dotsHorizontal;
    boxHeight = height / dotsVertical;
    dotSize = min(boxWidth, boxHeight) * dotSizeFactor;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: <Widget>[
      for (final dot in dots)
        Positioned(
            left: boxWidth * (dot.position.$1 + 0.4),
            top: boxHeight * (dot.position.$2 + 0.4),
            height: dotSize,
            width: dotSize,
            child: SvgPicture.asset('assets/dot.svg',
                colorFilter: const ColorFilter.mode(Colors.black, BlendMode.dst))),
    ]);
  }
}
