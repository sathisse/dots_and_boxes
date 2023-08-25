// ignore_for_file: avoid_print

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

Logger log = Logger(
  // printer: PrettyPrinter(),
  printer: PrettyPrinter(methodCount: 0),
);

void showSnackBarGlobal(BuildContext context, String message) {
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(days: 1),
      content: Text(
        message,
        textScaleFactor: 2,
      )));
}

(int, int) getFactors(int number) {
  List<int> factorSet = [];

  for (var candidate = 1; candidate <= min(number ~/ 2, 12); candidate++) {
    if (number % candidate == 0) {
      factorSet.add(candidate);
      factorSet.add((number ~/ candidate));
    }
  }

  var factors = factorSet..sort();
  var middleFactor = factors.toList()[(factors.length ~/ 2)];
  return (middleFactor, number ~/ middleFactor);
}

Map<int, (int, int)> getDimensionChoices(number) {
  Map<int, (int, int)> dims = {};

  for (int number = 4; number <= 84; number++) {
    dims[number] = getFactors(number);
  }

  // TODO: Optimize this by returning early:
  return Map<int, (int, int)>.fromEntries(
      dims.entries.where((dim) => dim.value.$2 > 2 && dim.value.$1 / dim.value.$2 < 4));
}

// (int, int) getDimensions(number) {
//   List<(int, int)> dims = [];
//
//   for (int number = 4; number <= 84; number++) {
//     dims.add(getFactors(number));
//   }
//
//   return dims
//       .where((dim) => dim.$2 > 2 && dim.$1 / dim.$2 < 4)
//       .where((dim) => dim.$1 * dim.$2 >= number)
//       .first;
// }
