import 'package:flutter/material.dart';

const double baseWidth = 480;
const double aspectRatio = 85.6 / 53.98;
const double baseHeight = baseWidth * aspectRatio;

const monthTextStyle = TextStyle(
  fontSize: baseWidth / 100 * 2.5,
  fontWeight: FontWeight.bold,
);
const weekdayTextStyle = TextStyle(
  fontSize: baseWidth / 100 * 2,
  fontWeight: FontWeight.bold,
);
const dayTextStyle = TextStyle(
  fontSize: baseWidth / 100 * 1.8,
  color: Colors.black,
);
const buttonTextStyle = TextStyle(
  fontSize: baseWidth / 100 * 3,
  color: Colors.white,
);
const versionTextStyle = TextStyle(
  fontSize: baseWidth / 100 * 2,
  color: Color(0xFF9E9E9E),
); 