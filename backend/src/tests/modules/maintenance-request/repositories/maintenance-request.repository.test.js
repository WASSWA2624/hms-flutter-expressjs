/**
 * Maintenance request repository tests
 *
 * @module tests/modules/maintenance-request/repositories
 * @description Tests for maintenance request repository data access layer
 */

const maintenanceRequestRepository = require('../../../../modules/maintenance-request/repositories/maintenance-request.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  maintenance_request: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Maintenance Request Repository', () => {
  const defaultIncludeMatcher = expect.objectContaining({
    facility: expect.any(Object),
    asset: expect.any(Object),
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find maintenance request by ID', async () => {
      const mockRequest = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        status: 'OPEN',
        description: 'Test request'
      };

      prisma.maintenance_request.findFirst.mockResolvedValue(mockRequest);

      const result = await maintenanceRequestRepository.findById(mockRequest.id);

      expect(result).toEqual(mockRequest);
      expect(prisma.maintenance_request.findFirst).toHaveBeenCalledWith({
        where: { id: mockRequest.id, deleted_at: null },
        include: defaultIncludeMatcher
      });
    });

    it('should return null when maintenance request not found', async () => {
      prisma.maintenance_request.findFirst.mockResolvedValue(null);

      const result = await maintenanceRequestRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.maintenance_request.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(maintenanceRequestRepository.findById('some-id')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find multiple maintenance requests with filters', async () => {
      const mockRequests = [
        { id: '1', status: 'OPEN' },
        { id: '2', status: 'IN_PROGRESS' }
      ];

      prisma.maintenance_request.findMany.mockResolvedValue(mockRequests);

      const filters = { status: 'OPEN' };
      const result = await maintenanceRequestRepository.findMany(filters, 0, 20);

      expect(result).toEqual(mockRequests);
      expect(prisma.maintenance_request.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: defaultIncludeMatcher
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.maintenance_request.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(maintenanceRequestRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count maintenance requests with filters', async () => {
      prisma.maintenance_request.count.mockResolvedValue(10);

      const filters = { status: 'OPEN' };
      const result = await maintenanceRequestRepository.count(filters);

      expect(result).toBe(10);
      expect(prisma.maintenance_request.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.maintenance_request.count.mockRejectedValue(new Error('DB Error'));

      await expect(maintenanceRequestRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new maintenance request', async () => {
      const mockData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174000',
        status: 'OPEN',
        description: 'New request'
      };

      const mockCreated = { id: '1', ...mockData };
      prisma.maintenance_request.create.mockResolvedValue(mockCreated);

      const result = await maintenanceRequestRepository.create(mockData);

      expect(result).toEqual(mockCreated);
      expect(prisma.maintenance_request.create).toHaveBeenCalledWith({
        data: mockData,
        include: defaultIncludeMatcher
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['field_name'] };

      prisma.maintenance_request.create.mockRejectedValue(error);

      await expect(maintenanceRequestRepository.create({})).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'facility_id' };

      prisma.maintenance_request.create.mockRejectedValue(error);

      await expect(maintenanceRequestRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update maintenance request', async () => {
      const mockUpdated = {
        id: '1',
        status: 'COMPLETED',
        description: 'Updated request'
      };

      prisma.maintenance_request.update.mockResolvedValue(mockUpdated);

      const result = await maintenanceRequestRepository.update('1', { status: 'COMPLETED' });

      expect(result).toEqual(mockUpdated);
      expect(prisma.maintenance_request.update).toHaveBeenCalledWith({
        where: { id: '1' },
        data: { status: 'COMPLETED' },
        include: defaultIncludeMatcher
      });
    });

    it('should throw HttpError when maintenance request not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';

      prisma.maintenance_request.update.mockRejectedValue(error);

      await expect(maintenanceRequestRepository.update('non-existent', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete maintenance request', async () => {
      const mockDeleted = { id: '1', deleted_at: new Date() };
      prisma.maintenance_request.update.mockResolvedValue(mockDeleted);

      const result = await maintenanceRequestRepository.softDelete('1');

      expect(result).toEqual(mockDeleted);
      expect(prisma.maintenance_request.update).toHaveBeenCalledWith({
        where: { id: '1' },
        data: { deleted_at: expect.any(Date) },
        include: defaultIncludeMatcher
      });
    });

    it('should throw HttpError when maintenance request not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';

      prisma.maintenance_request.update.mockRejectedValue(error);

      await expect(maintenanceRequestRepository.softDelete('non-existent')).rejects.toThrow(HttpError);
    });
  });
});
