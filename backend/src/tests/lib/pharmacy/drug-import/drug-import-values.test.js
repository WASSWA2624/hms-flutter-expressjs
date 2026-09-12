const {
  collapseWhitespace,
  parseNumber,
  parseDate,
  toIsoDate,
} = require('@lib/pharmacy/drug-import/drug-import-values');

describe('drug-import-values', () => {
  describe('collapseWhitespace', () => {
    it('collapses internal whitespace and treats placeholders as empty', () => {
      expect(collapseWhitespace('  I.V. CANNULA   BLUE ')).toBe('I.V. CANNULA BLUE');
      expect(collapseWhitespace('None')).toBeNull();
      expect(collapseWhitespace(' - ')).toBeNull();
      expect(collapseWhitespace(null)).toBeNull();
    });
  });

  describe('parseNumber', () => {
    it('accepts typed numbers and thousands separators', () => {
      expect(parseNumber(6000)).toEqual({ value: 6000, invalid: false });
      expect(parseNumber('6,000.50')).toEqual({ value: 6000.5, invalid: false });
      expect(parseNumber('-2')).toEqual({ value: -2, invalid: false });
    });

    it('treats blanks as missing and text as invalid', () => {
      expect(parseNumber('')).toEqual({ value: null, invalid: false });
      expect(parseNumber('None')).toEqual({ value: null, invalid: false });
      expect(parseNumber('ten')).toEqual({ value: null, invalid: true });
      expect(parseNumber(true)).toEqual({ value: null, invalid: true });
    });
  });

  describe('parseDate', () => {
    it('parses ISO, day-first, Excel serial, and Date cells to UTC midnight', () => {
      expect(toIsoDate(parseDate('2028-04-30').value)).toBe('2028-04-30');
      expect(toIsoDate(parseDate('30/04/2028').value)).toBe('2028-04-30');
      expect(toIsoDate(parseDate(46874).value)).toBe('2028-05-01');
      expect(toIsoDate(parseDate(new Date('2028-04-30T15:31:58.592Z')).value)).toBe(
        '2028-04-30'
      );
    });

    it('keeps the time component when dateOnly is false', () => {
      expect(parseDate('2026-07-02T15:31:58.592Z', { dateOnly: false }).value.toISOString()).toBe(
        '2026-07-02T15:31:58.592Z'
      );
    });

    it('flags impossible dates instead of rolling them over', () => {
      expect(parseDate('2028-02-30')).toEqual({ value: null, invalid: true });
      expect(parseDate('0028-05-05')).toEqual({ value: null, invalid: true });
      expect(parseDate('soon')).toEqual({ value: null, invalid: true });
      expect(parseDate('')).toEqual({ value: null, invalid: false });
    });
  });
});
