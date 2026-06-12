import { getMonthName, getNightWord } from './dateUtils.js';
import { getTelegramManagerId } from './appData.js';
import { DayStatus } from './calendarDayService.js';
import { getFullPriceInfo } from './priceUtils.js';

/** @param {Date} date */
function formatDate(date) {
  const currentYear = new Date().getFullYear();
  const monthName = getMonthName(date.getMonth() + 1, 'genitive');
  if (date.getFullYear() !== currentYear) {
    return `${date.getDate()} ${monthName} ${date.getFullYear()}`;
  }
  return `${date.getDate()} ${monthName}`;
}

/** @param {Date[]} sortedDays */
function groupDaysToIntervals(sortedDays) {
  if (sortedDays.length === 0) return [];
  /** @type {Date[][]} */
  const intervals = [];
  let currentInterval = [sortedDays[0]];
  for (let i = 1; i < sortedDays.length; i++) {
    const prev = sortedDays[i - 1];
    const curr = sortedDays[i];
    const diff = (curr - prev) / (24 * 60 * 60 * 1000);
    if (diff === 1) {
      currentInterval.push(curr);
    } else {
      intervals.push([...currentInterval]);
      currentInterval = [curr];
    }
  }
  intervals.push(currentInterval);
  return intervals;
}

/** @param {number} day */
function getPrepositionForFrom(day) {
  return day === 2 ? 'со' : 'с';
}

/**
 * @param {Date[]} interval
 * @param {number} currentYear
 * @param {boolean} hasMultipleYears
 */
function formatInterval(interval, currentYear, hasMultipleYears) {
  if (interval.length === 1) {
    return formatDate(interval[0]);
  }
  const start = interval[0];
  const end = interval[interval.length - 1];
  const nights = interval.length - 1;
  const preposition = getPrepositionForFrom(start.getDate());
  let baseText;

  if (start.getFullYear() === end.getFullYear()) {
    if (start.getMonth() === end.getMonth()) {
      if (start.getFullYear() !== currentYear) {
        baseText = `в ${start.getFullYear()} году ${preposition} ${start.getDate()} по ${end.getDate()} ${getMonthName(end.getMonth() + 1, 'genitive')}`;
      } else {
        baseText = hasMultipleYears
          ? `в этом году ${preposition} ${start.getDate()} по ${end.getDate()} ${getMonthName(end.getMonth() + 1, 'genitive')}`
          : `${preposition} ${start.getDate()} по ${end.getDate()} ${getMonthName(end.getMonth() + 1, 'genitive')}`;
      }
    } else if (start.getFullYear() !== currentYear) {
      baseText = `в ${start.getFullYear()} году ${preposition} ${start.getDate()} ${getMonthName(start.getMonth() + 1, 'genitive')} по ${end.getDate()} ${getMonthName(end.getMonth() + 1, 'genitive')}`;
    } else {
      baseText = hasMultipleYears
        ? `в этом году ${preposition} ${start.getDate()} ${getMonthName(start.getMonth() + 1, 'genitive')} по ${end.getDate()} ${getMonthName(end.getMonth() + 1, 'genitive')}`
        : `${preposition} ${start.getDate()} ${getMonthName(start.getMonth() + 1, 'genitive')} по ${end.getDate()} ${getMonthName(end.getMonth() + 1, 'genitive')}`;
    }
  } else {
    baseText = `${preposition} ${formatDate(start)} по ${formatDate(end)}`;
  }
  return `${baseText} (${nights} ${getNightWord(nights)})`;
}

function getGreeting() {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 12) return 'Доброе утро!';
  if (hour >= 12 && hour < 17) return 'Добрый день!';
  if (hour >= 17 && hour < 23) return 'Добрый вечер!';
  return 'Доброй ночи!';
}

/**
 * @param {Record<number, import('./calendarDayService.js').CalendarDay[]>} daysByRoom
 */
export function buildTelegramBookingMessage(daysByRoom) {
  const roomsWithDates = Object.values(daysByRoom).filter((days) =>
    days.some((d) => d.status === DayStatus.selected),
  ).length;

  const bookingPhrase =
    roomsWithDates === 0
      ? 'У меня есть несколько вопросов по бронированию:\n1. '
      : `Хотелось бы забронировать номер${roomsWithDates === 1 ? '' : 'а'} на следующие даты:\n`;

  let message = `${getGreeting()}\n${bookingPhrase}`;

  const hasAnyDates = Object.values(daysByRoom).some((days) =>
    days.some((d) => d.status === DayStatus.selected),
  );
  if (!hasAnyDates) {
    return message;
  }

  const roomEntries = [];
  for (const [roomKey, roomDays] of Object.entries(daysByRoom)) {
    const selectedDays = roomDays.filter((d) => d.status === DayStatus.selected);
    if (selectedDays.length === 0) continue;

    const sortedDays = selectedDays.map((d) => d.date).sort((a, b) => a - b);
    const intervals = groupDaysToIntervals(sortedDays);
    const years = new Set(intervals.map((i) => i[0].getFullYear()));
    const currentYear = new Date().getFullYear();
    const hasMultipleYears = years.size > 1;
    const formattedIntervals = intervals.map((interval) =>
      formatInterval(interval, currentYear, hasMultipleYears),
    );
    roomEntries.push(
      `Номер ${roomKey}:\n${formattedIntervals.map((i) => `- ${i}`).join('\n')}`,
    );
  }

  message += `\n${roomEntries.join('\n')}`;

  const allSelectedDays = [];
  for (const days of Object.values(daysByRoom)) {
    allSelectedDays.push(...days.filter((d) => d.status === DayStatus.selected));
  }
  if (allSelectedDays.length > 0) {
    message += `\n\n${getFullPriceInfo(allSelectedDays, daysByRoom)}`;
  }
  message += '\n\n__Заявка отправлена через Room Ranger.__';
  return message;
}

/** @param {string} message */
export function sendTelegramBookingMessage(message) {
  const managerId = getTelegramManagerId();
  const url = `https://t.me/${managerId}?text=${encodeURIComponent(message)}`;
  window.open(url, '_blank');
}

/**
 * @param {Record<number, import('./calendarDayService.js').CalendarDay[]>} daysByRoom
 */
export function formatAllBookingDatesText(daysByRoom) {
  const hasAnyDates = Object.values(daysByRoom).some((days) =>
    days.some((d) => d.status === DayStatus.selected),
  );
  if (!hasAnyDates) return '';

  const roomEntries = [];
  for (const [roomKey, roomDays] of Object.entries(daysByRoom)) {
    const selectedDays = roomDays.filter((d) => d.status === DayStatus.selected);
    if (selectedDays.length === 0) continue;

    const sortedDays = selectedDays.map((d) => d.date).sort((a, b) => a - b);
    const intervals = groupDaysToIntervals(sortedDays);
    const years = new Set(intervals.map((i) => i[0].getFullYear()));
    const currentYear = new Date().getFullYear();
    const hasMultipleYears = years.size > 1;
    const formattedIntervals = intervals.map((interval) =>
      formatInterval(interval, currentYear, hasMultipleYears),
    );
    roomEntries.push(
      `Номер ${roomKey}:\n${formattedIntervals.map((i) => `- ${i}`).join('\n')}`,
    );
  }
  return roomEntries.join('\n\n');
}
