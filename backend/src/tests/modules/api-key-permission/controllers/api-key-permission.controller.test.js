/**
 * API Key Permission controller tests
 *
 * @module tests/modules/api-key-permission/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/api-key-permission/api-key-permission.service');
jest.mock('@lib/response');

const apiKeyPermissionService = require('@services/api-key-permission/api-key-permission.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listApiKeyPermissions,
  getApiKeyPermissionById,
  createApiKeyPermission,
  updateApiKeyPermission,
  deleteApiKeyPermission
} = require('@controllers/api-key-permission/api-key-permission.controller');

describe('API Key Permission Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123', tenant_id: 'tenant-123' },
      ip: '192.168.1.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listApiKeyPermissions', () => {
    it('should list API key permissions', async () => {
      const mockResult = {
        api_key_permissions: [{ id: 'akp-1' }, { id: 'akp-2' }],
        pagination: { page: 1, limit: 20, total: 2 }
      };
      apiKeyPermissionService.listApiKeyPermissions.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };
      await listApiKeyPermissions(req, res);

      expect(apiKeyPermissionService.listApiKeyPermissions).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getApiKeyPermissionById', () => {
    it('should get API key permission by ID', async () => {
      const mockApiKeyPermission = { id: 'akp-123' };
      apiKeyPermissionService.getApiKeyPermissionById.mockResolvedValue(mockApiKeyPermission);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'akp-123' };
      await getApiKeyPermissionById(req, res);

      expect(apiKeyPermissionService.getApiKeyPermissionById).toHaveBeenCalledWith('akp-123', 'user-123', '192.168.1.1');
      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createApiKeyPermission', () => {
    it('should create API key permission', async () => {
      const newData = { api_key_id: 'api-key-123', permission_id: 'perm-123' };
      const created = { id: 'akp-123', ...newData };
      apiKeyPermissionService.createApiKeyPermission.mockResolvedValue(created);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = newData;
      await createApiKeyPermission(req, res);

      expect(apiKeyPermissionService.createApiKeyPermission).toHaveBeenCalled();
      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('updateApiKeyPermission', () => {
    it('should update API key permission', async () => {
      const updated = { id: 'akp-123', permission_id: 'perm-456' };
      apiKeyPermissionService.updateApiKeyPermission.mockResolvedValue(updated);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'akp-123' };
      req.body = { permission_id: 'perm-456' };
      await updateApiKeyPermission(req, res);

      expect(apiKeyPermissionService.updateApiKeyPermission).toHaveBeenCalled();
      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteApiKeyPermission', () => {
    it('should delete API key permission', async () => {
      apiKeyPermissionService.deleteApiKeyPermission.mockResolvedValue();
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'akp-123' };
      await deleteApiKeyPermission(req, res);

      expect(apiKeyPermissionService.deleteApiKeyPermission).toHaveBeenCalled();
      expect(sendNoContent).toHaveBeenCalled();
    });
  });
});
