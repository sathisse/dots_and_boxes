import 'package:dots_and_boxes/utils.dart';
import 'package:flutter/material.dart';

// import 'dots_and_boxes_game.dart';

class GameSizeSlider extends StatefulWidget {
  final void Function(int) setNumberOfDots;
  final bool isEnabled;

  const GameSizeSlider({required this.setNumberOfDots, required this.isEnabled, super.key});

  @override
  State<GameSizeSlider> createState() => _GameSizeSliderState();
}

class _GameSizeSliderState extends State<GameSizeSlider> {
  final dimChoices = getDimensionChoices();
  late double sliderValue;
  int numberOfDots = 12;

  @override
  void initState() {
    super.initState();
    // debugPrint('Dimension choices are: $dimChoices');
    sliderValue = 4;
  }

  @override
  Widget build(BuildContext context) {
    return Slider(
        value: sliderValue,
        max: dimChoices.length.toDouble() - 1,
        divisions: dimChoices.length - 2,
        label: "${dimChoices.keys.toList()[sliderValue.floor()]} dots",
        onChanged: widget.isEnabled ? onSliderChanged : null);
  }

  onSliderChanged(double value) {
    debugPrint("Slider tab set to ${value.round()}");

    sliderValue = value;
    var dims = dimChoices.entries
        .where((dim) => dim.value.$1 * dim.value.$2 >= dimChoices.keys.toList()[value.floor()])
        .first;
    debugPrint("dims=$dims");
    if (dims.key != numberOfDots) {
      widget.setNumberOfDots(dims.key);
    }

    setState(() {});
  }
}
