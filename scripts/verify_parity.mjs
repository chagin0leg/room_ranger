#!/usr/bin/env node
/**
 * Smoke tests for HTML port parity with Flutter logic.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { setAppData, getAvailableRooms } from '../html/js/appData.js';
import {
  DayStatus,
  copyDay,
  generateForAllRooms,
  applyGroupPositions,
  getMinNights,
} from '../html/js/calendarDayService.js';
import { isSameDay, makeDate } from '../html/js/dateUtils.js';
import { calculateTotalPrice, calculateFinalPrice } from '../html/js/priceUtils.js';
import { buildTelegramBookingMessage } from '../html/js/telegramUtils.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const dataPath = path.join(__dirname, '..', 'html', 'assets', 'data.json');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

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

function selectDate(days, date) {
  const idx = days.findIndex((d) => isSameDay(d.date, date));
  assert(idx !== -1, 'date not found in calendar');
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
}

function run() {
  assert(fs.existsSync(dataPath), 'data.json must exist — run npm run build:data');
  const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));

  assert(data.config?.telegramManagerId, 'config.telegramManagerId required');
  assert(data.config?.minNights >= 1, 'config.minNights must be positive');
  assert(Object.keys(data.rooms).length === 4, 'expected 4 rooms');
  assert(Object.keys(data.prices.byDate).length > 0, 'prices.byDate must not be empty');

  setAppData(data);
  const rooms = getAvailableRooms();
  assert(rooms.length === 4, 'getAvailableRooms should return 4 rooms');

  const from = makeDate(new Date().getFullYear(), 1, 1);
  const to = makeDate(new Date().getFullYear() + 2, 12, 31);
  const bookedMap = {};
  for (const room of rooms) {
    bookedMap[room] = new Set(data.rooms[String(room)].booked);
  }
  const daysByRoom = generateForAllRooms(rooms, from, to, bookedMap, {});

  for (const room of rooms) {
    const days = daysByRoom[room];
    assert(days.length > 1000, `room ${room} should have multi-year days`);
    const booked = days.filter((d) => d.status === DayStatus.booked);
    assert(booked.length > 0, `room ${room} should have booked days from ICS`);
  }

  const minNights = getMinNights();
  assert(minNights === data.config.minNights, 'minNights should match config');

  const room2 = [...daysByRoom[2]];
  const freeFuture = room2.filter((d) => d.status === DayStatus.free && d.date > new Date());
  assert(freeFuture.length > minNights + 2, 'need free future days for selection test');

  selectDate(room2, freeFuture[0].date);
  assert(
    room2.find((d) => isSameDay(d.date, freeFuture[0].date))?.status ===
      DayStatus.insufficientNights,
    'single day should be insufficient',
  );

  for (let i = 1; i <= minNights; i++) {
    selectDate(room2, freeFuture[i].date);
  }
  const selectedBlock = room2.filter(
    (d) =>
      d.status === DayStatus.selected &&
      freeFuture.slice(0, minNights + 1).some((f) => isSameDay(f.date, d.date)),
  );
  assert(
    selectedBlock.length === minNights + 1,
    `range of ${minNights + 1} days should become selected`,
  );

  selectDate(room2, freeFuture[0].date);
  assert(
    room2.find((d) => isSameDay(d.date, freeFuture[0].date))?.status === DayStatus.free,
    'clicking selected day should deselect it',
  );

  const roomForPrice = [...daysByRoom[2]];
  for (let i = 0; i <= minNights; i++) {
    selectDate(roomForPrice, freeFuture[i].date);
  }
  const pick = roomForPrice.filter((d) => d.status === DayStatus.selected);
  assert(pick.length === minNights + 1, 'valid range should remain selected for pricing');
  const total = calculateTotalPrice(pick);
  const finalP = calculateFinalPrice(pick);
  assert(total > 0, 'total price should be positive for selected range');
  assert(finalP > 0 && finalP <= total, 'final price should be within total');

  const msg = buildTelegramBookingMessage({ 2: pick });
  assert(msg.includes('Заявка'), 'telegram message footer');
  assert(msg.includes('Номер 2'), 'telegram message should list room');

  console.log('✅ All parity smoke tests passed');
  console.log(`   Rooms: ${rooms.join(', ')}`);
  console.log(`   Price dates: ${Object.keys(data.prices.byDate).length}`);
  console.log(`   Min nights: ${minNights}`);
}

run();
