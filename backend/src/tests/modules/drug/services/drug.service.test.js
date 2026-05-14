/**
 * Drug service tests
 *
 * @module tests/modules/drug/services
 * @description Tests for drug service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const drugService = require('@services/drug/drug.service');
const drugRepository = require('@repositories/drug/drug.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/identifiers/service-identifier-resolution');

// Mock dependencies
jest.mock('@repositories/drug/drug.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/service-identifier-resolution', () => ({
  resolveIdentifierForFilter: jest.fn(),
  resolveIdentifierForPayload: jest.fn(),
}));

const mockUser = {
  id: 'user-123',
  tenant_id: 'tenant-123',
  roles: ['PHARMACIST'],
};

const mockSuperAdminUser = {
  id: 'super-admin-1',
  roles: ['SUPER_ADMIN'],
};

const buildScopedDrug = (overrides = {}) => ({
  id: '123',
  tenant_id: 'tenant-123',
  name: 'Paracetamol',
  ...overrides,
});

describe('Drug Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
    resolveIdentifierForFilter.mockImplementation(async ({ value }) => value);
    resolveIdentifierForPayload.mockImplementation(async ({ value }) => value);
  });

  describe('listDrugs', () => {
    it('should list drugs with pagination', async () => {
      const mockDrugs = [{ id: '1', name: 'Paracetamol' }];
      drugRepository.findMany.mockResolvedValue(mockDrugs);
      drugRepository.count.mockResolvedValue(1);

      const result = await drugService.listDrugs(
        {},
        1,
        20,
        'created_at',
        'desc',
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(result.drugs).toEqual(mockDrugs);
      expect(result.pagination.total).toBe(1);
      expect(result.pagination.totalPages).toBe(1);
      expect(result.pagination.hasNextPage).toBe(false);
      expect(result.pagination.hasPreviousPage).toBe(false);
      expect(drugRepository.findMany).toHaveBeenCalled();
      expect(drugRepository.count).toHaveBeenCalled();
    });

    it('should handle search filters', async () => {
      drugRepository.findMany.mockResolvedValue([]);
      drugRepository.count.mockResolvedValue(0);

      await drugService.listDrugs(
        { search: 'Para' },
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(drugRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ OR: expect.any(Array) }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle name filter', async () => {
      drugRepository.findMany.mockResolvedValue([]);
      drugRepository.count.mockResolvedValue(0);

      await drugService.listDrugs(
        { name: 'Paracetamol' },
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(drugRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ name: { contains: 'Paracetamol' } }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle multiple filters', async () => {
      drugRepository.findMany.mockResolvedValue([]);
      drugRepository.count.mockResolvedValue(0);

      await drugService.listDrugs(
        { tenant_id: '123', form: 'Tablet', strength: '500mg' },
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(drugRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-123',
          form: { contains: 'Tablet' },
          strength: { contains: '500mg' }
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      drugRepository.findMany.mockResolvedValue([]);
      drugRepository.count.mockResolvedValue(50);

      const result = await drugService.listDrugs(
        {},
        2,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(result.pagination.totalPages).toBe(3);
      expect(result.pagination.hasNextPage).toBe(true);
      expect(result.pagination.hasPreviousPage).toBe(true);
    });

    it('resolves friendly tenant identifiers for super-admin list filters', async () => {
      drugRepository.findMany.mockResolvedValue([]);
      drugRepository.count.mockResolvedValue(0);
      resolveIdentifierForFilter.mockResolvedValue('tenant-uuid-1');

      await drugService.listDrugs(
        { tenant_id: 'TEN-ALPHA01' },
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress,
        mockSuperAdminUser
      );

      expect(resolveIdentifierForFilter).toHaveBeenCalledWith({
        value: 'TEN-ALPHA01',
        model: 'tenant',
        where: { deleted_at: null },
      });
      expect(drugRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ tenant_id: 'tenant-uuid-1' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('returns an empty list when a super-admin tenant filter cannot be resolved', async () => {
      resolveIdentifierForFilter.mockResolvedValue(null);

      const result = await drugService.listDrugs(
        { tenant_id: 'TEN-MISSING01' },
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress,
        mockSuperAdminUser
      );

      expect(result).toEqual({
        drugs: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false,
        },
      });
      expect(drugRepository.findMany).not.toHaveBeenCalled();
      expect(drugRepository.count).not.toHaveBeenCalled();
    });

    it('should handle repository errors', async () => {
      drugRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        drugService.listDrugs({}, 1, 20, null, 'asc', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getDrugById', () => {
    it('should get drug by id', async () => {
      const mockDrug = buildScopedDrug();
      drugRepository.findById.mockResolvedValue(mockDrug);

      const result = await drugService.getDrugById('123', mockUserId, mockIpAddress, mockUser);

      expect(result).toEqual(mockDrug);
      expect(drugRepository.findById).toHaveBeenCalledWith('123');
    });

    it('should throw HttpError if drug not found', async () => {
      drugRepository.findById.mockResolvedValue(null);

      await expect(
        drugService.getDrugById('nonexistent', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
      await expect(
        drugService.getDrugById('nonexistent', mockUserId, mockIpAddress, mockUser)
      ).rejects.toMatchObject({
        message: 'errors.drug.not_found',
        statusCode: 404
      });
    });

    it('should reject out-of-scope drugs', async () => {
      drugRepository.findById.mockResolvedValue(buildScopedDrug({ tenant_id: 'tenant-other' }));

      await expect(
        drugService.getDrugById('123', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });

    it('should handle repository errors', async () => {
      drugRepository.findById.mockRejectedValue(new Error('DB Error'));

      await expect(
        drugService.getDrugById('123', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createDrug', () => {
    it('should create drug and log audit', async () => {
      const mockData = { tenant_id: '123', name: 'Paracetamol', code: 'PARA500' };
      const mockDrug = { id: '456', ...mockData };
      drugRepository.create.mockResolvedValue(mockDrug);

      const result = await drugService.createDrug(mockData, mockUserId, mockIpAddress, mockUser);

      expect(result).toEqual(mockDrug);
      expect(drugRepository.create).toHaveBeenCalledWith({
        ...mockData,
        tenant_id: 'tenant-123',
      });
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        tenant_id: 'tenant-123',
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'drug',
        entity_id: '456',
        ip_address: mockIpAddress
      }));
    });

    it('should propagate HttpErrors from repository', async () => {
      const httpError = new HttpError('errors.database.unique_field', 409);
      drugRepository.create.mockRejectedValue(httpError);

      await expect(
        drugService.createDrug({}, mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });

    it('resolves friendly tenant identifiers for super-admin creates', async () => {
      const mockData = { tenant_id: 'TEN-ALPHA01', name: 'Paracetamol' };
      const mockDrug = { id: '456', tenant_id: 'tenant-uuid-1', name: 'Paracetamol' };
      resolveIdentifierForPayload.mockResolvedValue('tenant-uuid-1');
      drugRepository.create.mockResolvedValue(mockDrug);

      const result = await drugService.createDrug(
        mockData,
        mockUserId,
        mockIpAddress,
        mockSuperAdminUser
      );

      expect(result).toEqual(mockDrug);
      expect(resolveIdentifierForPayload).toHaveBeenCalledWith({
        value: 'TEN-ALPHA01',
        field: 'tenant_id',
        model: 'tenant',
        where: { deleted_at: null },
      });
      expect(drugRepository.create).toHaveBeenCalledWith({
        tenant_id: 'tenant-uuid-1',
        name: 'Paracetamol',
      });
    });

    it('should handle unexpected errors', async () => {
      drugRepository.create.mockRejectedValue(new Error('Unexpected error'));

      await expect(
        drugService.createDrug({}, mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('updateDrug', () => {
    it('should update drug and log audit', async () => {
      const mockBefore = buildScopedDrug();
      const mockAfter = { id: '123', name: 'Paracetamol Updated' };
      drugRepository.findById.mockResolvedValue(mockBefore);
      drugRepository.update.mockResolvedValue(mockAfter);

      const result = await drugService.updateDrug(
        '123',
        { name: 'Paracetamol Updated' },
        mockUserId,
        mockIpAddress,
        mockUser
      );

      expect(result).toEqual(mockAfter);
      expect(drugRepository.update).toHaveBeenCalledWith('123', {
        name: 'Paracetamol Updated',
        tenant_id: 'tenant-123',
      });
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        tenant_id: 'tenant-123',
        user_id: mockUserId,
        action: 'UPDATE',
        entity: 'drug',
        entity_id: '123',
        diff: { before: mockBefore, after: mockAfter },
        ip_address: mockIpAddress
      }));
    });

    it('should throw HttpError if drug not found', async () => {
      drugRepository.findById.mockResolvedValue(null);

      await expect(
        drugService.updateDrug('nonexistent', {}, mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
      await expect(
        drugService.updateDrug('nonexistent', {}, mockUserId, mockIpAddress, mockUser)
      ).rejects.toMatchObject({
        message: 'errors.drug.not_found',
        statusCode: 404
      });
    });

    it('should propagate HttpErrors from repository', async () => {
      drugRepository.findById.mockResolvedValue(buildScopedDrug());
      const httpError = new HttpError('errors.database.unique_field', 409);
      drugRepository.update.mockRejectedValue(httpError);

      await expect(
        drugService.updateDrug('123', {}, mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteDrug', () => {
    it('should soft delete drug and log audit', async () => {
      const mockBefore = buildScopedDrug();
      drugRepository.findById.mockResolvedValue(mockBefore);
      drugRepository.softDelete.mockResolvedValue({ id: '123', deleted_at: new Date() });

      await drugService.deleteDrug('123', mockUserId, mockIpAddress, mockUser);

      expect(drugRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        tenant_id: 'tenant-123',
        user_id: mockUserId,
        action: 'DELETE',
        entity: 'drug',
        entity_id: '123',
        diff: { before: mockBefore },
        ip_address: mockIpAddress
      }));
    });

    it('should throw HttpError if drug not found', async () => {
      drugRepository.findById.mockResolvedValue(null);

      await expect(
        drugService.deleteDrug('nonexistent', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
      await expect(
        drugService.deleteDrug('nonexistent', mockUserId, mockIpAddress, mockUser)
      ).rejects.toMatchObject({
        message: 'errors.drug.not_found',
        statusCode: 404
      });
    });

    it('should propagate HttpErrors from repository', async () => {
      drugRepository.findById.mockResolvedValue(buildScopedDrug());
      const httpError = new HttpError('errors.database.unexpected', 500);
      drugRepository.softDelete.mockRejectedValue(httpError);

      await expect(
        drugService.deleteDrug('123', mockUserId, mockIpAddress, mockUser)
      ).rejects.toThrow(HttpError);
    });
  });
});
