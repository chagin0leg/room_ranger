/// Russian grammatical cases
enum GrammaticalCase {
  nominative(1), // Nominative case (who? what?)
  genitive(2), // Genitive case (whose? what?)
  dative(3), // Dative case (to whom? to what?)
  accusative(4), // Accusative case (whom? what?)
  instrumental(5), // Instrumental case (by whom? by what?)
  prepositional(6); // Prepositional case (about whom? about what?)

  final int value;
  const GrammaticalCase(this.value);
}

/// Returns the month name in the specified grammatical case.
/// - `month` - month number (1-12).
/// - `grammaticalCase` - Russian grammatical case.
///
/// Examples:
/// ```dart
/// getMonthName(1, GrammaticalCase.nominative) // "январь"
/// getMonthName(1, GrammaticalCase.genitive) // "января"
/// getMonthName(1, GrammaticalCase.dative) // "январю"
/// ```
String getMonthName(int month, GrammaticalCase grammaticalCase) {
  if (month < 1 || month > 12) {
    throw ArgumentError('Month must be between 1 and 12');
  }

  const List<List<String>> rootsWithEndings = [
    /*root,nominative,genitive,dative,accusative,instrumental,prepositional*/
    ['январ', /****/ 'ь', /**/ 'я', /**/ 'ю', /**/ 'ь', /**/ 'ем', /**/ 'е'],
    ['феврал', /***/ 'ь', /**/ 'я', /**/ 'ю', /**/ 'ь', /**/ 'ем', /**/ 'е'],
    ['март', /*****/ '', /***/ 'а', /**/ 'у', /**/ '', /***/ 'ом', /**/ 'е'],
    ['апрел', /****/ 'ь', /**/ 'я', /**/ 'ю', /**/ 'ь', /**/ 'ем', /**/ 'е'],
    ['ма', /*******/ 'й', /**/ 'я', /**/ 'ю', /**/ 'й', /**/ 'ем', /**/ 'е'],
    ['июн', /******/ 'ь', /**/ 'я', /**/ 'ю', /**/ 'ь', /**/ 'ем', /**/ 'е'],
    ['июл', /******/ 'ь', /**/ 'я', /**/ 'ю', /**/ 'ь', /**/ 'ем', /**/ 'е'],
    ['август', /***/ '', /***/ 'а', /**/ 'у', /**/ '', /***/ 'ом', /**/ 'е'],
    ['сентябр', /**/ 'ь', /**/ 'я', /**/ 'ю', /**/ 'ь', /**/ 'ем', /**/ 'е'],
    ['октябр', /***/ 'ь', /**/ 'я', /**/ 'ю', /**/ 'ь', /**/ 'ем', /**/ 'е'],
    ['ноябр', /****/ 'ь', /**/ 'я', /**/ 'ю', /**/ 'ь', /**/ 'ем', /**/ 'е'],
    ['декабр', /***/ 'ь', /**/ 'я', /**/ 'ю', /**/ 'ь', /**/ 'ем', /**/ 'е'],
  ];

  final List<String> monthData = rootsWithEndings[month - 1];
  return monthData[0] /*root*/ + monthData[grammaticalCase.value] /*ending*/;
}

/// Returns the correct form of the word "ночь" depending on the number
String getNightWord(int count) => (count % 10 == 1 && count % 100 != 11)
    ? 'ночь'
    : (count % 10 >= 2 && count % 10 <= 4) &&
            (count % 100 < 10 || count % 100 >= 20)
        ? 'ночи'
        : 'ночей';
