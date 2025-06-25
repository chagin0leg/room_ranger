import 'package:flutter/material.dart';

const double baseWidth = 320;
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

// ========== RELATIVE SIZES ============= //

// Размеры для ячеек календаря и других элементов
const double calendarCellDimension = baseWidth / 30; // ~16 при 480px
const double calendarCellMargin = baseWidth / 120; // ~4 при 480px
const double calendarCellBorderRadius = baseWidth / 24; // ~20 при 480px
const double calendarCellSpacing = baseWidth / 120; // ~4 при 480px
const double calendarRowSpacing = baseWidth / 60; // ~8 при 480px
const double bookingContainerPadding = baseWidth / 48; // ~10 при 480px
const double versionPadding = baseWidth / 40; // ~12 при 480px
const double roomButtonSize = baseWidth / 6.15; // ~78 при 480px
const double bookingContainerBorderRadius = baseWidth / 24; // ~20 при 480px
const double bookingButtonFontSize = baseWidth / 40; // ~12 при 480px

// ========== END RELATIVE SIZES ========== // 