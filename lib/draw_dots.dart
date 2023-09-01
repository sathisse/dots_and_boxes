import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'dot.dart';
import 'dots_and_boxes_game.dart';

const paddingFactor = 0.25;

class DrawDots extends StatelessWidget {
  final double width;
  final double height;
  final Set<Dot> dots;
  final Function onLineRequested;

  late final double boxWidth;
  late final double boxHeight;
  late final double dotSize;
  late final double pencilSize;

  DrawDots(this.width, this.height, this.dots, {required this.onLineRequested, super.key}) {
    boxWidth = width / dotsHorizontal;
    boxHeight = height / dotsVertical;
    dotSize = min(boxWidth, boxHeight);
    pencilSize = dotSize / 3;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: <Widget>[
      for (final dot in dots)
        Positioned(
            left: boxWidth * (dot.position.$1),
            top: boxHeight * (dot.position.$2),
            width: boxWidth,
            height: boxHeight,
            child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: boxWidth * paddingFactor, vertical: boxHeight * paddingFactor),
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
                        dragAnchorStrategy: pointerDragAnchorStrategy,
                        feedback: SvgPicture.asset('assets/pencil.svg',
                            width: pencilSize,
                            height: pencilSize,
                            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.dst)),
                        childWhenDragging: SvgPicture.asset('assets/dot.svg',
                            width: dotSize,
                            height: dotSize,
                            colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn)),
                        child: SvgPicture.asset('assets/dot.svg',
                            width: dotSize,
                            height: dotSize,
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
                )))
    ]);
  }
}
