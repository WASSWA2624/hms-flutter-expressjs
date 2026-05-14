/**
 * API Key service tests
 *
 * @module tests/modules/api-key/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/api-key/api-key.repository');
jest.mock('@lib/audit');
jest.mock('@lib/crypto');

const apiKeyRepository = require('@repositories/api-key/api-key.repository');
const { createAuditLog } = require('@lib/audit');
const { hashApiKey } = require('@lib/crypto');
const {
  listApiKeys,
  getApiKeyById,
  createApiKey,
  updateApiKey,
  deleteApiKey
} = require('@services/api-key/api-key.service');

describe('API Key Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    apiKeyRepository.createPublicId.mockReturnValue('KEY-TEST1234');
  });

  describe('listApiKeys', () => {
    it('should list API keys with default pagination', async () => {
      const mockApiKeys = [
        { id: 'api-key-1', name: 'Production Key', key_hash: 'hash1', tenant_id: 'tenant-123', is_active: true },
        { id: 'api-key-2', name: 'Development Key', key_hash: 'hash2', tenant_id: 'tenant-123', is_active: true }
      ];
      apiKeyRepository.findMany.mockResolvedValue(mockApiKeys);
      apiKeyRepository.count.mockResolvedValue(10);

      const result = await listApiKeys({}, 1, 20);

      expect(result.api_keys).toHaveLength(2);
      expect(result.api_keys[0]).not.toHaveProperty('key_hash');
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
      expect(apiKeyRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by tenant_id', async () => {
      const mockApiKeys = [{ id: 'api-key-1', name: 'Test Key', key_hash: 'hash1' }];
      apiKeyRepository.findMany.mockResolvedValue(mockApiKeys);
      apiKeyRepository.count.mockResolvedValue(1);

      const result = await listApiKeys({ tenant_id: 'tenant-123' }, 1, 20);

      expect(result.api_keys).toHaveLength(1);
      expect(apiKeyRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by user_id', async () => {
      const mockApiKeys = [{ id: 'api-key-1', name: 'Test Key', key_hash: 'hash1' }];
      apiKeyRepository.findMany.mockResolvedValue(mockApiKeys);
      apiKeyRepository.count.mockResolvedValue(1);

      const result = await listApiKeys({ user_id: 'user-123' }, 1, 20);

      expect(result.api_keys).toHaveLength(1);
      expect(apiKeyRepository.findMany).toHaveBeenCalledWith(
        { user_id: 'user-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_active', async () => {
      const mockApiKeys = [{ id: 'api-key-1', name: 'Test Key', key_hash: 'hash1', is_active: true }];
      apiKeyRepository.findMany.mockResolvedValue(mockApiKeys);
      apiKeyRepository.count.mockResolvedValue(1);

      const result = await listApiKeys({ is_active: true }, 1, 20);

      expect(result.api_keys).toHaveLength(1);
      expect(apiKeyRepository.findMany).toHaveBeenCalledWith(
        { is_active: true },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by search (name contains)', async () => {
      const mockApiKeys = [{ id: 'api-key-1', name: 'Production Key', key_hash: 'hash1' }];
      apiKeyRepository.findMany.mockResolvedValue(mockApiKeys);
      apiKeyRepository.count.mockResolvedValue(1);

      const result = await listApiKeys({ search: 'Production' }, 1, 20);

      expect(result.api_keys).toHaveLength(1);
      expect(apiKeyRepository.findMany).toHaveBeenCalledWith(
        { name: { contains: 'Production' } },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle custom pagination', async () => {
      const mockApiKeys = [];
      apiKeyRepository.findMany.mockResolvedValue(mockApiKeys);
      apiKeyRepository.count.mockResolvedValue(50);

      const result = await listApiKeys({}, 3, 10);

      expect(result.pagination).toEqual({
        page: 3,
        limit: 10,
        total: 50,
        totalPages: 5,
        hasNextPage: true,
        hasPreviousPage: true
      });
      expect(apiKeyRepository.findMany).toHaveBeenCalledWith(
        {},
        20,
        10,
        { created_at: 'desc' }
      );
    });

    it('should handle custom sort', async () => {
      const mockApiKeys = [];
      apiKeyRepository.findMany.mockResolvedValue(mockApiKeys);
      apiKeyRepository.count.mockResolvedValue(0);

      await listApiKeys({}, 1, 20, 'name', 'asc');

      expect(apiKeyRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { name: 'asc' }
      );
    });

    it('should throw HttpError on repository error', async () => {
      apiKeyRepository.findMany.mockRejectedValue(new Error('DB error'));

      await expect(listApiKeys({}, 1, 20))
        .rejects
        .toThrow(HttpError);
    });

    it('should remove key_hash from all API keys in response', async () => {
      const mockApiKeys = [
        { id: 'api-key-1', name: 'Key 1', key_hash: 'secret-hash-1' },
        { id: 'api-key-2', name: 'Key 2', key_hash: 'secret-hash-2' }
      ];
      apiKeyRepository.findMany.mockResolvedValue(mockApiKeys);
      apiKeyRepository.count.mockResolvedValue(2);

      const result = await listApiKeys({}, 1, 20);

      result.api_keys.forEach(key => {
        expect(key).not.toHaveProperty('key_hash');
      });
    });
  });

  describe('getApiKeyById', () => {
    it('should get API key by ID', async () => {
      const mockApiKey = {
        id: 'api-key-123',
        name: 'Test Key',
        key_hash: 'hashed-key',
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        is_active: true
      };
      apiKeyRepository.findById.mockResolvedValue(mockApiKey);

      const result = await getApiKeyById('api-key-123');

      expect(result.id).toBe('api-key-123');
      expect(result).not.toHaveProperty('key_hash');
      expect(apiKeyRepository.findById).toHaveBeenCalledWith('api-key-123');
    });

    it('should throw HttpError when API key not found', async () => {
      apiKeyRepository.findById.mockResolvedValue(null);

      await expect(getApiKeyById('api-key-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      apiKeyRepository.findById.mockRejectedValue(new Error('DB error'));

      await expect(getApiKeyById('api-key-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createApiKey', () => {
    it('should create API key with hashed key', async () => {
      const newApiKeyData = {
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        name: 'New API Key',
        expires_at: new Date('2027-12-31')
      };
      const hashedKey = 'hashed-api-key';
      const createdApiKey = {
        id: 'api-key-123',
        ...newApiKeyData,
        human_friendly_id: 'KEY-TEST1234',
        key_hash: hashedKey,
        is_active: true,
        created_at: new Date(),
        updated_at: new Date()
      };

      hashApiKey.mockResolvedValue(hashedKey);
      apiKeyRepository.create.mockResolvedValue(createdApiKey);

      const result = await createApiKey(newApiKeyData, 'user-123', '127.0.0.1');

      expect(result.id).toBe('api-key-123');
      expect(result).toHaveProperty('api_key');
      expect(typeof result.api_key).toBe('string');
      expect(result.api_key).toMatch(/^KEY-TEST1234\.[a-f0-9]{64}$/);
      expect(result).not.toHaveProperty('key_hash');
      expect(hashApiKey).toHaveBeenCalledWith(result.api_key);
      expect(apiKeyRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          ...newApiKeyData,
          human_friendly_id: 'KEY-TEST1234',
          key_hash: hashedKey,
          is_active: true
        })
      );
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-123',
          action: 'CREATE',
          entity: 'api_key',
          entity_id: 'api-key-123',
          ip_address: '127.0.0.1'
        })
      );
    });

    it('should generate unique API key on each creation', async () => {
      const newApiKeyData = {
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        name: 'API Key'
      };
      const createdApiKey = {
        id: 'api-key-123',
        ...newApiKeyData,
        human_friendly_id: 'KEY-TEST1234',
        key_hash: 'hash',
        is_active: true
      };

      hashApiKey.mockResolvedValue('hash');
      apiKeyRepository.create.mockResolvedValue(createdApiKey);

      const result1 = await createApiKey(newApiKeyData, 'user-123', '127.0.0.1');
      const result2 = await createApiKey(newApiKeyData, 'user-123', '127.0.0.1');

      expect(result1.api_key).not.toBe(result2.api_key);
    });

    it('should throw HttpError on repository error', async () => {
      hashApiKey.mockResolvedValue('hash');
      apiKeyRepository.create.mockRejectedValue(new Error('DB error'));

      await expect(createApiKey({}, 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should redact key_hash in audit log', async () => {
      const newApiKeyData = {
        tenant_id: 'tenant-123',
        user_id: 'user-123',
        name: 'API Key'
      };
      const createdApiKey = {
        id: 'api-key-123',
        ...newApiKeyData,
        human_friendly_id: 'KEY-TEST1234',
        key_hash: 'secret-hash',
        is_active: true
      };

      hashApiKey.mockResolvedValue('secret-hash');
      apiKeyRepository.create.mockResolvedValue(createdApiKey);

      await createApiKey(newApiKeyData, 'user-123', '127.0.0.1');

      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          diff: expect.objectContaining({
            after: expect.objectContaining({
              key_hash: '[REDACTED]'
            })
          })
        })
      );
    });
  });

  describe('updateApiKey', () => {
    it('should update API key', async () => {
      const updateData = {
        name: 'Updated Key',
        is_active: false
      };
      const beforeApiKey = {
        id: 'api-key-123',
        name: 'Old Key',
        key_hash: 'hash',
        is_active: true
      };
      const updatedApiKey = {
        id: 'api-key-123',
        ...updateData,
        key_hash: 'hash'
      };

      apiKeyRepository.findById.mockResolvedValue(beforeApiKey);
      apiKeyRepository.update.mockResolvedValue(updatedApiKey);

      const result = await updateApiKey('api-key-123', updateData, 'user-123', '127.0.0.1');

      expect(result.name).toBe('Updated Key');
      expect(result).not.toHaveProperty('key_hash');
      expect(apiKeyRepository.update).toHaveBeenCalledWith('api-key-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-123',
          action: 'UPDATE',
          entity: 'api_key',
          entity_id: 'api-key-123',
          ip_address: '127.0.0.1'
        })
      );
    });

    it('should throw HttpError when API key not found', async () => {
      apiKeyRepository.findById.mockResolvedValue(null);

      await expect(updateApiKey('api-key-123', {}, 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      apiKeyRepository.findById.mockResolvedValue({ id: 'api-key-123' });
      apiKeyRepository.update.mockRejectedValue(new Error('DB error'));

      await expect(updateApiKey('api-key-123', {}, 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should redact key_hash in audit log', async () => {
      const beforeApiKey = {
        id: 'api-key-123',
        name: 'Old Key',
        key_hash: 'secret-hash-1'
      };
      const updatedApiKey = {
        id: 'api-key-123',
        name: 'New Key',
        key_hash: 'secret-hash-2'
      };

      apiKeyRepository.findById.mockResolvedValue(beforeApiKey);
      apiKeyRepository.update.mockResolvedValue(updatedApiKey);

      await updateApiKey('api-key-123', { name: 'New Key' }, 'user-123', '127.0.0.1');

      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          diff: {
            before: expect.objectContaining({ key_hash: '[REDACTED]' }),
            after: expect.objectContaining({ key_hash: '[REDACTED]' })
          }
        })
      );
    });
  });

  describe('deleteApiKey', () => {
    it('should soft delete API key', async () => {
      const apiKey = {
        id: 'api-key-123',
        name: 'Test Key',
        key_hash: 'hash'
      };

      apiKeyRepository.findById.mockResolvedValue(apiKey);
      apiKeyRepository.softDelete.mockResolvedValue();

      await deleteApiKey('api-key-123', 'user-123', '127.0.0.1');

      expect(apiKeyRepository.softDelete).toHaveBeenCalledWith('api-key-123');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: 'user-123',
          action: 'DELETE',
          entity: 'api_key',
          entity_id: 'api-key-123',
          ip_address: '127.0.0.1'
        })
      );
    });

    it('should throw HttpError when API key not found', async () => {
      apiKeyRepository.findById.mockResolvedValue(null);

      await expect(deleteApiKey('api-key-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      apiKeyRepository.findById.mockResolvedValue({ id: 'api-key-123' });
      apiKeyRepository.softDelete.mockRejectedValue(new Error('DB error'));

      await expect(deleteApiKey('api-key-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should redact key_hash in audit log', async () => {
      const apiKey = {
        id: 'api-key-123',
        name: 'Test Key',
        key_hash: 'secret-hash'
      };

      apiKeyRepository.findById.mockResolvedValue(apiKey);
      apiKeyRepository.softDelete.mockResolvedValue();

      await deleteApiKey('api-key-123', 'user-123', '127.0.0.1');

      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          diff: {
            before: expect.objectContaining({ key_hash: '[REDACTED]' })
          }
        })
      );
    });
  });
});
