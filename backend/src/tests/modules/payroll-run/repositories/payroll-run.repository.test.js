/**
 * Payroll run repository tests
 *
 * @module tests/modules/payroll-run/repositories
 * @description Tests for payroll run repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const payrollRunRepository = require('@repositories/payroll-run/payroll-run.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  payroll_run: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Payroll Run Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find payroll run by id', async () => {
      const mockPayrollRun = { 
        id: '123', 
        tenant_id: 'tenant-123', 
        period_start: new Date('2024-01-01'),
        period_end: new Date('2024-01-31'),
        status: 'DRAFT' 
      };
      prisma.payroll_run.findFirst.mockResolvedValue(mockPayrollRun);

      const result = await payrollRunRepository.findById('123');
      expect(result).toEqual(mockPayrollRun);
      expect(prisma.payroll_run.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if payroll run not found', async () => {
      prisma.payroll_run.findFirst.mockResolvedValue(null);

      const result = await payrollRunRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.payroll_run.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(payrollRunRepository.findById('123')).rejects.toThrow(HttpError);
    });

    it('should support include parameter', async () => {
      const mockPayrollRun = { id: '123', items: [] };
      prisma.payroll_run.findFirst.mockResolvedValue(mockPayrollRun);

      const include = { items: true };
      const result = await payrollRunRepository.findById('123', include);
      expect(result).toEqual(mockPayrollRun);
      expect(prisma.payroll_run.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include
      });
    });
  });

  describe('findMany', () => {
    it('should find many payroll runs with pagination', async () => {
      const mockPayrollRuns = [
        { id: '1', status: 'DRAFT' },
        { id: '2', status: 'PROCESSED' }
      ];
      prisma.payroll_run.findMany.mockResolvedValue(mockPayrollRuns);

      const result = await payrollRunRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockPayrollRuns);
      expect(prisma.payroll_run.findMany).toHaveBeenCalled();
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '123', status: 'PROCESSED' };
      prisma.payroll_run.findMany.mockResolvedValue([]);

      await payrollRunRepository.findMany(filters, 0, 20);
      expect(prisma.payroll_run.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply custom ordering', async () => {
      prisma.payroll_run.findMany.mockResolvedValue([]);

      await payrollRunRepository.findMany({}, 0, 20, { period_start: 'asc' });
      expect(prisma.payroll_run.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { period_start: 'asc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.payroll_run.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(payrollRunRepository.findMany({}, 0, 20)).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count payroll runs', async () => {
      prisma.payroll_run.count.mockResolvedValue(42);

      const result = await payrollRunRepository.count({});
      expect(result).toBe(42);
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '123', status: 'PAID' };
      prisma.payroll_run.count.mockResolvedValue(10);

      await payrollRunRepository.count(filters);
      expect(prisma.payroll_run.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.payroll_run.count.mockRejectedValue(new Error('DB Error'));

      await expect(payrollRunRepository.count({})).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create payroll run', async () => {
      const mockData = { 
        tenant_id: '123', 
        period_start: new Date('2024-01-01'),
        period_end: new Date('2024-01-31'),
        status: 'DRAFT'
      };
      const mockPayrollRun = { id: '456', ...mockData };
      prisma.payroll_run.create.mockResolvedValue(mockPayrollRun);

      const result = await payrollRunRepository.create(mockData);
      expect(result).toEqual(mockPayrollRun);
      expect(prisma.payroll_run.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const mockData = { tenant_id: '123', period_start: new Date(), period_end: new Date() };
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['tenant_id'] };
      prisma.payroll_run.create.mockRejectedValue(error);

      await expect(payrollRunRepository.create(mockData)).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const mockData = { tenant_id: '123', period_start: new Date(), period_end: new Date() };
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.payroll_run.create.mockRejectedValue(error);

      await expect(payrollRunRepository.create(mockData)).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      const mockData = { tenant_id: '123', period_start: new Date(), period_end: new Date() };
      prisma.payroll_run.create.mockRejectedValue(new Error('DB Error'));

      await expect(payrollRunRepository.create(mockData)).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update payroll run', async () => {
      const mockData = { status: 'PROCESSED' };
      const mockPayrollRun = { id: '123', ...mockData };
      prisma.payroll_run.update.mockResolvedValue(mockPayrollRun);

      const result = await payrollRunRepository.update('123', mockData);
      expect(result).toEqual(mockPayrollRun);
      expect(prisma.payroll_run.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: mockData
      });
    });

    it('should throw HttpError on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.payroll_run.update.mockRejectedValue(error);

      await expect(payrollRunRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['tenant_id'] };
      prisma.payroll_run.update.mockRejectedValue(error);

      await expect(payrollRunRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.payroll_run.update.mockRejectedValue(error);

      await expect(payrollRunRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.payroll_run.update.mockRejectedValue(new Error('DB Error'));

      await expect(payrollRunRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete payroll run', async () => {
      const mockPayrollRun = { id: '123', deleted_at: new Date() };
      prisma.payroll_run.update.mockResolvedValue(mockPayrollRun);

      const result = await payrollRunRepository.softDelete('123');
      expect(result).toEqual(mockPayrollRun);
      expect(prisma.payroll_run.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.payroll_run.update.mockRejectedValue(error);

      await expect(payrollRunRepository.softDelete('123')).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.payroll_run.update.mockRejectedValue(new Error('DB Error'));

      await expect(payrollRunRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
