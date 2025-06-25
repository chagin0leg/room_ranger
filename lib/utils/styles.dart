import 'package:flutter/material.dart';

const double baseWidth = 480;
const double aspectRatio = 16 / 9;
// const double aspectRatio = 85.6 / 53.98;
const double baseHeight = baseWidth * aspectRatio;

const Color colorBooked = Color(0xFFed8f75);
const Color colorSelected = Color(0xFFd2dfb3);
const Color colorTransparent = Color(0x00000000);
const Color colorTableCell = Color(0xFFfbf4e2);
const Color colorBookingBg = Color(0xFFebeed3);
const Color colorButtonBg = Color(0xFFd2dfb3);
const Color colorButtonFg = Color(0xFF4a4b4d);

const monthTextStyle = TextStyle(
  fontSize: baseWidth / 100 * 3,
  fontWeight: FontWeight.bold,
  color: colorButtonFg,
  letterSpacing: 1.2,
);
const weekdayTextStyle = TextStyle(
  fontSize: baseWidth / 100 * 2.25,
  fontWeight: FontWeight.bold,
  color: colorButtonFg,
);
const dayTextStyle = TextStyle(
  fontSize: baseWidth / 100 * 2,
  color: colorButtonFg,
);
const buttonTextStyle = TextStyle(
  fontSize: baseWidth / 100 * 3,
  fontWeight: FontWeight.bold,
  color: colorButtonFg,
);
const versionTextStyle = TextStyle(
  fontSize: baseWidth / 100 * 2,
  fontWeight: FontWeight.w100,
  color: colorButtonFg,
); 