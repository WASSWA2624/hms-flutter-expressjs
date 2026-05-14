const prisma = require('@prisma/client');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

describe('resolve-entity-id helpers', () => {
  afterEach(() => {
    delete prisma.test_model;
    jest.clearAllMocks();
  });

  test('returns null instead of fabricating a record when the prisma delegate is unavailable', async () => {
    const record = await resolveModelRecordByIdentifier({
      model: 'test_model',
      identifier: 'missing-friendly-id',
    });

    const resolvedId = await resolveModelIdByIdentifier({
      model: 'test_model',
      identifier: 'missing-friendly-id',
    });

    expect(record).toBeNull();
    expect(resolvedId).toBeNull();
  });

  test('uses the prisma delegate when it exists', async () => {
    prisma.test_model = {
      findFirst: jest.fn().mockResolvedValue({ id: 'record-123' }),
    };

    const record = await resolveModelRecordByIdentifier({
      model: 'test_model',
      identifier: 'REC-123',
    });

    expect(record).toEqual({ id: 'record-123' });
    expect(prisma.test_model.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          deleted_at: null,
          human_friendly_id: 'REC-123',
        }),
      })
    );
  });
});
