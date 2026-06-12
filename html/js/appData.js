/** @typedef {{ price: number, discount: number, currency: string, hasPrice: boolean }} PriceInfo */

/** @type {{ config: object, prices: object, rooms: object } | null} */
let appData = null;

/**
 * @param {{ config: object, prices: object, rooms: object }} data
 */
export function setAppData(data) {
  appData = data;
}

export function getAppData() {
  if (!appData) throw new Error('App data not loaded');
  return appData;
}

export function getMinNights() {
  return getAppData().config.minNights ?? 4;
}

export function getTelegramManagerId() {
  return getAppData().config.telegramManagerId ?? '';
}

export function getDefaultCurrency() {
  return getAppData().prices.defaultCurrency ?? '₽';
}

/**
 * @param {Date} date
 * @returns {PriceInfo}
 */
export function getPriceForDate(date) {
  const { prices } = getAppData();
  const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  const entry = prices.byDate[key];
  if (entry) {
    return {
      price: entry.price,
      discount: entry.discount,
      currency: entry.currency,
      hasPrice: entry.price > 0,
    };
  }
  return {
    price: 0,
    discount: prices.defaultDiscount ?? 10,
    currency: prices.defaultCurrency ?? '₽',
    hasPrice: false,
  };
}

/** @param {Date} date */
export function getBasePriceForDate(date) {
  return getPriceForDate(date).price;
}

/** @param {Date} date */
export function getDiscountPercentForDate(date) {
  return getPriceForDate(date).discount;
}

/** @param {Date} date */
export function getCurrencyForDate(date) {
  return getPriceForDate(date).currency;
}

/** @param {Date} date */
export function hasPriceForDate(date) {
  return getPriceForDate(date).hasPrice;
}

/** @returns {number[]} */
export function getAvailableRooms() {
  return Object.keys(getAppData().rooms)
    .map(Number)
    .sort((a, b) => a - b);
}

/** @param {number} room */
export function getBookedDateKeys(room) {
  const roomData = getAppData().rooms[String(room)];
  return roomData?.booked ?? [];
}
