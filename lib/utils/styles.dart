import 'package:flutter/material.dart';

// Функция для получения базовой ширины в зависимости от размера экрана
double getBaseWidth(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final maxWidthByHeight = screenHeight / aspectRatio;
  return [screenWidth, maxBaseWidth, maxWidthByHeight].reduce((a, b) => a < b ? a : b);
}

// Константы для максимальной ширины и соотношения сторон
const double maxBaseWidth = 640;
const double aspectRatio = 16 / 9;
// const double aspectRatio = 85.6 / 53.98;

// Функция для получения базовой высоты
double getBaseHeight(BuildContext context) {
  return getBaseWidth(context) * aspectRatio;
}

const Color colorBooked = Color(0xFFed8f75);
const Color colorSelected = Color(0xFFd2dfb3);
const Color colorTransparent = Color(0x00000000);
const Color colorTableCell = Color(0xFFfbf4e2);
const Color colorBookingBg = Color(0xFFebeed3);
const Color colorButtonBg = Color(0xFFd2dfb3);
const Color colorButtonFg = Color(0xFF4a4b4d);

// Функции для стилей текста
TextStyle getMonthTextStyle(BuildContext context) => TextStyle(
  fontSize: getBaseWidth(context) / 100 * 3,
  fontWeight: FontWeight.bold,
  color: colorButtonFg,
  letterSpacing: 1.2,
);

TextStyle getWeekdayTextStyle(BuildContext context) => TextStyle(
  fontSize: getBaseWidth(context) / 100 * 2.25,
  fontWeight: FontWeight.bold,
  color: colorButtonFg,
);

TextStyle getDayTextStyle(BuildContext context) => TextStyle(
  fontSize: getBaseWidth(context) / 100 * 2,
  color: colorButtonFg,
);

TextStyle getButtonTextStyle(BuildContext context) => TextStyle(
  fontSize: getBaseWidth(context) / 100 * 3,
  fontWeight: FontWeight.bold,
  color: colorButtonFg,
);

TextStyle getVersionTextStyle(BuildContext context) => TextStyle(
  fontSize: getBaseWidth(context) / 100 * 2,
  fontWeight: FontWeight.w100,
  color: colorButtonFg,
);

TextStyle getPriceTextStyle(BuildContext context) => TextStyle(
  fontSize: getBaseWidth(context) / 100 * 2.5,
  fontWeight: FontWeight.w500,
  color: colorButtonFg,
);

TextStyle getPriceTotalTextStyle(BuildContext context) => TextStyle(
  fontSize: getBaseWidth(context) / 100 * 2.8,
  fontWeight: FontWeight.bold,
  color: colorButtonFg,
);

// ========== RELATIVE SIZES ============= //

// Функции для размеров ячеек календаря и других элементов
double getCalendarCellDimension(BuildContext context) => getBaseWidth(context) / 30; // ~16 при 480px
double getCalendarCellMargin(BuildContext context) => getBaseWidth(context) / 120; // ~4 при 480px
double getCalendarCellBorderRadius(BuildContext context) => getBaseWidth(context) / 24; // ~20 при 480px
double getCalendarCellSpacing(BuildContext context) => getBaseWidth(context) / 120; // ~4 при 480px
double getCalendarRowSpacing(BuildContext context) => getBaseWidth(context) / 60; // ~8 при 480px
double getBookingContainerPadding(BuildContext context) => getBaseWidth(context) / 48; // ~10 при 480px
double getVersionPadding(BuildContext context) => getBaseWidth(context) / 40; // ~12 при 480px
double getRoomButtonSize(BuildContext context) => getBaseWidth(context) / 6.15; // ~78 при 480px
double getBookingContainerBorderRadius(BuildContext context) => getBaseWidth(context) / 24; // ~20 при 480px
double getBookingButtonFontSize(BuildContext context) => getBaseWidth(context) / 40; // ~12 при 480px

// ========== END RELATIVE SIZES ========== // 