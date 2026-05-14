/**
 * Vital Sign repository tests
 *
 * @module tests/modules/vital-sign/repositories
 * @description Tests for vital sign repository
 * Per testing.mdc: Repository tests with mocked Prisma client
 */

const vitalSignRepository = require('@repositories/vital-sign/vital-sign.repository');
const prisma = require('@prisma/client');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  vital_sign: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Vital Sign Repository', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find vital sign by ID', async () => {
      const mockVitalSign = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        encounter_id: '550e8400-e29b-41d4-a716-446655440001',
        vital_type: 'TEMPERATURE',
        value: '98.6',
        unit: 'F',
        deleted_at: null
      };

      prisma.vital_sign.findFirst.mockResolvedValue(mockVitalSign);

      const result = await vitalSignRepository.findById(mockVitalSign.id);
      expect(result).toEqual(mockVitalSign);
      expect(prisma.vital_sign.findFirst).toHaveBeenCalledWith({
        where: { id: mockVitalSign.id, deleted_at: null },
        include: {}
      });
    });

    it('should return null when vital sign not found', async () => {
      prisma.vital_sign.findFirst.mockResolvedValue(null);

      const result = await vitalSignRepository.findById('non-existent-id');
      expect(result).toBeNull();
    });
  });

  describe('findMany', () => {
    it('should find multiple vital signs', async () => {
      const mockVitalSigns = [
        { id: '1', vital_type: 'TEMPERATURE', value: '98.6', deleted_at: null },
        { id: '2', vital_type: 'HEART_RATE', value: '72', deleted_at: null }
      ];

      prisma.vital_sign.findMany.mockResolvedValue(mockVitalSigns);

      const result = await vitalSignRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockVitalSigns);
    });
  });

  describe('count', () => {
    it('should count vital signs', async () => {
      prisma.vital_sign.count.mockResolvedValue(10);

      const result = await vitalSignRepository.count({});
      expect(result).toBe(10);
    });
  });

  describe('create', () => {
    it('should create new vital sign', async () => {
      const newVitalSign = {
        encounter_id: '550e8400-e29b-41d4-a716-446655440001',
        vital_type: 'TEMPERATURE',
        value: '98.6',
        unit: 'F'
      };

      const createdVitalSign = { id: '550e8400-e29b-41d4-a716-446655440000', ...newVitalSign };

      prisma.vital_sign.create.mockResolvedValue(createdVitalSign);

      const result = await vitalSignRepository.create(newVitalSign);
      expect(result).toEqual(createdVitalSign);
    });
  });

  describe('update', () => {
    it('should update vital sign', async () => {
      const updateData = { value: '99.0' };
      const updatedVitalSign = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        vital_type: 'TEMPERATURE',
        value: '99.0',
        unit: 'F'
      };

      prisma.vital_sign.update.mockResolvedValue(updatedVitalSign);

      const result = await vitalSignRepository.update('550e8400-e29b-41d4-a716-446655440000', updateData);
      expect(result).toEqual(updatedVitalSign);
    });
  });

  describe('softDelete', () => {
    it('should soft delete vital sign', async () => {
      const id = '550e8400-e29b-41d4-a716-446655440000';
      const deletedVitalSign = { id, deleted_at: expect.any(Date) };

      prisma.vital_sign.update.mockResolvedValue(deletedVitalSign);

      const result = await vitalSignRepository.softDelete(id);
      expect(result.id).toBe(id);
      expect(result.deleted_at).toBeDefined();
    });
  });
});
