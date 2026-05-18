/**
 * Visit queue controller tests
 *
 * @module tests/modules/visit-queue/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/visit-queue/visit-queue.service');
jest.mock('@lib/response');

const visitQueueService = require('@services/visit-queue/visit-queue.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listVisitQueues,
  getVisitQueueById,
  createVisitQueue,
  updateVisitQueue,
  deleteVisitQueue
} = require('@controllers/visit-queue/visit-queue.controller');

describe('Visit Queue Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123'
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

  describe('listVisitQueues', () => {
    it('should list visit queue entries with default pagination', async () => {
      const mockResult = {
        entries: [
          { id: 'queue-1', patient_id: 'patient-123', status: 'SCHEDULED' },
          { id: 'queue-2', patient_id: 'patient-456', status: 'CONFIRMED' }
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
      visitQueueService.listVisitQueues.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listVisitQueues(req, res);

      expect(visitQueueService.listVisitQueues).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.visit_queue.list.success',
        mockResult.entries,
        mockResult.pagination
      );
    });

    it('should list visit queue entries with filters', async () => {
      const mockResult = {
        entries: [{ id: 'queue-1', tenant_id: 'tenant-123', status: 'SCHEDULED' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      visitQueueService.listVisitQueues.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        patient_id: 'patient-123',
        appointment_id: 'appointment-123',
        provider_user_id: 'user-123',
        status: 'SCHEDULED'
      };

      await listVisitQueues(req, res);

      expect(visitQueueService.listVisitQueues).toHaveBeenCalled();
    });

    it('should apply search filter', async () => {
      const mockResult = {
        entries: [{ id: 'queue-1' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      visitQueueService.listVisitQueues.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = { search: 'test' };

      await listVisitQueues(req, res);

      expect(visitQueueService.listVisitQueues).toHaveBeenCalled();
    });

    it('should apply custom sort and order', async () => {
      const mockResult = {
        entries: [],
        pagination: { page: 1, limit: 20, total: 0 }
      };
      visitQueueService.listVisitQueues.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = { sort_by: 'created_at', order: 'asc' };

      await listVisitQueues(req, res);

      expect(visitQueueService.listVisitQueues).toHaveBeenCalled();
    });
  });

  describe('getVisitQueueById', () => {
    it('should get visit queue entry by ID', async () => {
      const mockEntry = {
        id: 'queue-123',
        patient_id: 'patient-123',
        status: 'SCHEDULED'
      };
      visitQueueService.getVisitQueueById.mockResolvedValue(mockEntry);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'queue-123' };

      await getVisitQueueById(req, res);

      expect(visitQueueService.getVisitQueueById).toHaveBeenCalledWith('queue-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.visit_queue.get.success',
        mockEntry
      );
    });
  });

  describe('createVisitQueue', () => {
    it('should create visit queue entry', async () => {
      const entryData = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        status: 'SCHEDULED'
      };
      const mockCreated = {
        id: 'queue-123',
        ...entryData,
        created_at: new Date()
      };
      visitQueueService.createVisitQueue.mockResolvedValue(mockCreated);
      sendSuccess.mockImplementation(() => {});

      req.body = entryData;

      await createVisitQueue(req, res);

      expect(visitQueueService.createVisitQueue).toHaveBeenCalledWith(
        { ...entryData, facility_id: 'facility-123' },
        expect.objectContaining({
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        })
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.visit_queue.create.success',
        mockCreated
      );
    });

    it('should build context from request', async () => {
      const entryData = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        status: 'SCHEDULED'
      };
      const mockCreated = { id: 'queue-123', ...entryData };
      visitQueueService.createVisitQueue.mockResolvedValue(mockCreated);
      sendSuccess.mockImplementation(() => {});

      req.body = entryData;
      req.user = {
        id: 'user-456',
        tenant_id: 'tenant-456',
        facility_id: 'facility-456'
      };
      req.ip = '10.0.0.1';

      await createVisitQueue(req, res);

      expect(visitQueueService.createVisitQueue).toHaveBeenCalledWith(
        {
          ...entryData,
          tenant_id: 'tenant-456',
          facility_id: 'facility-456'
        },
        {
          user_id: 'user-456',
          tenant_id: 'tenant-456',
          facility_id: 'facility-456',
          ip_address: '10.0.0.1',
          user_agent: 'Mozilla/5.0'
        }
      );
    });
  });

  describe('updateVisitQueue', () => {
    it('should update visit queue entry', async () => {
      const updateData = { status: 'IN_PROGRESS' };
      const mockUpdated = {
        id: 'queue-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        status: 'IN_PROGRESS'
      };
      visitQueueService.updateVisitQueue.mockResolvedValue(mockUpdated);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'queue-123' };
      req.body = updateData;

      await updateVisitQueue(req, res);

      expect(visitQueueService.updateVisitQueue).toHaveBeenCalledWith(
        'queue-123',
        updateData,
        expect.objectContaining({
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        })
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.visit_queue.update.success',
        mockUpdated
      );
    });

    it('should update multiple fields', async () => {
      const updateData = {
        facility_id: 'facility-456',
        provider_user_id: 'user-789',
        status: 'COMPLETED'
      };
      const mockUpdated = { id: 'queue-123', ...updateData };
      visitQueueService.updateVisitQueue.mockResolvedValue(mockUpdated);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'queue-123' };
      req.body = updateData;

      await updateVisitQueue(req, res);

      expect(visitQueueService.updateVisitQueue).toHaveBeenCalledWith(
        'queue-123',
        { ...updateData, facility_id: 'facility-123' },
        expect.any(Object)
      );
    });

    it('should build context from request', async () => {
      const updateData = { status: 'CANCELLED' };
      const mockUpdated = { id: 'queue-123', ...updateData };
      visitQueueService.updateVisitQueue.mockResolvedValue(mockUpdated);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'queue-123' };
      req.body = updateData;
      req.user = {
        id: 'user-789',
        tenant_id: 'tenant-789',
        facility_id: 'facility-789'
      };
      req.ip = '172.16.0.1';

      await updateVisitQueue(req, res);

      expect(visitQueueService.updateVisitQueue).toHaveBeenCalledWith(
        'queue-123',
        updateData,
        {
          user_id: 'user-789',
          tenant_id: 'tenant-789',
          facility_id: 'facility-789',
          ip_address: '172.16.0.1',
          user_agent: 'Mozilla/5.0'
        }
      );
    });
  });

  describe('deleteVisitQueue', () => {
    it('should delete visit queue entry', async () => {
      visitQueueService.deleteVisitQueue.mockResolvedValue();
      sendNoContent.mockImplementation(() => {});

      req.params = { id: 'queue-123' };

      await deleteVisitQueue(req, res);

      expect(visitQueueService.deleteVisitQueue).toHaveBeenCalledWith(
        'queue-123',
        expect.objectContaining({
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '192.168.1.1',
          user_agent: 'Mozilla/5.0'
        })
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });

    it('should build context from request', async () => {
      visitQueueService.deleteVisitQueue.mockResolvedValue();
      sendNoContent.mockImplementation(() => {});

      req.params = { id: 'queue-123' };
      req.user = {
        id: 'user-999',
        tenant_id: 'tenant-999',
        facility_id: 'facility-999'
      };
      req.ip = '203.0.113.1';

      await deleteVisitQueue(req, res);

      expect(visitQueueService.deleteVisitQueue).toHaveBeenCalledWith(
        'queue-123',
        {
          user_id: 'user-999',
          tenant_id: 'tenant-999',
          facility_id: 'facility-999',
          ip_address: '203.0.113.1',
          user_agent: 'Mozilla/5.0'
        }
      );
    });
  });
});
