/**
 * Integration repository tests
 *
 * @module tests/modules/integration/repositories
 * @description Tests for integration repository functions
 */

const integrationRepository = require('@repositories/integration/integration.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  integration: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Integration Repository', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find integration by ID', async () => {
      const mockIntegration = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Integration',
        integration_type: 'HL7',
        status: 'ACTIVE'
      };

      prisma.integration.findFirst.mockResolvedValue(mockIntegration);

      const result = await integrationRepository.findById(mockIntegration.id);

      expect(result).toEqual(mockIntegration);
      expect(prisma.integration.findFirst).toHaveBeenCalledWith({
        where: {
          id: mockIntegration.id,
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if integration not found', async () => {
      prisma.integration.findFirst.mockResolvedValue(null);

      const result = await integrationRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.integration.findFirst.mockRejectedValue(new Error('Database error'));

      await expect(integrationRepository.findById('some-id'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many integrations with filters', async () => {
      const mockIntegrations = [
        { id: '1', name: 'Integration 1', integration_type: 'HL7', status: 'ACTIVE' },
        { id: '2', name: 'Integration 2', integration_type: 'FHIR', status: 'INACTIVE' }
      ];

      prisma.integration.findMany.mockResolvedValue(mockIntegrations);

      const filters = { tenant_id: 'tenant-123' };
      const result = await integrationRepository.findMany(filters, 0, 20);

      expect(result).toEqual(mockIntegrations);
      expect(prisma.integration.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.integration.findMany.mockRejectedValue(new Error('Database error'));

      await expect(integrationRepository.findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count integrations with filters', async () => {
      prisma.integration.count.mockResolvedValue(10);

      const filters = { status: 'ACTIVE' };
      const result = await integrationRepository.count(filters);

      expect(result).toBe(10);
      expect(prisma.integration.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          ...filters
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.integration.count.mockRejectedValue(new Error('Database error'));

      await expect(integrationRepository.count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new integration', async () => {
      const mockData = {
        tenant_id: 'tenant-123',
        integration_type: 'HL7',
        status: 'ACTIVE',
        name: 'New Integration'
      };

      const mockCreated = { id: 'new-id', ...mockData };
      prisma.integration.create.mockResolvedValue(mockCreated);

      const result = await integrationRepository.create(mockData);

      expect(result).toEqual(mockCreated);
      expect(prisma.integration.create).toHaveBeenCalledWith({ data: mockData });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['name'] };

      prisma.integration.create.mockRejectedValue(error);

      await expect(integrationRepository.create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };

      prisma.integration.create.mockRejectedValue(error);

      await expect(integrationRepository.create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update integration', async () => {
      const mockData = { name: 'Updated Integration' };
      const mockUpdated = { id: 'integration-id', ...mockData };

      prisma.integration.update.mockResolvedValue(mockUpdated);

      const result = await integrationRepository.update('integration-id', mockData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.integration.update).toHaveBeenCalledWith({
        where: { id: 'integration-id' },
        data: mockData
      });
    });

    it('should throw HttpError when integration not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.integration.update.mockRejectedValue(error);

      await expect(integrationRepository.update('non-existent-id', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['name'] };

      prisma.integration.update.mockRejectedValue(error);

      await expect(integrationRepository.update('integration-id', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete integration', async () => {
      const mockDeleted = {
        id: 'integration-id',
        deleted_at: expect.any(Date)
      };

      prisma.integration.update.mockResolvedValue(mockDeleted);

      const result = await integrationRepository.softDelete('integration-id');

      expect(result).toEqual(mockDeleted);
      expect(prisma.integration.update).toHaveBeenCalledWith({
        where: { id: 'integration-id' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when integration not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.integration.update.mockRejectedValue(error);

      await expect(integrationRepository.softDelete('non-existent-id'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
