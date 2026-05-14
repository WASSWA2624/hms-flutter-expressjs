/**
 * Transfer request repository tests
 *
 * @module tests/modules/transfer-request/repositories
 * @description Tests for transfer request repository operations
 * Per testing.mdc: Repository tests must mock Prisma client
 */

const transferRequestRepository = require('@repositories/transfer-request/transfer-request.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  transfer_request: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Transfer Request Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find transfer request by id', async () => {
      const mockTransferRequest = {
        id: '123',
        admission_id: 'adm-123',
        from_ward_id: 'ward-1',
        to_ward_id: 'ward-2',
        status: 'REQUESTED'
      };
      prisma.transfer_request.findFirst.mockResolvedValue(mockTransferRequest);

      const result = await transferRequestRepository.findById('123');
      expect(result).toEqual(mockTransferRequest);
      expect(prisma.transfer_request.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include: {}
      });
    });

    it('should return null if transfer request not found', async () => {
      prisma.transfer_request.findFirst.mockResolvedValue(null);

      const result = await transferRequestRepository.findById('nonexistent');
      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.transfer_request.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(transferRequestRepository.findById('123')).rejects.toThrow(HttpError);
    });

    it('should accept include parameter', async () => {
      const mockTransferRequest = { id: '123', admission_id: 'adm-123' };
      const include = { admission: true, from_ward: true, to_ward: true };
      prisma.transfer_request.findFirst.mockResolvedValue(mockTransferRequest);

      await transferRequestRepository.findById('123', include);
      expect(prisma.transfer_request.findFirst).toHaveBeenCalledWith({
        where: { id: '123', deleted_at: null },
        include
      });
    });
  });

  describe('findMany', () => {
    it('should find many transfer requests with pagination', async () => {
      const mockTransferRequests = [
        { id: '1', admission_id: 'adm-1', status: 'REQUESTED' },
        { id: '2', admission_id: 'adm-2', status: 'APPROVED' }
      ];
      prisma.transfer_request.findMany.mockResolvedValue(mockTransferRequests);

      const result = await transferRequestRepository.findMany({}, 0, 20);
      expect(result).toEqual(mockTransferRequests);
      expect(prisma.transfer_request.findMany).toHaveBeenCalled();
    });

    it('should apply filters correctly', async () => {
      const filters = { admission_id: 'adm-123', status: 'REQUESTED' };
      prisma.transfer_request.findMany.mockResolvedValue([]);

      await transferRequestRepository.findMany(filters, 0, 20);
      expect(prisma.transfer_request.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply custom orderBy', async () => {
      const orderBy = { requested_at: 'asc' };
      prisma.transfer_request.findMany.mockResolvedValue([]);

      await transferRequestRepository.findMany({}, 0, 20, orderBy);
      expect(prisma.transfer_request.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy,
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.transfer_request.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(transferRequestRepository.findMany({}, 0, 20)).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count transfer requests', async () => {
      prisma.transfer_request.count.mockResolvedValue(42);

      const result = await transferRequestRepository.count({});
      expect(result).toBe(42);
    });

    it('should count with filters', async () => {
      const filters = { status: 'REQUESTED' };
      prisma.transfer_request.count.mockResolvedValue(10);

      const result = await transferRequestRepository.count(filters);
      expect(result).toBe(10);
      expect(prisma.transfer_request.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.transfer_request.count.mockRejectedValue(new Error('DB Error'));

      await expect(transferRequestRepository.count({})).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create transfer request', async () => {
      const mockData = {
        admission_id: 'adm-123',
        from_ward_id: 'ward-1',
        to_ward_id: 'ward-2',
        status: 'REQUESTED'
      };
      const mockTransferRequest = { id: '456', ...mockData };
      prisma.transfer_request.create.mockResolvedValue(mockTransferRequest);

      const result = await transferRequestRepository.create(mockData);
      expect(result).toEqual(mockTransferRequest);
      expect(prisma.transfer_request.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['admission_id'] };
      prisma.transfer_request.create.mockRejectedValue(error);

      await expect(transferRequestRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'admission_id' };
      prisma.transfer_request.create.mockRejectedValue(error);

      await expect(transferRequestRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on general database error', async () => {
      prisma.transfer_request.create.mockRejectedValue(new Error('DB Error'));

      await expect(transferRequestRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update transfer request', async () => {
      const mockTransferRequest = { id: '123', status: 'APPROVED' };
      prisma.transfer_request.update.mockResolvedValue(mockTransferRequest);

      const result = await transferRequestRepository.update('123', { status: 'APPROVED' });
      expect(result).toEqual(mockTransferRequest);
      expect(prisma.transfer_request.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { status: 'APPROVED' }
      });
    });

    it('should throw HttpError if transfer request not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.transfer_request.update.mockRejectedValue(error);

      await expect(transferRequestRepository.update('nonexistent', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['admission_id'] };
      prisma.transfer_request.update.mockRejectedValue(error);

      await expect(transferRequestRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'to_ward_id' };
      prisma.transfer_request.update.mockRejectedValue(error);

      await expect(transferRequestRepository.update('123', {})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on general database error', async () => {
      prisma.transfer_request.update.mockRejectedValue(new Error('DB Error'));

      await expect(transferRequestRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete transfer request', async () => {
      const mockTransferRequest = { id: '123', deleted_at: new Date() };
      prisma.transfer_request.update.mockResolvedValue(mockTransferRequest);

      const result = await transferRequestRepository.softDelete('123');
      expect(result).toEqual(mockTransferRequest);
      expect(prisma.transfer_request.update).toHaveBeenCalledWith({
        where: { id: '123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if transfer request not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.transfer_request.update.mockRejectedValue(error);

      await expect(transferRequestRepository.softDelete('nonexistent')).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on general database error', async () => {
      prisma.transfer_request.update.mockRejectedValue(new Error('DB Error'));

      await expect(transferRequestRepository.softDelete('123')).rejects.toThrow(HttpError);
    });
  });
});
