import { dateKey, daysBetween } from './dateUtils.js';
import { getMinNights, getPriceForDate, hasPriceForDate } from './appData.js';

export const DayStatus = {
  free: 'free',
  booked: 'booked',
  selected: 'selected',
  unavailable: 'unavailable',
  insufficientNights: 'insufficientNights',
};

export const DayPosition = {
  single: 'single',
  start: 'start',
  middle: 'middle',
  end: 'end',
};

/**
 * @typedef {object} CalendarDay
 * @property {Date} date
 * @property {string} status
 * @property {number|null} price
 * @property {number|null} discount
 * @property {string|null} currency
 * @property {string} position
 * @property {string|null} groupId
 */

/**
 * @param {CalendarDay} day
 * @param {Partial<CalendarDay>} patch
 * @returns {CalendarDay}
 */
export function copyDay(day, patch) {
  return { ...day, ...patch };
}

/**
 * @param {number[]} rooms
 * @param {Date} from
 * @param {Date} to
 * @param {Record<number, Set<string>>} bookedDates
 * @param {Record<number, Set<string>>} selectedDates
 * @returns {Record<number, CalendarDay[]>}
 */
export function generateForAllRooms(rooms, from, to, bookedDates, selectedDates) {
  /** @type {Record<number, CalendarDay[]>} */
  const result = {};
  for (const room of rooms) {
    result[room] = generateForRoom(
      from,
      to,
      bookedDates[room] ?? new Set(),
      selectedDates[room] ?? new Set(),
    );
  }
  return result;
}

/**
 * @param {Date} from
 * @param {Date} to
 * @param {Set<string>} booked
 * @param {Set<string>} selected
 * @returns {CalendarDay[]}
 */
export function generateForRoom(from, to, booked, selected) {
  /** @type {CalendarDay[]} */
  const days = [];
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const current = new Date(from);
  current.setHours(0, 0, 0, 0);
  const end = new Date(to);
  end.setHours(0, 0, 0, 0);

  while (current <= end) {
    const key = dateKey(current);
    const isPast = current < today;
    const hasPrice = hasPriceForDate(current);
    const priceInfo = getPriceForDate(current);

    let status = DayStatus.free;
    if (booked.has(key)) {
      status = DayStatus.booked;
    } else if (selected.has(key)) {
      status = DayStatus.selected;
    } else if (isPast || !hasPrice) {
      status = DayStatus.unavailable;
    }

    days.push({
      date: new Date(current),
      status,
      price: priceInfo.price > 0 ? priceInfo.price : null,
      discount: priceInfo.discount > 0 ? priceInfo.discount : null,
      currency: priceInfo.currency,
      position: DayPosition.single,
      groupId: null,
    });

    current.setDate(current.getDate() + 1);
  }

  applyGroupPositions(days, DayStatus.booked);
  applyGroupPositions(days, DayStatus.selected);
  return days;
}

/**
 * @param {CalendarDay[]} days
 * @param {string} status
 */
export function applyGroupPositions(days, status) {
  /** @type {number[][]} */
  const groupList = [];
  /** @type {number[]} */
  let currentGroup = [];

  for (let i = 0; i < days.length; i++) {
    if (days[i].status === status) {
      if (
        currentGroup.length === 0 ||
        daysBetween(days[currentGroup[currentGroup.length - 1]].date, days[i].date) === 1
      ) {
        currentGroup.push(i);
      } else {
        groupList.push([...currentGroup]);
        currentGroup = [i];
      }
    } else if (currentGroup.length > 0) {
      groupList.push([...currentGroup]);
      currentGroup = [];
    }
  }
  if (currentGroup.length > 0) groupList.push(currentGroup);

  for (const group of groupList) {
    const groupId = `${status}_${dateKey(days[group[0]].date)}`;
    for (let j = 0; j < group.length; j++) {
      const idx = group[j];
      let pos;
      if (group.length === 1) pos = DayPosition.single;
      else if (j === 0) pos = DayPosition.start;
      else if (j === group.length - 1) pos = DayPosition.end;
      else pos = DayPosition.middle;
      days[idx] = copyDay(days[idx], { position: pos, groupId });
    }
  }
}

export { getMinNights };
