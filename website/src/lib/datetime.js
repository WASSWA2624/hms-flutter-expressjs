/**
 * Human-readable timestamps for the notifications the site sends.
 *
 * These land in an inbox and in WhatsApp, where an ISO string
 * ("2026-09-13T09:00:53.815Z") is something to decode rather than read. They
 * are rendered in East Africa Time because that is the clock the people
 * reading them are on, in 24-hour form, with the zone named so a timestamp
 * read from anywhere else is still unambiguous.
 *
 * @file src/lib/datetime.js
 */

/** The team's timezone, and the one the notifications are read in. */
export const DISPLAY_TIME_ZONE = 'Africa/Kampala';
export const DISPLAY_TIME_ZONE_LABEL = 'EAT';

/**
 * Format a moment as e.g. "Sunday, 13 September 2026 at 12:07 EAT".
 *
 * `hourCycle: 'h23'` rather than `hour12: false` - the latter can render
 * midnight as "24:00" in some locales.
 *
 * @param {Date} [date] - Moment to format; defaults to now
 * @returns {string} Readable timestamp
 */
export function formatTimestamp(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: DISPLAY_TIME_ZONE,
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);

  const get = (type) => parts.find((part) => part.type === type)?.value || '';

  return (
    `${get('weekday')}, ${get('day')} ${get('month')} ${get('year')}` +
    ` at ${get('hour')}:${get('minute')} ${DISPLAY_TIME_ZONE_LABEL}`
  );
}
