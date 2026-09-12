/**
 * Cell value parsing shared by pharmacy drug import sources.
 *
 * Spreadsheet exports mix typed cells (numbers, dates) with free text such as
 * "6,000", "None", or "2028-04-30"; these helpers normalize both shapes and
 * report unparsable values instead of guessing.
 */

const EMPTY_TOKENS = new Set(['', 'none', 'null', 'n/a', 'na', '-', '--']);
const EXCEL_EPOCH_OFFSET_DAYS = 25569;
const MS_PER_DAY = 86400000;
const MAX_EXCEL_SERIAL = 2958465;

const isEmptyToken = (text) => EMPTY_TOKENS.has(String(text).trim().toLowerCase());

/**
 * Collapse internal whitespace and treat placeholder tokens ("None", "-") as empty.
 *
 * @param {*} value
 * @returns {string|null}
 */
const collapseWhitespace = (value) => {
  if (value == null) return null;
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value.toISOString().slice(0, 10);
  }
  const text = String(value).replace(/\s+/g, ' ').trim();
  return text && !isEmptyToken(text) ? text : null;
};

/**
 * @param {*} value
 * @returns {{ value: number|null, invalid: boolean }}
 */
const parseNumber = (value) => {
  if (value == null) return { value: null, invalid: false };
  if (typeof value === 'number') {
    return Number.isFinite(value) ? { value, invalid: false } : { value: null, invalid: true };
  }
  if (typeof value === 'boolean' || value instanceof Date) {
    return { value: null, invalid: true };
  }
  const text = String(value).trim();
  if (!text || isEmptyToken(text)) return { value: null, invalid: false };
  const normalized = text.replace(/[\s,]/g, '');
  if (!/^[-+]?(\d+\.?\d*|\.\d+)$/.test(normalized)) {
    return { value: null, invalid: true };
  }
  return { value: Number(normalized), invalid: false };
};

const toUtcDate = (year, month, day) => {
  const date = new Date(Date.UTC(year, month - 1, day));
  const isSameDay =
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
  return isSameDay ? date : null;
};

const toDateOnly = (date) =>
  toUtcDate(date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate());

/**
 * Parse a date cell. Date-only values normalize to UTC midnight.
 *
 * Accepts Date cells, Excel serial numbers, ISO strings, and day-first
 * DD/MM/YYYY text.
 *
 * @param {*} value
 * @param {Object} [options]
 * @param {boolean} [options.dateOnly=true]
 * @returns {{ value: Date|null, invalid: boolean }}
 */
const parseDate = (value, { dateOnly = true } = {}) => {
  if (value == null) return { value: null, invalid: false };

  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) return { value: null, invalid: true };
    return { value: dateOnly ? toDateOnly(value) : value, invalid: false };
  }

  if (typeof value === 'number') {
    if (!Number.isFinite(value) || value <= 0 || value > MAX_EXCEL_SERIAL) {
      return { value: null, invalid: true };
    }
    const date = new Date(Math.round((value - EXCEL_EPOCH_OFFSET_DAYS) * MS_PER_DAY));
    return { value: dateOnly ? toDateOnly(date) : date, invalid: false };
  }

  const text = String(value).trim();
  if (!text || isEmptyToken(text)) return { value: null, invalid: false };

  const isoMatch = text.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  if (isoMatch) {
    const date = toUtcDate(Number(isoMatch[1]), Number(isoMatch[2]), Number(isoMatch[3]));
    return date ? { value: date, invalid: false } : { value: null, invalid: true };
  }

  const dayFirstMatch = text.match(/^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})$/);
  if (dayFirstMatch) {
    const date = toUtcDate(
      Number(dayFirstMatch[3]),
      Number(dayFirstMatch[2]),
      Number(dayFirstMatch[1])
    );
    return date ? { value: date, invalid: false } : { value: null, invalid: true };
  }

  const parsed = new Date(text);
  if (Number.isNaN(parsed.getTime())) return { value: null, invalid: true };
  return { value: dateOnly ? toDateOnly(parsed) : parsed, invalid: false };
};

/**
 * @param {Date|null|undefined} value
 * @returns {string|null} YYYY-MM-DD
 */
const toIsoDate = (value) =>
  value instanceof Date && !Number.isNaN(value.getTime())
    ? value.toISOString().slice(0, 10)
    : null;

const startOfUtcDay = (value = new Date()) => toDateOnly(value);

module.exports = {
  collapseWhitespace,
  parseNumber,
  parseDate,
  toIsoDate,
  startOfUtcDay,
};
