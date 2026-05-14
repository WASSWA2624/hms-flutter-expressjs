/**
 * backfill-vital-bp-components script tests
 */

jest.mock('../../../src/prisma/client', () => ({
  vital_sign: {
    findMany: jest.fn(),
    update: jest.fn(),
  },
  $disconnect: jest.fn(),
}));

const prisma = require('../../../src/prisma/client');
const {
  parseLegacyBpValue,
  backfillBpComponents,
} = require('../../../scripts/backfill-vital-bp-components');

describe('backfill-vital-bp-components script', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('parseLegacyBpValue', () => {
    it('parses valid blood pressure strings', () => {
      expect(parseLegacyBpValue('120/80')).toEqual({ systolic: 120, diastolic: 80 });
      expect(parseLegacyBpValue(' 118.5 / 77.2 ')).toEqual({ systolic: 118.5, diastolic: 77.2 });
    });

    it('returns null for invalid strings', () => {
      expect(parseLegacyBpValue('invalid')).toBeNull();
      expect(parseLegacyBpValue('120')).toBeNull();
      expect(parseLegacyBpValue(null)).toBeNull();
    });
  });

  describe('backfillBpComponents', () => {
    it('summarizes dry-run updates without mutating records', async () => {
      prisma.vital_sign.findMany
        .mockResolvedValueOnce([
          {
            id: 'row-1',
            value: '120 / 80',
            systolic_value: null,
            diastolic_value: null,
            map_value: null,
          },
          {
            id: 'row-2',
            value: '110/70',
            systolic_value: 110,
            diastolic_value: 70,
            map_value: 83.33,
          },
          {
            id: 'row-3',
            value: 'unknown',
            systolic_value: null,
            diastolic_value: null,
            map_value: null,
          },
        ])
        .mockResolvedValueOnce([]);

      const summary = await backfillBpComponents({ dryRun: true });

      expect(summary).toEqual({
        dryRun: true,
        scanned: 3,
        updated: 1,
        unchanged: 2,
        unparsable: 1,
      });
      expect(prisma.vital_sign.update).not.toHaveBeenCalled();
    });

    it('updates parsed rows and canonicalizes value when executing', async () => {
      prisma.vital_sign.findMany
        .mockResolvedValueOnce([
          {
            id: 'row-1',
            value: '121 / 79',
            systolic_value: null,
            diastolic_value: null,
            map_value: null,
          },
        ])
        .mockResolvedValueOnce([]);

      const summary = await backfillBpComponents({ dryRun: false });

      expect(summary).toEqual({
        dryRun: false,
        scanned: 1,
        updated: 1,
        unchanged: 0,
        unparsable: 0,
      });
      expect(prisma.vital_sign.update).toHaveBeenCalledWith({
        where: { id: 'row-1' },
        data: {
          value: '121/79',
          systolic_value: 121,
          diastolic_value: 79,
          map_value: 93,
        },
      });
    });
  });
});

