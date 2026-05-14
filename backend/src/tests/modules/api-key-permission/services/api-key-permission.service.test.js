// API Key Permission service tests
// Per testing.mdc: Mock all external dependencies

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/api-key-permission/api-key-permission.repository');
jest.mock('@lib/audit');

const apiKeyPermissionRepository = require('@repositories/api-key-permission/api-key-permission.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listApiKeyPermissions,
  getApiKeyPermissionById,
  createApiKeyPermission,
  updateApiKeyPermission,
  deleteApiKeyPermission
} = require('@services/api-key-permission/api-key-permission.service');

describe('API Key Permission Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listApiKeyPermissions', () => {
    it('should list API key permissions with default pagination', async () => {
      const mockApiKeyPermissions = [
        { id: 'akp-1', api_key_id: 'api-key-123', permission_id: 'perm-1' },
        { id: 'akp-2', api_key_id: 'api-key-123', permission_id: 'perm-2' }
      ];
      apiKeyPermissionRepository.findMany.mockResolvedValue(mockApiKeyPermissions);
      apiKeyPermissionRepository.count.mockResolvedValue(10);

      const result = await listApiKeyPermissions({}, 1, 20);

      expect(result.api_key_permissions).toEqual(mockApiKeyPermissions);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });
  });

  describe('getApiKeyPermissionById', () => {
    it('should get API key permission by ID', async () => {
      const mockApiKeyPermission = {
        id: 'akp-123',
        api_key_id: 'api-key-123',
        permission_id: 'perm-123'
      };
      apiKeyPermissionRepository.findById.mockResolvedValue(mockApiKeyPermission);

      const result = await getApiKeyPermissionById('akp-123');

      expect(result).toEqual(mockApiKeyPermission);
    });

    it('should throw HttpError when not found', async () => {
      apiKeyPermissionRepository.findById.mockResolvedValue(null);

      await expect(getApiKeyPermissionById('akp-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createApiKeyPermission', () => {
    it('should create API key permission', async () => {
      const newData = {
        api_key_id: 'api-key-123',
        permission_id: 'perm-123'
      };
      const created = { id: 'akp-123', ...newData };
      apiKeyPermissionRepository.create.mockResolvedValue(created);

      const result = await createApiKeyPermission(newData, 'user-123', '127.0.0.1');

      expect(result).toEqual(created);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateApiKeyPermission', () => {
    it('should update API key permission', async () => {
      const before = { id: 'akp-123', api_key_id: 'api-key-123', permission_id: 'perm-123' };
      const updated = { id: 'akp-123', api_key_id: 'api-key-123', permission_id: 'perm-456' };
      apiKeyPermissionRepository.findById.mockResolvedValue(before);
      apiKeyPermissionRepository.update.mockResolvedValue(updated);

      const result = await updateApiKeyPermission('akp-123', { permission_id: 'perm-456' }, 'user-123', '127.0.0.1');

      expect(result).toEqual(updated);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('deleteApiKeyPermission', () => {
    it('should soft delete API key permission', async () => {
      const before = { id: 'akp-123', api_key_id: 'api-key-123', permission_id: 'perm-123' };
      apiKeyPermissionRepository.findById.mockResolvedValue(before);
      apiKeyPermissionRepository.softDelete.mockResolvedValue();

      await deleteApiKeyPermission('akp-123', 'user-123', '127.0.0.1');

      expect(apiKeyPermissionRepository.softDelete).toHaveBeenCalledWith('akp-123');
      expect(createAuditLog).toHaveBeenCalled();
    });
  });
});
