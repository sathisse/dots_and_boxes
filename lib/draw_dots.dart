import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'dot.dart';
import 'dots_and_boxes_game.dart';

class DrawDots extends StatelessWidget {
  final double width;
  final double height;
  final Set<Dot> dots;
  final Function onLineRequested;

  late final double boxWidth;
  late final double boxHeight;
  late final double dotSize;

  DrawDots(this.width, this.height, this.dots, {required this.onLineRequested, super.key}) {
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
            width: dotSize,
            height: dotSize,
            child: DragTarget<Dot>(
              builder: (
                BuildContext context,
                List<dynamic> accepted,
                List<dynamic> rejected,
              ) {
                return Draggable<Dot>(
                    data: dot,
                    onDragStarted: () {},
                    onDragEnd: (details) {},
                    feedback: SvgPicture.asset('assets/pencil.svg',
                        width: dotSize * 2,
                        height: dotSize * 2,
                        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.dst)),
                    child: SvgPicture.asset('assets/dot.svg',
                        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.dst)));
              },
              onWillAccept: (data) {
                // debugPrint("in onWillAccept with dst $dot and src $data");
                return dot.position != data?.position;
              },
              onAccept: (data) {
                // debugPrint("in onAccept with dst $dot and src $data");
                onLineRequested(data, dot);
              },
            ))
    ]);
  }
}
