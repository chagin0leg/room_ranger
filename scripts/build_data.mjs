#!/usr/bin/env node
/**
 * Converts ICS calendar files and .env config into html/assets/data.json
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import ical from 'node-ical';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');

/**
 * @param {string} envPath
 */
function loadEnv(envPath) {
  /** @type {Record<string, string>} */
  const env = {};
  if (!fs.existsSync(envPath)) {
    throw new Error(`.env not found at ${envPath}`);
  }
  const lines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    env[trimmed.slice(0, eq).trim()] = trimmed.slice(eq + 1).trim();
  }
  for (const key of Object.keys(env)) {
    env[key] = env[key].replace(/\$([A-Z_][A-Z0-9_]*)/g, (_, name) => env[name] ?? '');
  }
  return env;
}

/**
 * @param {string} url
 */
function extractIcsFileName(url) {
  const match = url.match(/\/ical\/([0-9a-zA-Z]+)/);
  if (match) return `${match[1]}.ics`;
  try {
    const segments = new URL(url).pathname.split('/').filter(Boolean);
    return segments.length ? segments[segments.length - 1] : null;
  } catch {
    return null;
  }
}

/**
 * @param {string} value DTSTART/DTEND value, e.g. 20260421T140000 or 20260421
 * @returns {{ y: number, m: number, d: number } | null}
 */
function parseIcsDateParts(value) {
  const m = String(value).trim().match(/^(\d{4})(\d{2})(\d{2})/);
  if (!m) return null;
  return { y: Number(m[1]), m: Number(m[2]), d: Number(m[3]) };
}

/**
 * @param {{ y: number, m: number, d: number }} parts
 */
function partsToKey(parts) {
  return parts.y * 10000 + parts.m * 100 + parts.d;
}

/**
 * @param {{ y: number, m: number, d: number }} parts
 */
function partsToDateKey(parts) {
  return `${parts.y}-${String(parts.m).padStart(2, '0')}-${String(parts.d).padStart(2, '0')}`;
}

/**
 * @param {{ y: number, m: number, d: number }} parts
 */
function addDayParts(parts) {
  const dt = new Date(parts.y, parts.m - 1, parts.d + 1);
  return { y: dt.getFullYear(), m: dt.getMonth() + 1, d: dt.getDate() };
}

/**
 * Occupied nights for sutochno bookings: from check-in through checkout day (inclusive).
 * Uses calendar dates from ICS as-is (Europe/Moscow), without timezone conversion.
 *
 * @param {{ y: number, m: number, d: number }} start
 * @param {{ y: number, m: number, d: number }} end
 */
function expandBookedRange(start, end) {
  /** @type {string[]} */
  const dates = [];
  let current = start;
  const endKey = partsToKey(end);
  while (partsToKey(current) <= endKey) {
    dates.push(partsToDateKey(current));
    current = addDayParts(current);
  }
  return dates;
}

/**
 * Price/date ranges: DTEND is exclusive (iCalendar convention).
 *
 * @param {Date} start
 * @param {Date} end
 */
function expandDateRange(start, end) {
  /** @type {string[]} */
  const dates = [];
  const startParts = parseIcsDateParts(
    `${start.getFullYear()}${String(start.getMonth() + 1).padStart(2, '0')}${String(start.getDate()).padStart(2, '0')}`,
  );
  const endParts = parseIcsDateParts(
    `${end.getFullYear()}${String(end.getMonth() + 1).padStart(2, '0')}${String(end.getDate()).padStart(2, '0')}`,
  );
  if (!startParts || !endParts) return dates;

  let current = startParts;
  const endKey = partsToKey(endParts);
  while (partsToKey(current) < endKey) {
    dates.push(partsToDateKey(current));
    current = addDayParts(current);
  }
  return dates;
}

/**
 * @param {string} content
 */
function parseBookedDatesFromIcs(content) {
  /** @type {Set<string>} */
  const booked = new Set();
  const blocks = content.split('BEGIN:VEVENT');
  for (const block of blocks.slice(1)) {
    const startMatch = block.match(/^DTSTART(?:;[^:\r\n]*)?:(\S+)/m);
    const endMatch = block.match(/^DTEND(?:;[^:\r\n]*)?:(\S+)/m);
    if (!startMatch) continue;
    const start = parseIcsDateParts(startMatch[1]);
    const end = endMatch ? parseIcsDateParts(endMatch[1]) : start;
    if (!start || !end) continue;
    for (const key of expandBookedRange(start, end)) {
      booked.add(key);
    }
  }
  return [...booked].sort();
}

/**
 * @param {string} summary
 */
function parsePriceFromSummary(summary) {
  if (!summary) {
    return { price: 0, discount: 0, currency: '₽', hasPrice: false };
  }
  const parts = summary.split('|').map((s) => s.trim());
  let pricePart = parts[0] ?? '';
  let discountPart = parts[1] ?? '';
  let currency = '₽';
  if (pricePart.includes('₽')) {
    currency = '₽';
    pricePart = pricePart.replace(/₽/g, '');
  } else if (pricePart.includes('$')) {
    currency = '$';
    pricePart = pricePart.replace(/\$/g, '');
  }
  const price = parseInt(pricePart, 10) || 0;
  discountPart = discountPart.replace(/%/g, '');
  const discount = parseInt(discountPart, 10) || 0;
  return { price, discount, currency, hasPrice: price > 0 };
}

/**
 * @param {string} filePath
 */
function parseBookedDates(filePath) {
  if (!fs.existsSync(filePath)) {
    console.warn(`[ICS] File not found: ${filePath}`);
    return [];
  }
  const content = fs.readFileSync(filePath, 'utf8');
  return parseBookedDatesFromIcs(content);
}

/**
 * @param {string} filePath
 */
function parsePrices(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Prices file not found: ${filePath}`);
  }
  const content = fs.readFileSync(filePath, 'utf8');
  const calendar = ical.parseICS(content);
  /** @type {Record<string, { price: number, discount: number, currency: string }>} */
  const byDate = {};
  let defaultDiscount = 10;
  let defaultCurrency = '₽';

  for (const event of Object.values(calendar)) {
    if (!event || typeof event !== 'object' || event.type !== 'VEVENT') continue;
    const summary = event.summary?.toString() ?? '';
    const priceInfo = parsePriceFromSummary(summary);
    const start = event.start ? new Date(event.start) : null;
    const end = event.end ? new Date(event.end) : null;
    if (!start) continue;

    const startParts = parseIcsDateParts(
      `${start.getFullYear()}${String(start.getMonth() + 1).padStart(2, '0')}${String(start.getDate()).padStart(2, '0')}`,
    );
    if (!startParts) continue;

    const dates = end
      ? expandDateRange(start, end)
      : [partsToDateKey(startParts)];
    for (const key of dates) {
      byDate[key] = {
        price: priceInfo.price,
        discount: priceInfo.discount,
        currency: priceInfo.currency,
      };
    }
    if (defaultDiscount === 10 && priceInfo.hasPrice) {
      defaultDiscount = priceInfo.discount;
    }
    if (defaultCurrency === '₽' && priceInfo.hasPrice) {
      defaultCurrency = priceInfo.currency;
    }
  }

  return { byDate, defaultDiscount, defaultCurrency };
}

function readVersion() {
  const pubspecPath = path.join(rootDir, 'pubspec.yaml');
  if (fs.existsSync(pubspecPath)) {
    const content = fs.readFileSync(pubspecPath, 'utf8');
    const match = content.match(/^version:\s*(.+)$/m);
    if (match) {
      const [version, build] = match[1].trim().split('+');
      return { version: version ?? '0.0.0', build: build ?? '0' };
    }
  }
  const pkgPath = path.join(rootDir, 'package.json');
  if (fs.existsSync(pkgPath)) {
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    return {
      version: pkg.version ?? '0.9.2',
      build: String(pkg.build ?? process.env.BUILD_NUMBER ?? '0'),
    };
  }
  return { version: '0.9.2', build: '0' };
}

function main() {
  const env = loadEnv(path.join(rootDir, '.env'));
  const icsFilesRaw = env.ICS_FILES ?? '';
  const icsUrls = icsFilesRaw
    .split(',')
    .map((s) => s.trim())
    .filter((s) => s.endsWith('.ics'));

  /** @type {Record<string, { booked: string[] }>} */
  const rooms = {};
  for (let i = 0; i < icsUrls.length; i++) {
    const roomNum = String(i + 1);
    const fileName = extractIcsFileName(icsUrls[i]);
    if (!fileName) {
      console.warn(`[ICS] Cannot resolve filename for room ${roomNum}`);
      rooms[roomNum] = { booked: [] };
      continue;
    }
    const filePath = path.join(rootDir, 'assets', 'data', fileName);
    rooms[roomNum] = { booked: parseBookedDates(filePath) };
    console.log(`[ICS] Room ${roomNum}: ${rooms[roomNum].booked.length} booked days`);
  }

  const pricesUrl = env.PRICES_FILE;
  if (!pricesUrl) {
    throw new Error('PRICES_FILE not set in .env');
  }
  const pricesFileName = extractIcsFileName(pricesUrl);
  if (!pricesFileName) {
    throw new Error(`Cannot resolve prices filename from: ${pricesUrl}`);
  }
  const pricesPath = path.join(rootDir, 'assets', 'data', pricesFileName);
  const prices = parsePrices(pricesPath);
  console.log(`[PRICES] ${Object.keys(prices.byDate).length} price dates loaded`);

  const { version, build } = readVersion();
  const output = {
    config: {
      minNights: parseInt(env.MIN_NIGHTS ?? '4', 10) || 4,
      telegramManagerId: env.TELEGRAM_MANAGER_ID ?? '',
      version,
      build,
    },
    prices: {
      defaultDiscount: prices.defaultDiscount,
      defaultCurrency: prices.defaultCurrency,
      byDate: prices.byDate,
    },
    rooms,
  };

  const outDir = path.join(rootDir, 'html', 'assets');
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, 'data.json');
  fs.writeFileSync(outPath, JSON.stringify(output, null, 2), 'utf8');
  console.log(`✅ Wrote ${outPath}`);
}

main();
