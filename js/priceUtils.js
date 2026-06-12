import { getMonthName, getNightWord } from './dateUtils.js';
import {
  getBasePriceForDate,
  getDiscountPercentForDate,
  getCurrencyForDate,
  getDefaultCurrency,
} from './appData.js';
import { DayStatus } from './calendarDayService.js';

/**
 * @param {import('./calendarDayService.js').CalendarDay[]} days
 */
function groupIntoIntervals(days) {
  if (days.length === 0) return [];
  const sorted = [...days].sort((a, b) => a.date - b.date);
  /** @type {import('./calendarDayService.js').CalendarDay[][]} */
  const intervals = [];
  let current = [sorted[0]];
  for (let i = 1; i < sorted.length; i++) {
    const prev = sorted[i - 1];
    const curr = sorted[i];
    const diff = (curr.date - prev.date) / (24 * 60 * 60 * 1000);
    if (diff === 1) {
      current.push(curr);
    } else {
      intervals.push([...current]);
      current = [curr];
    }
  }
  intervals.push(current);
  return intervals;
}

/**
 * @param {import('./calendarDayService.js').CalendarDay[]} days
 */
export function calculateTotalPrice(days) {
  if (days.length === 0) return 0;
  const intervals = groupIntoIntervals(days);
  let total = 0;
  for (const interval of intervals) {
    for (let i = 0; i < interval.length - 1; i++) {
      total += getBasePriceForDate(interval[i].date);
    }
  }
  return total;
}

/**
 * @param {import('./calendarDayService.js').CalendarDay[]} days
 */
export function calculateFinalPrice(days) {
  if (days.length === 0) return 0;
  const intervals = groupIntoIntervals(days);
  let total = 0;
  for (const interval of intervals) {
    for (let i = 0; i < interval.length - 1; i++) {
      const basePrice = getBasePriceForDate(interval[i].date);
      const discountPercent = getDiscountPercentForDate(interval[i].date);
      const discount = Math.round((basePrice * discountPercent) / 100);
      total += basePrice - discount;
    }
  }
  return total;
}

/** @param {number} price */
export function formatPrice(price) {
  return String(price).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
}

/**
 * @param {import('./calendarDayService.js').CalendarDay[]} days
 * @param {Record<number, import('./calendarDayService.js').CalendarDay[]>} [daysByRoom]
 */
export function getFullPriceInfo(days, daysByRoom = null) {
  if (days.length === 0) return '';

  /** @type {Record<number, import('./calendarDayService.js').CalendarDay[]>} */
  const daysByRoomGroup = {};

  if (daysByRoom) {
    for (const [roomKey, roomDays] of Object.entries(daysByRoom)) {
      const selected = roomDays.filter((d) => d.status === DayStatus.selected);
      if (selected.length > 0) {
        daysByRoomGroup[Number(roomKey)] = selected;
      }
    }
  } else {
    daysByRoomGroup[1] = days;
  }

  let totalBasePrice = 0;
  let totalFinalPrice = 0;
  let totalNights = 0;
  let totalDiscountPercent = 0;
  let totalNightsWithDiscount = 0;

  for (const groupDays of Object.values(daysByRoomGroup)) {
    const intervals = groupIntoIntervals(groupDays);
    let totalNightsRoom = 0;
    for (const interval of intervals) {
      totalNightsRoom += interval.length > 1 ? interval.length - 1 : 0;
    }

    if (totalNightsRoom > 0) {
      let groupBasePrice = 0;
      let groupFinalPrice = 0;
      let groupDiscountPercent = 0;
      let groupNightsWithDiscount = 0;

      for (const interval of intervals) {
        for (let i = 0; i < interval.length - 1; i++) {
          const basePrice = getBasePriceForDate(interval[i].date);
          const discountPercent = getDiscountPercentForDate(interval[i].date);
          const discount = Math.round((basePrice * discountPercent) / 100);
          groupBasePrice += basePrice;
          groupFinalPrice += basePrice - discount;
          if (discountPercent > 0) {
            groupDiscountPercent += discountPercent;
            groupNightsWithDiscount++;
          }
        }
      }

      totalBasePrice += groupBasePrice;
      totalFinalPrice += groupFinalPrice;
      totalNights += totalNightsRoom;
      totalDiscountPercent += groupDiscountPercent;
      totalNightsWithDiscount += groupNightsWithDiscount;
    }
  }

  if (totalNights === 0) {
    return 'Выберите даты для расчета стоимости';
  }

  const discount = totalBasePrice - totalFinalPrice;
  const avgDiscountPercent =
    totalNightsWithDiscount > 0
      ? Math.floor(totalDiscountPercent / totalNightsWithDiscount)
      : 0;
  const currency =
    days.length > 0 ? getCurrencyForDate(days[0].date) : getDefaultCurrency();

  return (
    `Стоимость за ${totalNights} ${getNightWord(totalNights)}: ${formatPrice(totalBasePrice)}${currency}\n` +
    `Скидка ${avgDiscountPercent}%: -${formatPrice(discount)}${currency}\n` +
    `Итого: ${formatPrice(totalFinalPrice)}${currency}`
  );
}
