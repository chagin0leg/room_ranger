/** @typedef {'nominative'|'genitive'|'dative'|'accusative'|'instrumental'|'prepositional'} GrammaticalCase */

const CASE_INDEX = {
  nominative: 1,
  genitive: 2,
  dative: 3,
  accusative: 4,
  instrumental: 5,
  prepositional: 6,
};

const MONTHS = [
  ['январ', 'ь', 'я', 'ю', 'ь', 'ем', 'е'],
  ['феврал', 'ь', 'я', 'ю', 'ь', 'ем', 'е'],
  ['март', '', 'а', 'у', '', 'ом', 'е'],
  ['апрел', 'ь', 'я', 'ю', 'ь', 'ем', 'е'],
  ['ма', 'й', 'я', 'ю', 'й', 'ем', 'е'],
  ['июн', 'ь', 'я', 'ю', 'ь', 'ем', 'е'],
  ['июл', 'ь', 'я', 'ю', 'ь', 'ем', 'е'],
  ['август', '', 'а', 'у', '', 'ом', 'е'],
  ['сентябр', 'ь', 'я', 'ю', 'ь', 'ем', 'е'],
  ['октябр', 'ь', 'я', 'ю', 'ь', 'ем', 'е'],
  ['ноябр', 'ь', 'я', 'ю', 'ь', 'ем', 'е'],
  ['декабр', 'ь', 'я', 'ю', 'ь', 'ем', 'е'],
];

/**
 * @param {number} month 1-12
 * @param {GrammaticalCase} grammaticalCase
 */
export function getMonthName(month, grammaticalCase) {
  if (month < 1 || month > 12) {
    throw new Error('Month must be between 1 and 12');
  }
  const idx = CASE_INDEX[grammaticalCase];
  const data = MONTHS[month - 1];
  return data[0] + data[idx];
}

/** @param {number} count */
export function getNightWord(count) {
  if (count % 10 === 1 && count % 100 !== 11) return 'ночь';
  if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
    return 'ночи';
  }
  return 'ночей';
}

/** @param {Date} date */
export function dateKey(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/** @param {string} key */
export function parseDateKey(key) {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, m - 1, d);
}

/** @param {number} year @param {number} month @param {number} day */
export function makeDate(year, month, day) {
  return new Date(year, month - 1, day);
}

/** @param {Date} a @param {Date} b */
export function daysBetween(a, b) {
  const ms = b.getTime() - a.getTime();
  return Math.round(ms / (24 * 60 * 60 * 1000));
}

/** @param {Date} a @param {Date} b */
export function isSameDay(a, b) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}
