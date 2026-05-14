/**
 * Adverse Event controller tests
 *
 * @module tests/modules/adverse-event/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/adverse-event/adverse-event.service');
jest.mock('@lib/response');
jest.mock('@lib/errors');

const adverseEventService = require('@services/adverse-event/adverse-event.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { HttpError } = require('@lib/errors');
const {
  listAdverseEvents,
  getAdverseEventById,
  createAdverseEvent,
  updateAdverseEvent,
  deleteAdverseEvent
} = require('@controllers/adverse-event/adverse-event.controller');

describe('Adverse Event Controller', () => {
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
      ip: '192.168.1.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listAdverseEvents', () => {
    it('should list adverse events with default pagination', async () => {
      const mockResult = {
        items: [
          { id: 'event-1', patient_id: 'patient-123', severity: 'MILD' },
          { id: 'event-2', patient_id: 'patient-123', severity: 'SEVERE' }
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
      adverseEventService.listAdverseEvents.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listAdverseEvents(req, res);

      expect(adverseEventService.listAdverseEvents).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.adverse_event.list.success',
        mockResult.items,
        mockResult.pagination
      );
    });

    it('should list adverse events with filters', async () => {
      const mockResult = {
        items: [{ id: 'event-1', patient_id: 'patient-123', severity: 'SEVERE' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      adverseEventService.listAdverseEvents.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = { patient_id: 'patient-123', severity: 'SEVERE' };

      await listAdverseEvents(req, res);

      expect(adverseEventService.listAdverseEvents).toHaveBeenCalledWith(
        { patient_id: 'patient-123', severity: 'SEVERE' },
        1,
        20,
        'created_at',
        'desc'
      );
    });

    it('should handle custom sort parameters', async () => {
      const mockResult = { items: [], pagination: {} };
      adverseEventService.listAdverseEvents.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = { sort_by: 'reported_at', order: 'asc' };

      await listAdverseEvents(req, res);

      expect(adverseEventService.listAdverseEvents).toHaveBeenCalledWith(
        {},
        1,
        20,
        'reported_at',
        'asc'
      );
    });
  });

  describe('getAdverseEventById', () => {
    it('should get adverse event by ID', async () => {
      const mockAdverseEvent = { id: 'event-123', severity: 'MODERATE' };
      adverseEventService.getAdverseEventById.mockResolvedValue(mockAdverseEvent);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params.id = 'event-123';

      await getAdverseEventById(req, res);

      expect(adverseEventService.getAdverseEventById).toHaveBeenCalledWith('event-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.adverse_event.get.success',
        mockAdverseEvent
      );
    });

    it('should throw HttpError if adverse event not found', async () => {
      adverseEventService.getAdverseEventById.mockResolvedValue(null);
      HttpError.mockImplementation((message, status) => {
        const error = new Error(message);
        error.status = status;
        return error;
      });

      req.params.id = 'event-123';

      await expect(getAdverseEventById(req, res))
        .rejects
        .toThrow();
    });
  });

  describe('createAdverseEvent', () => {
    it('should create adverse event', async () => {
      const newAdverseEvent = {
        patient_id: 'patient-123',
        severity: 'MODERATE',
        description: 'Test'
      };
      const mockCreatedAdverseEvent = {
        id: 'event-123',
        ...newAdverseEvent
      };
      adverseEventService.createAdverseEvent.mockResolvedValue(mockCreatedAdverseEvent);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = newAdverseEvent;

      await createAdverseEvent(req, res);

      expect(adverseEventService.createAdverseEvent).toHaveBeenCalledWith(
        newAdverseEvent,
        { user_id: 'user-123', ip: '192.168.1.1' }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.adverse_event.create.success',
        mockCreatedAdverseEvent
      );
    });
  });

  describe('updateAdverseEvent', () => {
    it('should update adverse event', async () => {
      const updateData = { severity: 'SEVERE', description: 'Updated' };
      const mockUpdatedAdverseEvent = {
        id: 'event-123',
        ...updateData
      };
      adverseEventService.updateAdverseEvent.mockResolvedValue(mockUpdatedAdverseEvent);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params.id = 'event-123';
      req.body = updateData;

      await updateAdverseEvent(req, res);

      expect(adverseEventService.updateAdverseEvent).toHaveBeenCalledWith(
        'event-123',
        updateData,
        { user_id: 'user-123', ip: '192.168.1.1' }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.adverse_event.update.success',
        mockUpdatedAdverseEvent
      );
    });
  });

  describe('deleteAdverseEvent', () => {
    it('should delete adverse event', async () => {
      adverseEventService.deleteAdverseEvent.mockResolvedValue({});

      req.params.id = 'event-123';

      await deleteAdverseEvent(req, res);

      expect(adverseEventService.deleteAdverseEvent).toHaveBeenCalledWith(
        'event-123',
        { user_id: 'user-123', ip: '192.168.1.1' }
      );
      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });
  });
});
