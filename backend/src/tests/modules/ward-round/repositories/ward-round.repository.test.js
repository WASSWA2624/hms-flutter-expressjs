/**
 * Ward Round repository tests
 */

const wardRoundRepository = require('../../../../modules/ward-round/repositories/ward-round.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  ward_round: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Ward Round Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find ward round by id', async () => {
      const mockWardRound = { id: 'test-id', admission_id: 'admission-id', notes: 'Patient stable', deleted_at: null };
      prisma.ward_round.findFirst.mockResolvedValue(mockWardRound);
      const result = await wardRoundRepository.findById('test-id');
      expect(result).toEqual(mockWardRound);
      expect(prisma.ward_round.findFirst).toHaveBeenCalledWith({ where: { id: 'test-id', deleted_at: null }, include: {} });
    });

    it('should return null if not found', async () => {
      prisma.ward_round.findFirst.mockResolvedValue(null);
      const result = await wardRoundRepository.findById('non-existent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.ward_round.findFirst.mockRejectedValue(new Error('DB Error'));
      await expect(wardRoundRepository.findById('test-id')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find ward rounds with filters', async () => {
      const mockWardRounds = [{ id: '1' }, { id: '2' }];
      prisma.ward_round.findMany.mockResolvedValue(mockWardRounds);
      const result = await wardRoundRepository.findMany({ admission_id: 'test' }, 0, 10);
      expect(result).toEqual(mockWardRounds);
      expect(prisma.ward_round.findMany).toHaveBeenCalled();
    });

    it('should throw HttpError on error', async () => {
      prisma.ward_round.findMany.mockRejectedValue(new Error('DB Error'));
      await expect(wardRoundRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count ward rounds', async () => {
      prisma.ward_round.count.mockResolvedValue(5);
      const result = await wardRoundRepository.count({});
      expect(result).toBe(5);
    });
  });

  describe('create', () => {
    it('should create ward round', async () => {
      const data = { admission_id: 'a-id', notes: 'Patient stable' };
      const mockCreated = { id: 'new-id', ...data };
      prisma.ward_round.create.mockResolvedValue(mockCreated);
      const result = await wardRoundRepository.create(data);
      expect(result).toEqual(mockCreated);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = { code: 'P2003', meta: { field_name: 'admission_id' } };
      prisma.ward_round.create.mockRejectedValue(error);
      await expect(wardRoundRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update ward round', async () => {
      const mockUpdated = { id: 'test-id', notes: 'Updated notes' };
      prisma.ward_round.update.mockResolvedValue(mockUpdated);
      const result = await wardRoundRepository.update('test-id', { notes: 'Updated notes' });
      expect(result).toEqual(mockUpdated);
    });

    it('should throw HttpError if not found', async () => {
      const error = { code: 'P2025' };
      prisma.ward_round.update.mockRejectedValue(error);
      await expect(wardRoundRepository.update('non-existent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete ward round', async () => {
      const mockDeleted = { id: 'test-id', deleted_at: expect.any(Date) };
      prisma.ward_round.update.mockResolvedValue(mockDeleted);
      const result = await wardRoundRepository.softDelete('test-id');
      expect(result).toEqual(mockDeleted);
    });

    it('should throw HttpError if not found', async () => {
      const error = { code: 'P2025' };
      prisma.ward_round.update.mockRejectedValue(error);
      await expect(wardRoundRepository.softDelete('non-existent')).rejects.toThrow(HttpError);
    });
  });
});
