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

const smallestAllowedNumberOfDots = 6;
const largestAllowedNumberOfDots = 100;
const smallestMinorDimension = 2;
const largestAllowedRatio = 3;

Map<int, (int, int)> getDimensionChoices() {
  Map<int, (int, int)> dims = {};

  for (int number = smallestAllowedNumberOfDots; number <= largestAllowedNumberOfDots; number++) {
    dims[number] = getFactors(number);
  }

  return Map<int, (int, int)>.fromEntries(dims.entries.where((dim) =>
      dim.value.$2 >= smallestMinorDimension &&
      dim.value.$1 / dim.value.$2 <= largestAllowedRatio));
}
