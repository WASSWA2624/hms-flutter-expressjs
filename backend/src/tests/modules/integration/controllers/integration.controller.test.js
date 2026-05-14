/**
 * Integration controller tests
 *
 * @module tests/modules/integration/controllers
 * @description Tests for integration controller functions
 */

const integrationController = require('@controllers/integration/integration.controller');
const integrationService = require('@services/integration/integration.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

// Mock dependencies
jest.mock('@services/integration/integration.service');
jest.mock('@lib/response');

describe('Integration Controller', () => {
  let req, res;

  beforeEach(() => {
    req = {
      params: {},
      query: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123'
      },
      ip: '127.0.0.1'
    };

    res = {
      status: jest.fn().mockReturnThis(),
      send: jest.fn(),
      json: jest.fn()
    };

    sendSuccess.mockImplementation((res, status, message, data) => {
      return res;
    });

    sendPaginated.mockImplementation((res, message, data, pagination) => {
      return res;
    });
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getIntegration', () => {
    it('should return integration by ID', async () => {
      const mockIntegration = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Test Integration'
      };

      req.params.id = mockIntegration.id;
      integrationService.getIntegrationById.mockResolvedValue(mockIntegration);

      await integrationController.getIntegration(req, res);

      expect(integrationService.getIntegrationById).toHaveBeenCalledWith(mockIntegration.id);
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.integration.retrieved',
        mockIntegration
      );
    });
  });

  describe('listIntegrations', () => {
    it('should return paginated integrations', async () => {
      const mockResult = {
        data: [
          { id: '1', name: 'Integration 1' },
          { id: '2', name: 'Integration 2' }
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

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'created_at',
        order: 'desc',
        tenant_id: 'tenant-123'
      };

      integrationService.listIntegrations.mockResolvedValue(mockResult);

      await integrationController.listIntegrations(req, res);

      expect(integrationService.listIntegrations).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123' },
        1,
        20,
        'created_at',
        'desc'
      );

      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.integration.list_retrieved',
        mockResult.data,
        mockResult.pagination
      );
    });
  });

  describe('createIntegration', () => {
    it('should create new integration', async () => {
      const mockData = {
        tenant_id: 'tenant-123',
        integration_type: 'HL7',
        status: 'ACTIVE',
        name: 'New Integration'
      };

      const mockCreated = { id: 'new-id', ...mockData };
      req.body = mockData;

      integrationService.createIntegration.mockResolvedValue(mockCreated);

      await integrationController.createIntegration(req, res);

      expect(integrationService.createIntegration).toHaveBeenCalledWith(
        mockData,
        {
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          ip_address: '127.0.0.1'
        }
      );

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.integration.created',
        mockCreated
      );
    });
  });

  describe('updateIntegration', () => {
    it('should update integration', async () => {
      const mockData = { name: 'Updated Integration' };
      const mockUpdated = { id: 'integration-id', ...mockData };

      req.params.id = 'integration-id';
      req.body = mockData;

      integrationService.updateIntegration.mockResolvedValue(mockUpdated);

      await integrationController.updateIntegration(req, res);

      expect(integrationService.updateIntegration).toHaveBeenCalledWith(
        'integration-id',
        mockData,
        {
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          ip_address: '127.0.0.1'
        }
      );

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.integration.updated',
        mockUpdated
      );
    });
  });

  describe('deleteIntegration', () => {
    it('should delete integration and return 204', async () => {
      req.params.id = 'integration-id';

      integrationService.deleteIntegration.mockResolvedValue({});

      await integrationController.deleteIntegration(req, res);

      expect(integrationService.deleteIntegration).toHaveBeenCalledWith(
        'integration-id',
        {
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          ip_address: '127.0.0.1'
        }
      );

      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });
  });
});
