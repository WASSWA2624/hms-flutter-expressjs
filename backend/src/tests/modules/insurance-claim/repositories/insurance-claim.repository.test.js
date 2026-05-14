/**
 * Insurance claim repository tests
 *
 * @module tests/modules/insurance-claim/repositories
 * @description Tests for insurance claim repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const insuranceClaimRepository = require('@repositories/insurance-claim/insurance-claim.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  insurance_claim: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Insurance Claim Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find insurance claim by id', async () => {
      const mockClaim = { 
        id: '123', 
        coverage_plan_id: '456', 
        invoice_id: '789',
        status: 'SUBMITTED'
      };
      prisma.insurance_claim.findFirst.mockResolvedValue(mockClaim);

      const result = await insuranceClaimRepository.findById('123');
      expect(result).toEqual(mockClaim);
      expect(prisma.insurance_claim.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if insurance claim not found', async () => {
      prisma.insurance_claim.findFirst.mockResolvedValue(null);

      const result = await insuranceClaimRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.insurance_claim.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(insuranceClaimRepository.findById('123')).rejects.toThrow(HttpError);
    });

    it('should support include parameter', async () => {
      const mockClaim = { id: '123', coverage_plan_id: '456' };
      prisma.insurance_claim.findFirst.mockResolvedValue(mockClaim);

      await insuranceClaimRepository.findById('123', { coverage_plan: true });
      expect(prisma.insurance_claim.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: { coverage_plan: true }
      });
    });
  });

  describe('findMany', () => {
    it('should find many insurance claims with pagination', async () => {
      const mockClaims = [
        { id: '1', status: 'SUBMITTED' },
        { id: '2', status: 'APPROVED' }
      ];
      prisma.insurance_claim.findMany.mockResolvedValue(mockClaims);

      const result = await insuranceClaimRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockClaims);
      expect(prisma.insurance_claim.findMany).toHaveBeenCalled();
    });

    it('should apply filters correctly', async () => {
      const filters = { status: 'APPROVED', coverage_plan_id: '123' };
      prisma.insurance_claim.findMany.mockResolvedValue([]);

      await insuranceClaimRepository.findMany(filters, 0, 20);
      expect(prisma.insurance_claim.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.insurance_claim.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(insuranceClaimRepository.findMany({}, 0, 20)).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count insurance claims', async () => {
      prisma.insurance_claim.count.mockResolvedValue(42);

      const result = await insuranceClaimRepository.count({});
      expect(result).toBe(42);
    });

    it('should count with filters', async () => {
      const filters = { status: 'PAID' };
      prisma.insurance_claim.count.mockResolvedValue(10);

      const result = await insuranceClaimRepository.count(filters);
      expect(result).toBe(10);
      expect(prisma.insurance_claim.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.insurance_claim.count.mockRejectedValue(new Error('DB Error'));

      await expect(insuranceClaimRepository.count({})).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create insurance claim', async () => {
      const mockData = { 
        coverage_plan_id: '123', 
        invoice_id: '456',
        status: 'SUBMITTED'
      };
      const mockClaim = { id: '789', ...mockData };
      prisma.insurance_claim.create.mockResolvedValue(mockClaim);

      const result = await insuranceClaimRepository.create(mockData);
      expect(result).toEqual(mockClaim);
      expect(prisma.insurance_claim.create).toHaveBeenCalledWith({
        data: mockData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['invoice_id'] };
      prisma.insurance_claim.create.mockRejectedValue(error);

      await expect(insuranceClaimRepository.create({})).rejects.toThrow(HttpError);
      await expect(insuranceClaimRepository.create({})).rejects.toThrow(/unique_field/);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'coverage_plan_id' };
      prisma.insurance_claim.create.mockRejectedValue(error);

      await expect(insuranceClaimRepository.create({})).rejects.toThrow(HttpError);
      await expect(insuranceClaimRepository.create({})).rejects.toThrow(/foreign_key_field/);
    });

    it('should throw HttpError on generic database error', async () => {
      prisma.insurance_claim.create.mockRejectedValue(new Error('Generic DB error'));

      await expect(insuranceClaimRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update insurance claim', async () => {
      const mockClaim = { id: '123', status: 'APPROVED' };
      prisma.insurance_claim.update.mockResolvedValue(mockClaim);

      const result = await insuranceClaimRepository.update('123', { status: 'APPROVED' });
      expect(result).toEqual(mockClaim);
      expect(prisma.insurance_claim.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { status: 'APPROVED' }
      });
    });

    it('should throw HttpError if insurance claim not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.insurance_claim.update.mockRejectedValue(error);

      await expect(insuranceClaimRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
      await expect(insuranceClaimRepository.update('nonexistent', {})).rejects.toThrow(/not_found/);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['invoice_id'] };
      prisma.insurance_claim.update.mockRejectedValue(error);

      await expect(insuranceClaimRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'invoice_id' };
      prisma.insurance_claim.update.mockRejectedValue(error);

      await expect(insuranceClaimRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete insurance claim', async () => {
      const mockClaim = { id: '123', deleted_at: new Date() };
      prisma.insurance_claim.update.mockResolvedValue(mockClaim);

      const result = await insuranceClaimRepository.softDelete('123');
      expect(result).toEqual(mockClaim);
      expect(prisma.insurance_claim.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if insurance claim not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.insurance_claim.update.mockRejectedValue(error);

      await expect(insuranceClaimRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
      await expect(insuranceClaimRepository.softDelete('nonexistent')).rejects.toThrow(/not_found/);
    });

    it('should throw HttpError on database error', async () => {
      prisma.insurance_claim.update.mockRejectedValue(new Error('DB Error'));

      await expect(insuranceClaimRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
