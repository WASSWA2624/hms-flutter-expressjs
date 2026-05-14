/**
 * Analytics event controller tests
 *
 * @module tests/modules/analytics-event/controllers
 * @description Tests for analytics event controllers
 * Per testing.mdc: Comprehensive controller tests with mocked service
 */

const analyticsEventController = require('@modules/analytics-event/controllers/analytics-event.controller');
const analyticsEventService = require('@modules/analytics-event/services/analytics-event.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

// Mock service and response helpers
jest.mock('@modules/analytics-event/services/analytics-event.service');
jest.mock('@lib/response');

describe('Analytics Event Controller', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  const mockReq = {
    query: {},
    params: {},
    body: {},
    user: { id: 'user-id-123' },
    ip: '127.0.0.1',
    get: jest.fn(() => 'jest-test-agent')
  };

  const mockRes = {};

  const mockAnalyticsEvent = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    tenant_id: '660e8400-e29b-41d4-a716-446655440000',
    event_name: 'page_view',
    payload_json: { page: '/dashboard' },
    occurred_at: new Date(),
    created_at: new Date(),
    updated_at: new Date(),
    deleted_at: null,
    version: 1
  };

  describe('listAnalyticsEvents', () => {
    it('should list analytics events', async () => {
      const mockResult = {
        analyticsEvents: [mockAnalyticsEvent],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      analyticsEventService.listAnalyticsEvents.mockResolvedValue(mockResult);

      await analyticsEventController.listAnalyticsEvents(mockReq, mockRes);

      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.analytics_event.list.success',
        mockResult.analyticsEvents,
        mockResult.pagination
      );
    });
  });

  describe('getAnalyticsEventById', () => {
    it('should get analytics event by ID', async () => {
      mockReq.params = { id: mockAnalyticsEvent.id };
      analyticsEventService.getAnalyticsEventById.mockResolvedValue(mockAnalyticsEvent);

      await analyticsEventController.getAnalyticsEventById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.analytics_event.get.success',
        mockAnalyticsEvent
      );
    });
  });

  describe('createAnalyticsEvent', () => {
    it('should create analytics event', async () => {
      mockReq.body = {
        tenant_id: mockAnalyticsEvent.tenant_id,
        event_name: mockAnalyticsEvent.event_name
      };
      analyticsEventService.createAnalyticsEvent.mockResolvedValue(mockAnalyticsEvent);

      await analyticsEventController.createAnalyticsEvent(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.analytics_event.create.success',
        mockAnalyticsEvent
      );
    });
  });

  describe('updateAnalyticsEvent', () => {
    it('should update analytics event', async () => {
      mockReq.params = { id: mockAnalyticsEvent.id };
      mockReq.body = { event_name: 'button_click' };
      const updated = { ...mockAnalyticsEvent, event_name: 'button_click' };
      analyticsEventService.updateAnalyticsEvent.mockResolvedValue(updated);

      await analyticsEventController.updateAnalyticsEvent(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.analytics_event.update.success',
        updated
      );
    });
  });

  describe('deleteAnalyticsEvent', () => {
    it('should delete analytics event', async () => {
      mockReq.params = { id: mockAnalyticsEvent.id };
      analyticsEventService.deleteAnalyticsEvent.mockResolvedValue();

      await analyticsEventController.deleteAnalyticsEvent(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
