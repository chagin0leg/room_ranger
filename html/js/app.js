import { setAppData, getAvailableRooms, getDefaultCurrency } from './appData.js';
import {
  DayStatus,
  copyDay,
  generateForAllRooms,
  applyGroupPositions,
  getMinNights,
} from './calendarDayService.js';
import { getMonthName, isSameDay, makeDate, getNightWord } from './dateUtils.js';
import {
  calculateTotalPrice,
  calculateFinalPrice,
  formatPrice,
} from './priceUtils.js';
import {
  buildTelegramBookingMessage,
  sendTelegramBookingMessage,
  formatAllBookingDatesText,
} from './telegramUtils.js';

/** @type {Record<number, import('./calendarDayService.js').CalendarDay[]>} */
let daysByRoom = {};
/** @type {Record<number, Set<string>>} */
let bookedMap = {};
/** @type {Record<number, Set<string>>} */
let selectedMap = {};
let selectedYear = new Date().getFullYear();
let selectedRoom = 2;
let pickedRoom = 2;
let appConfig = {};

const appEl = document.getElementById('app');
const versionEl = document.getElementById('version');
let bookingTopEl = null;
let calendarGridEl = null;

/** @type {{ startX: number, startY: number, isDragging: boolean, lastDayKey: string | null } | null} */
let activeGesture = null;

const TAP_THRESHOLD_PX = 5;

function hasInsufficientNights() {
  return Object.values(daysByRoom).some((days) =>
    days.some((d) => d.status === DayStatus.insufficientNights),
  );
}

function hasAnySelected() {
  return Object.values(daysByRoom).some((days) =>
    days.some((d) => d.status === DayStatus.selected),
  );
}

function getStatusMessage() {
  if (pickedRoom <= 0) return 'Выберите номер';
  if (!hasAnySelected() && !hasInsufficientNights()) return 'Выберите даты';
  if (hasInsufficientNights()) {
    const min = getMinNights();
    return `Мин. ${min} ${getNightWord(min)} подряд`;
  }
  return formatAllBookingDatesText(daysByRoom);
}

function getButtonText() {
  const min = getMinNights();
  if (hasInsufficientNights()) return `Мин. ${min} ${getNightWord(min)} подряд  `;
  if (hasAnySelected()) return 'Забронировать  ';
  return 'Задать вопрос  ';
}

/**
 * @param {import('./calendarDayService.js').CalendarDay[]} days
 * @param {number} clickedIndex
 * @param {boolean} isRemoving
 */
function updateRangeStatuses(days, clickedIndex, isRemoving) {
  let left = clickedIndex;
  while (
    left > 0 &&
    (days[left - 1].status === DayStatus.selected ||
      days[left - 1].status === DayStatus.insufficientNights)
  ) {
    left--;
  }
  let right = clickedIndex;
  while (
    right < days.length - 1 &&
    (days[right + 1].status === DayStatus.selected ||
      days[right + 1].status === DayStatus.insufficientNights)
  ) {
    right++;
  }

  /** @type {number[]} */
  let range;
  if (isRemoving) {
    range = [];
    for (let i = left; i <= right; i++) {
      if (
        i !== clickedIndex &&
        (days[i].status === DayStatus.selected ||
          days[i].status === DayStatus.insufficientNights)
      ) {
        range.push(i);
      }
    }
  } else {
    range = [];
    for (let i = left; i <= right; i++) range.push(i);
  }

  if (range.length === 0) return;

  const minNights = getMinNights();
  const nights = range.length - 1;
  const newStatus =
    nights >= minNights ? DayStatus.selected : DayStatus.insufficientNights;

  for (const i of range) {
    if (
      days[i].status === DayStatus.selected ||
      days[i].status === DayStatus.insufficientNights
    ) {
      days[i] = copyDay(days[i], { status: newStatus });
    }
  }

  const affectedDays = range.map((i) => days[i]);
  applyGroupPositions(affectedDays, newStatus);
  for (let j = 0; j < range.length; j++) {
    days[range[j]] = affectedDays[j];
  }
}

/** @param {Date} date */
function onDateSelected(date) {
  const days = daysByRoom[selectedRoom];
  if (!days) return;
  const idx = days.findIndex((d) => isSameDay(d.date, date));
  if (idx === -1) return;
  const current = days[idx];

  if (
    current.status === DayStatus.selected ||
    current.status === DayStatus.insufficientNights
  ) {
    days[idx] = copyDay(current, { status: DayStatus.free, position: 'single', groupId: null });
    updateRangeStatuses(days, idx, true);
  } else if (current.status === DayStatus.free) {
    days[idx] = copyDay(current, { status: DayStatus.selected });
    updateRangeStatuses(days, idx, false);
  }
  render();
}

function onYearChanged(newYear) {
  selectedYear = newYear;
  const rooms = Object.keys(daysByRoom).map(Number);
  const from = makeDate(selectedYear, 1, 1);
  const to = makeDate(selectedYear + 2, 12, 31);
  daysByRoom = generateForAllRooms(rooms, from, to, bookedMap, selectedMap);
  render();
}

function onRoomChanged(room) {
  selectedRoom = room;
  pickedRoom = room;
  render();
}

function onBookingClick() {
  if (hasInsufficientNights()) return;
  sendTelegramBookingMessage(buildTelegramBookingMessage(daysByRoom));
}

/**
 * @param {number} year
 * @param {number} month
 * @param {number} day
 */
function dayKey(year, month, day) {
  return `${year}-${month}-${day}`;
}

/**
 * @param {number} clientX
 * @param {number} clientY
 * @returns {{ year: number, month: number, day: number } | null}
 */
function resolveDayAtPoint(clientX, clientY) {
  const el = document.elementFromPoint(clientX, clientY);
  const cell = el?.closest('.day-cell[data-day]');
  if (!cell) return null;

  const monthCell = cell.closest('.month-cell');
  if (!monthCell) return null;

  const weeks = monthCell.querySelector('.month-weeks');
  if (!weeks || weeks.classList.contains('is-disabled')) return null;

  const year = Number(monthCell.dataset.year);
  const month = Number(monthCell.dataset.month);
  const day = Number(cell.dataset.day);

  const roomDays = daysByRoom[selectedRoom] ?? [];
  const calendarDay = roomDays.find(
    (d) =>
      d.date.getFullYear() === year &&
      d.date.getMonth() === month - 1 &&
      d.date.getDate() === day,
  );
  if (!calendarDay) return null;
  if (
    calendarDay.status === DayStatus.booked ||
    calendarDay.status === DayStatus.unavailable
  ) {
    return null;
  }

  return { year, month, day };
}

/**
 * @param {{ year: number, month: number, day: number }} target
 */
function toggleDayAt(target) {
  onDateSelected(makeDate(target.year, target.month, target.day));
}

function initCalendarGestures() {
  if (!calendarGridEl) return;

  calendarGridEl.addEventListener('pointerdown', (e) => {
    if (e.button !== 0) return;
    const weeks = e.target.closest('.month-weeks');
    if (!weeks || weeks.classList.contains('is-disabled')) return;

    activeGesture = {
      startX: e.clientX,
      startY: e.clientY,
      isDragging: false,
      lastDayKey: null,
    };
    calendarGridEl.setPointerCapture(e.pointerId);
  });

  calendarGridEl.addEventListener('pointermove', (e) => {
    if (!activeGesture) return;

    const dist = Math.hypot(e.clientX - activeGesture.startX, e.clientY - activeGesture.startY);

    if (dist >= TAP_THRESHOLD_PX && !activeGesture.isDragging) {
      activeGesture.isDragging = true;
      const startTarget = resolveDayAtPoint(activeGesture.startX, activeGesture.startY);
      if (startTarget) {
        activeGesture.lastDayKey = dayKey(startTarget.year, startTarget.month, startTarget.day);
        toggleDayAt(startTarget);
      }
    }

    if (!activeGesture.isDragging) return;

    const target = resolveDayAtPoint(e.clientX, e.clientY);
    if (!target) return;

    const key = dayKey(target.year, target.month, target.day);
    if (key === activeGesture.lastDayKey) return;

    activeGesture.lastDayKey = key;
    toggleDayAt(target);
  });

  calendarGridEl.addEventListener('pointerup', (e) => {
    if (!activeGesture) return;

    const dist = Math.hypot(e.clientX - activeGesture.startX, e.clientY - activeGesture.startY);
    if (!activeGesture.isDragging && dist < TAP_THRESHOLD_PX) {
      const target = resolveDayAtPoint(e.clientX, e.clientY);
      if (target) toggleDayAt(target);
    }

    activeGesture = null;
    try {
      calendarGridEl.releasePointerCapture(e.pointerId);
    } catch {
      /* ignore */
    }
  });

  calendarGridEl.addEventListener('pointercancel', (e) => {
    activeGesture = null;
    try {
      calendarGridEl.releasePointerCapture(e.pointerId);
    } catch {
      /* ignore */
    }
  });
}

/**
 * @param {string} position
 * @param {string} status
 */
function bgClass(position, status) {
  const statusClass =
    status === DayStatus.selected
      ? 'selected'
      : status === DayStatus.insufficientNights
        ? 'insufficient'
        : status === DayStatus.booked
          ? 'booked'
          : '';
  if (!statusClass) return '';
  return `day-cell__bg day-cell__bg--${position} day-cell__bg--${statusClass}`;
}

/**
 * @param {number} month
 * @param {number} year
 * @param {import('./calendarDayService.js').CalendarDay[]} days
 * @param {boolean} isEnabled
 */
function renderMonth(month, year, days, isEnabled) {
  const daysInMonth = new Date(year, month, 0).getDate();
  const firstWeekday = new Date(year, month - 1, 1).getDay();
  const mondayBasedFirst = firstWeekday === 0 ? 7 : firstWeekday;

  const getDay = (dayNum) =>
    days.find(
      (d) =>
        d.date.getFullYear() === year &&
        d.date.getMonth() === month - 1 &&
        d.date.getDate() === dayNum,
    );

  let weeksHtml = '';
  for (let week = 0; week < 6; week++) {
    let row = '';
    for (let dayIndex = 0; dayIndex < 7; dayIndex++) {
      const dayNumber = week * 7 + dayIndex - mondayBasedFirst + 2;
      const day = getDay(dayNumber);
      if (dayNumber < 1 || dayNumber > daysInMonth || !day) {
        row += '<div class="day-cell day-cell--empty"></div>';
        continue;
      }

      const isInteractive =
        isEnabled &&
        day.status !== DayStatus.booked &&
        day.status !== DayStatus.unavailable;
      const unavailable = day.status === DayStatus.unavailable;
      const bg =
        day.status === DayStatus.selected ||
        day.status === DayStatus.insufficientNights ||
        day.status === DayStatus.booked
          ? `<div class="${bgClass(day.position, day.status)}"></div>`
          : '';

      const numHtml = unavailable
        ? `<span class="day-cell__num day-cell__num--unavailable"><span class="day-cell__num-value">${dayNumber}</span><span class="day-cell__cross" aria-hidden="true">✗</span></span>`
        : `<span class="day-cell__num">${dayNumber}</span>`;

      row += `<div class="day-cell${isInteractive ? ' day-cell--interactive' : ''}" data-day="${dayNumber}">${bg}${numHtml}</div>`;
    }
    weeksHtml += `<div class="week">${row}</div>`;
  }

  return `
    <div class="month-cell" data-month="${month}" data-year="${year}">
      <div class="month-title">${getMonthName(month, 'nominative')}</div>
      <div class="weekdays">
        ${['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
          .map((d) => `<div class="weekday">${d}</div>`)
          .join('')}
      </div>
      <div class="month-weeks${isEnabled ? '' : ' is-disabled'}">
        ${weeksHtml}
      </div>
    </div>`;
}

function renderRoomButton(roomNum) {
  const roomDays = daysByRoom[roomNum] ?? [];
  const selectedDays = roomDays.filter((d) => d.status === DayStatus.selected);
  const insufficientDays = roomDays.filter(
    (d) => d.status === DayStatus.insufficientNights,
  );
  const allSelectedDays = [...selectedDays, ...insufficientDays];
  const basePrice = calculateTotalPrice(allSelectedDays);
  const finalPrice = calculateFinalPrice(allSelectedDays);
  const active = pickedRoom === roomNum ? ' is-active' : '';

  let inner;
  if (allSelectedDays.length === 0 || basePrice === 0) {
    inner = String(roomNum);
  } else {
    inner = `<span class="room-btn__strike">${formatPrice(basePrice)}</span><span class="room-btn__total">${formatPrice(finalPrice)}${getDefaultCurrency()}</span>`;
  }

  return `<button type="button" class="room-btn${active}" data-room="${roomNum}">${inner}</button>`;
}

function renderBookingTop() {
  const currentYear = new Date().getFullYear();
  const maxYear = currentYear + 2;
  const canGoLeft = selectedYear > currentYear;
  const canGoRight = selectedYear < maxYear;
  const insufficient = hasInsufficientNights();

  bookingTopEl.innerHTML = `
    <div class="booking-top-inner">
      <div class="building-panel">
        <img src="assets/home.png" alt="Здание">
        <div class="room-buttons">
          <div class="room-row">${renderRoomButton(4)}${renderRoomButton(3)}</div>
          <div class="room-row">${renderRoomButton(2)}${renderRoomButton(1)}</div>
        </div>
      </div>
      <div class="controls-panel">
        <div class="year-selector">
          <span class="year-selector__label">${selectedYear}</span>
          <div class="year-selector__nav">
            <button type="button" class="year-btn" data-year-delta="-1" ${canGoLeft ? '' : 'disabled'}>‹</button>
            <button type="button" class="year-btn" data-year-delta="1" ${canGoRight ? '' : 'disabled'}>›</button>
          </div>
        </div>
        <button type="button" class="booking-btn${insufficient ? ' is-centered' : ''}" id="booking-btn" ${insufficient ? 'disabled' : ''}>
          ${insufficient ? '' : '<svg class="booking-btn__icon" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M9.78 18.65l.28-4.23 7.68-6.92c.34-.31-.07-.46-.52-.19L7.74 13.3 3.64 12c-.88-.25-.89-.86.2-1.3l15.97-6.16c.73-.33 1.43.18 1.15 1.3l-2.72 12.81c-.19.91-.74 1.13-1.5.71L12.6 16.3l-1.99 1.93c-.23.23-.42.42-.83.42z"/></svg>'}
          <span>${getButtonText()}</span>
          ${insufficient ? '' : '<span></span>'}
        </button>
        <div class="status-message">${getStatusMessage()}</div>
      </div>
    </div>`;

  bookingTopEl.querySelectorAll('[data-room]').forEach((btn) => {
    btn.addEventListener('click', () => onRoomChanged(Number(btn.dataset.room)));
  });

  bookingTopEl.querySelectorAll('[data-year-delta]').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (btn.disabled) return;
      onYearChanged(selectedYear + Number(btn.dataset.yearDelta));
    });
  });

  document.getElementById('booking-btn')?.addEventListener('click', onBookingClick);
}

function renderCalendar() {
  const days = daysByRoom[selectedRoom] ?? [];
  let calendarHtml = '';

  for (let row = 0; row < 4; row++) {
    let rowHtml = '<div class="calendar-row">';
    for (let col = 0; col < 3; col++) {
      const monthIndex = row * 3 + col + 1;
      const monthDays = days.filter(
        (d) =>
          d.date.getMonth() === monthIndex - 1 &&
          d.date.getFullYear() === selectedYear,
      );
      rowHtml += renderMonth(monthIndex, selectedYear, monthDays, selectedRoom > 0);
    }
    rowHtml += '</div>';
    calendarHtml += rowHtml;
  }

  calendarGridEl.innerHTML = calendarHtml;
}

function render() {
  if (!bookingTopEl || !calendarGridEl) return;
  appEl.classList.remove('is-loading');
  renderBookingTop();
  renderCalendar();
}

function ensureAppShell() {
  if (bookingTopEl && calendarGridEl) return;

  appEl.innerHTML = `
    <div id="booking-top" class="booking-top"></div>
    <div id="calendar-grid" class="calendar-grid"></div>`;

  bookingTopEl = document.getElementById('booking-top');
  calendarGridEl = document.getElementById('calendar-grid');
  initCalendarGestures();
}

function initFromData(data) {
  setAppData(data);
  appConfig = data.config;

  const rooms = getAvailableRooms();
  bookedMap = {};
  for (const room of rooms) {
    const keys = data.rooms[String(room)]?.booked ?? [];
    bookedMap[room] = new Set(keys);
  }
  selectedMap = {};

  const from = makeDate(selectedYear, 1, 1);
  const to = makeDate(selectedYear + 2, 12, 31);
  daysByRoom = generateForAllRooms(rooms, from, to, bookedMap, selectedMap);

  const version = appConfig.version ?? '0.0.0';
  const build = appConfig.build ?? 'dev';
  versionEl.textContent = `v${version} (${build})`;

  ensureAppShell();
  render();
}

async function loadApp() {
  const response = await fetch('assets/data.json', { cache: 'no-store' });
  if (!response.ok) {
    appEl.innerHTML = '<p>Не удалось загрузить данные календаря.</p>';
    return;
  }
  const data = await response.json();
  initFromData(data);
}

loadApp();
