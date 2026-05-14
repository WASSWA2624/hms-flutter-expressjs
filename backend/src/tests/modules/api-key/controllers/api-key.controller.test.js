/**
 * API Key controller tests
 *
 * @module tests/modules/api-key/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/api-key/api-key.service');
jest.mock('@lib/response');

const apiKeyService = require('@services/api-key/api-key.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listApiKeys,
  getApiKeyById,
  createApiKey,
  updateApiKey,
  deleteApiKey
} = require('@controllers/api-key/api-key.controller');

describe('API Key Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123'
      },
      ip: '192.168.1.1',
      get: jest.fn((header) => {
        if (header === 'user-agent') return 'Mozilla/5.0';
        return null;
      })
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listApiKeys', () => {
    it('should list API keys with default pagination', async () => {
      const mockResult = {
        api_keys: [
          { id: 'api-key-1', name: 'Production Key', tenant_id: 'tenant-123' },
          { id: 'api-key-2', name: 'Development Key', tenant_id: 'tenant-123' }
        ],
        pagination: {
          page: 1,
          limit: 20,
          total: 2,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      apiKeyService.listApiKeys.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listApiKeys(req, res);

      expect(apiKeyService.listApiKeys).toHaveBeenCalledWith(
        {},
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '192.168.1.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.api_key.list.success',
        mockResult.api_keys,
        mockResult.pagination
      );
    });

    it('should list API keys with filters', async () => {
      const mockResult = {
        api_keys: [{ id: 'api-key-1', name: 'Production Key' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      apiKeyService.listApiKeys.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        is_active: 'true',
        search: 'Production'
      };

      await listApiKeys(req, res);

      expect(apiKeyService.listApiKeys).toHaveBeenCalledWith(
        {
          tenant_id: 'tenant-123',
          user_id: 'user-123',
          is_active: 'true',
          search: 'Production'
        },
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '192.168.1.1'
      );
    });

    it('should list API keys with sorting', async () => {
      const mockResult = {
        api_keys: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      apiKeyService.listApiKeys.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'name',
        order: 'desc'
      };

      await listApiKeys(req, res);

      expect(apiKeyService.listApiKeys).toHaveBeenCalledWith(
        {},
        1,
        20,
        'name',
        'desc',
        'user-123',
        '192.168.1.1'
      );
    });

    it('should list API keys with custom pagination', async () => {
      const mockResult = {
        api_keys: [],
        pagination: {
          page: 3,
          limit: 50,
          total: 100,
          totalPages: 2,
          hasNextPage: false,
          hasPreviousPage: true
        }
      };
      apiKeyService.listApiKeys.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 3,
        limit: 50
      };

      await listApiKeys(req, res);

      expect(apiKeyService.listApiKeys).toHaveBeenCalledWith(
        {},
        3,
        50,
        undefined,
        'asc',
        'user-123',
        '192.168.1.1'
      );
    });
  });

  describe('getApiKeyById', () => {
    it('should get API key by ID', async () => {
      const mockApiKey = {
        id: 'api-key-123',
        name: 'Test Key',
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        is_active: true
      };
      apiKeyService.getApiKeyById.mockResolvedValue(mockApiKey);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'api-key-123' };

      await getApiKeyById(req, res);

      expect(apiKeyService.getApiKeyById).toHaveBeenCalledWith(
        'api-key-123',
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.api_key.get.success',
        mockApiKey
      );
    });

    it('should handle missing user in request', async () => {
      const mockApiKey = { id: 'api-key-123', name: 'Test Key' };
      apiKeyService.getApiKeyById.mockResolvedValue(mockApiKey);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.user = undefined;
      req.params = { id: 'api-key-123' };

      await getApiKeyById(req, res);

      expect(apiKeyService.getApiKeyById).toHaveBeenCalledWith(
        'api-key-123',
        undefined,
        '192.168.1.1'
      );
    });
  });

  describe('createApiKey', () => {
    it('should create API key', async () => {
      const newApiKeyData = {
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        name: 'New API Key',
        expires_at: '2027-12-31T23:59:59Z'
      };
      const createdApiKey = {
        id: 'api-key-123',
        ...newApiKeyData,
        api_key: 'plain-api-key-value',
        is_active: true,
        created_at: new Date()
      };
      apiKeyService.createApiKey.mockResolvedValue(createdApiKey);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = newApiKeyData;

      await createApiKey(req, res);

      expect(apiKeyService.createApiKey).toHaveBeenCalledWith(
        newApiKeyData,
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.api_key.create.success',
        createdApiKey
      );
    });

    it('should handle missing user in request', async () => {
      const newApiKeyData = { name: 'New Key' };
      const createdApiKey = {
        id: 'api-key-123',
        ...newApiKeyData,
        api_key: 'plain-key'
      };
      apiKeyService.createApiKey.mockResolvedValue(createdApiKey);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.user = undefined;
      req.body = newApiKeyData;

      await createApiKey(req, res);

      expect(apiKeyService.createApiKey).toHaveBeenCalledWith(
        newApiKeyData,
        undefined,
        '192.168.1.1'
      );
    });
  });

  describe('updateApiKey', () => {
    it('should update API key', async () => {
      const updateData = {
        name: 'Updated Key',
        is_active: false
      };
      const updatedApiKey = {
        id: 'api-key-123',
        ...updateData,
        tenant_id: 'tenant-123',
        user_id: 'user-123'
      };
      apiKeyService.updateApiKey.mockResolvedValue(updatedApiKey);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'api-key-123' };
      req.body = updateData;

      await updateApiKey(req, res);

      expect(apiKeyService.updateApiKey).toHaveBeenCalledWith(
        'api-key-123',
        updateData,
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.api_key.update.success',
        updatedApiKey
      );
    });

    it('should handle missing user in request', async () => {
      const updateData = { name: 'Updated Key' };
      const updatedApiKey = { id: 'api-key-123', ...updateData };
      apiKeyService.updateApiKey.mockResolvedValue(updatedApiKey);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.user = undefined;
      req.params = { id: 'api-key-123' };
      req.body = updateData;

      await updateApiKey(req, res);

      expect(apiKeyService.updateApiKey).toHaveBeenCalledWith(
        'api-key-123',
        updateData,
        undefined,
        '192.168.1.1'
      );
    });
  });

  describe('deleteApiKey', () => {
    it('should delete API key', async () => {
      apiKeyService.deleteApiKey.mockResolvedValue();
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'api-key-123' };

      await deleteApiKey(req, res);

      expect(apiKeyService.deleteApiKey).toHaveBeenCalledWith(
        'api-key-123',
        'user-123',
        '192.168.1.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });

    it('should handle missing user in request', async () => {
      apiKeyService.deleteApiKey.mockResolvedValue();
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.user = undefined;
      req.params = { id: 'api-key-123' };

      await deleteApiKey(req, res);

      expect(apiKeyService.deleteApiKey).toHaveBeenCalledWith(
        'api-key-123',
        undefined,
        '192.168.1.1'
      );
    });
  });
});
