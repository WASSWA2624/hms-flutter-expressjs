/**
 * Integration log controller tests
 *
 * @module tests/modules/integration-log/controllers
 * @description Tests for integration log controller functions
 */

const integrationLogController = require('@controllers/integration-log/integration-log.controller');
const integrationLogService = require('@services/integration-log/integration-log.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

// Mock dependencies
jest.mock('@services/integration-log/integration-log.service');
jest.mock('@lib/response');

describe('Integration Log Controller', () => {
  let req, res;

  beforeEach(() => {
    req = {
      params: {},
      query: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123'
      },
      ip: '127.0.0.1'
    };

    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };

    sendSuccess.mockImplementation((res, status, message, data) => {
      res.status(status).json({ message, data });
    });

    sendPaginated.mockImplementation((res, message, data, pagination) => {
      res.status(200).json({ message, data, pagination });
    });
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getIntegrationLog', () => {
    it('should return integration log by ID', async () => {
      const mockIntegrationLog = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        integration_id: 'integration-123',
        message: 'Test log'
      };

      req.params.id = mockIntegrationLog.id;
      integrationLogService.getIntegrationLogById.mockResolvedValue(mockIntegrationLog);

      await integrationLogController.getIntegrationLog(req, res);

      expect(integrationLogService.getIntegrationLogById).toHaveBeenCalledWith(mockIntegrationLog.id);
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.integration_log.retrieved',
        mockIntegrationLog
      );
    });
  });

  describe('getIntegrationLogsByIntegrationId', () => {
    it('should return paginated integration logs for integration', async () => {
      const mockResult = {
        data: [
          { id: '1', message: 'Log 1' },
          { id: '2', message: 'Log 2' }
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

      req.params.integrationId = 'integration-123';
      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'logged_at',
        order: 'desc'
      };

      integrationLogService.getIntegrationLogsByIntegrationId.mockResolvedValue(mockResult);

      await integrationLogController.getIntegrationLogsByIntegrationId(req, res);

      expect(integrationLogService.getIntegrationLogsByIntegrationId).toHaveBeenCalledWith(
        'integration-123',
        1,
        20,
        'logged_at',
        'desc'
      );

      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.integration_log.list_retrieved',
        mockResult.data,
        mockResult.pagination
      );
    });
  });

  describe('listIntegrationLogs', () => {
    it('should return paginated integration logs', async () => {
      const mockResult = {
        data: [
          { id: '1', message: 'Log 1' },
          { id: '2', message: 'Log 2' }
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
        sort_by: 'logged_at',
        order: 'desc',
        integration_id: 'integration-123',
        status: 'ACTIVE'
      };

      integrationLogService.listIntegrationLogs.mockResolvedValue(mockResult);

      await integrationLogController.listIntegrationLogs(req, res);

      expect(integrationLogService.listIntegrationLogs).toHaveBeenCalledWith(
        { integration_id: 'integration-123', status: 'ACTIVE' },
        1,
        20,
        'logged_at',
        'desc'
      );

      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.integration_log.list_retrieved',
        mockResult.data,
        mockResult.pagination
      );
    });
  });
});
