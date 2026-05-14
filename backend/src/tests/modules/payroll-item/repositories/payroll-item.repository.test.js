/**
 * Payroll item repository tests
 *
 * @module tests/modules/payroll-item/repositories
 * @description Tests for payroll item repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const payrollItemRepository = require('@repositories/payroll-item/payroll-item.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  payroll_item: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Payroll Item Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find payroll item by id', async () => {
      const mockPayrollItem = { 
        id: '123', 
        payroll_run_id: 'run-123', 
        staff_profile_id: 'staff-123',
        amount: 5000.00,
        currency: 'USD'
      };
      prisma.payroll_item.findFirst.mockResolvedValue(mockPayrollItem);

      const result = await payrollItemRepository.findById('123');
      expect(result).toEqual(mockPayrollItem);
      expect(prisma.payroll_item.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if payroll item not found', async () => {
      prisma.payroll_item.findFirst.mockResolvedValue(null);

      const result = await payrollItemRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.payroll_item.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(payrollItemRepository.findById('123')).rejects.toThrow(HttpError);
    });

    it('should support include parameter', async () => {
      const mockPayrollItem = { id: '123', payroll_run: {}, staff_profile: {} };
      prisma.payroll_item.findFirst.mockResolvedValue(mockPayrollItem);

      const include = { payroll_run: true, staff_profile: true };
      const result = await payrollItemRepository.findById('123', include);
      expect(result).toEqual(mockPayrollItem);
      expect(prisma.payroll_item.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include
      });
    });
  });

  describe('findMany', () => {
    it('should find many payroll items with pagination', async () => {
      const mockPayrollItems = [
        { id: '1', amount: 5000 },
        { id: '2', amount: 6000 }
      ];
      prisma.payroll_item.findMany.mockResolvedValue(mockPayrollItems);

      const result = await payrollItemRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockPayrollItems);
      expect(prisma.payroll_item.findMany).toHaveBeenCalled();
    });

    it('should apply filters', async () => {
      const filters = { payroll_run_id: '123', currency: 'USD' };
      prisma.payroll_item.findMany.mockResolvedValue([]);

      await payrollItemRepository.findMany(filters, 0, 20);
      expect(prisma.payroll_item.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply custom ordering', async () => {
      prisma.payroll_item.findMany.mockResolvedValue([]);

      await payrollItemRepository.findMany({}, 0, 20, { amount: 'desc' });
      expect(prisma.payroll_item.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { amount: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.payroll_item.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(payrollItemRepository.findMany({}, 0, 20)).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count payroll items', async () => {
      prisma.payroll_item.count.mockResolvedValue(100);

      const result = await payrollItemRepository.count({});
      expect(result).toBe(100);
    });

    it('should apply filters', async () => {
      const filters = { payroll_run_id: '123', staff_profile_id: 'staff-123' };
      prisma.payroll_item.count.mockResolvedValue(5);

      await payrollItemRepository.count(filters);
      expect(prisma.payroll_item.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.payroll_item.count.mockRejectedValue(new Error('DB Error'));

      await expect(payrollItemRepository.count({})).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create payroll item', async () => {
      const mockData = { 
        payroll_run_id: '123', 
        staff_profile_id: 'staff-123',
        amount: 5000.00,
        currency: 'USD'
      };
      const mockPayrollItem = { id: '456', ...mockData };
      prisma.payroll_item.create.mockResolvedValue(mockPayrollItem);

      const result = await payrollItemRepository.create(mockData);
      expect(result).toEqual(mockPayrollItem);
      expect(prisma.payroll_item.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const mockData = { payroll_run_id: '123', staff_profile_id: 'staff-123', amount: 5000, currency: 'USD' };
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['payroll_run_id'] };
      prisma.payroll_item.create.mockRejectedValue(error);

      await expect(payrollItemRepository.create(mockData)).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const mockData = { payroll_run_id: '123', staff_profile_id: 'staff-123', amount: 5000, currency: 'USD' };
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'payroll_run_id' };
      prisma.payroll_item.create.mockRejectedValue(error);

      await expect(payrollItemRepository.create(mockData)).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      const mockData = { payroll_run_id: '123', staff_profile_id: 'staff-123', amount: 5000, currency: 'USD' };
      prisma.payroll_item.create.mockRejectedValue(new Error('DB Error'));

      await expect(payrollItemRepository.create(mockData)).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update payroll item', async () => {
      const mockData = { amount: 5500.00 };
      const mockPayrollItem = { id: '123', ...mockData };
      prisma.payroll_item.update.mockResolvedValue(mockPayrollItem);

      const result = await payrollItemRepository.update('123', mockData);
      expect(result).toEqual(mockPayrollItem);
      expect(prisma.payroll_item.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: mockData
      });
    });

    it('should throw HttpError on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.payroll_item.update.mockRejectedValue(error);

      await expect(payrollItemRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['payroll_run_id'] };
      prisma.payroll_item.update.mockRejectedValue(error);

      await expect(payrollItemRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'staff_profile_id' };
      prisma.payroll_item.update.mockRejectedValue(error);

      await expect(payrollItemRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.payroll_item.update.mockRejectedValue(new Error('DB Error'));

      await expect(payrollItemRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete payroll item', async () => {
      const mockPayrollItem = { id: '123', deleted_at: new Date() };
      prisma.payroll_item.update.mockResolvedValue(mockPayrollItem);

      const result = await payrollItemRepository.softDelete('123');
      expect(result).toEqual(mockPayrollItem);
      expect(prisma.payroll_item.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.payroll_item.update.mockRejectedValue(error);

      await expect(payrollItemRepository.softDelete('123')).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unexpected database error', async () => {
      prisma.payroll_item.update.mockRejectedValue(new Error('DB Error'));

      await expect(payrollItemRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
