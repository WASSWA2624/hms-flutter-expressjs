/**
 * Analytics event service tests
 *
 * @module tests/modules/analytics-event/services
 * @description Tests for analytics event service layer
 */

const analyticsEventService = require('@modules/analytics-event/services/analytics-event.service');
const analyticsEventRepository = require('@modules/analytics-event/repositories/analytics-event.repository');
const { createAuditLog } = require('@lib/audit');

jest.mock('@modules/analytics-event/repositories/analytics-event.repository');
jest.mock('@lib/audit');

describe('Analytics Event Service', () => {
  const tenantId = '660e8400-e29b-41d4-a716-446655440000';
  const userId = '550e8400-e29b-41d4-a716-446655440000';
  const actor = { id: userId, tenant_id: tenantId };
  const context = {
    user: actor,
    user_id: userId,
    ip_address: '127.0.0.1',
    user_agent: 'jest-test-agent',
  };

  const mockAnalyticsEvent = {
    id: '550e8400-e29b-41d4-a716-446655440001',
    human_friendly_id: 'ANL0000001',
    tenant_id: tenantId,
    user_id: userId,
    event_name: 'page_view',
    event_category: 'navigation',
    entity_type: 'report',
    entity_public_id: 'KPI0000001',
    severity: 'INFO',
    payload_json: { page: '/dashboard' },
    occurred_at: new Date('2026-01-19T12:00:00.000Z'),
    created_at: new Date('2026-01-19T12:00:00.000Z'),
    updated_at: new Date('2026-01-19T12:00:00.000Z'),
    deleted_at: null,
    version: 1,
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listAnalyticsEvents', () => {
    it('should list analytics events with pagination', async () => {
      analyticsEventRepository.findMany.mockResolvedValue([mockAnalyticsEvent]);
      analyticsEventRepository.count.mockResolvedValue(1);

      const result = await analyticsEventService.listAnalyticsEvents({}, 1, 20, 'created_at', 'desc', actor);

      expect(result.analyticsEvents).toEqual([
        expect.objectContaining({
          id: 'ANL0000001',
          display_id: 'ANL0000001',
          user_id: null,
          event_name: 'page_view',
          event_category: 'navigation',
          severity: 'INFO',
        }),
      ]);
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false,
      });
    });
  });

  describe('getAnalyticsEventById', () => {
    it('should get analytics event by ID', async () => {
      analyticsEventRepository.findById.mockResolvedValue(mockAnalyticsEvent);

      const result = await analyticsEventService.getAnalyticsEventById(mockAnalyticsEvent.id, actor);

      expect(result).toEqual(
        expect.objectContaining({
          id: 'ANL0000001',
          event_name: 'page_view',
          severity: 'INFO',
        })
      );
    });
  });

  describe('createAnalyticsEvent', () => {
    it('should create analytics event and audit log', async () => {
      analyticsEventRepository.create.mockResolvedValue(mockAnalyticsEvent);

      const result = await analyticsEventService.createAnalyticsEvent(
        {
          event_name: 'page_view',
          event_category: 'navigation',
          entity_type: 'report',
          entity_public_id: 'KPI0000001',
          severity: 'INFO',
          payload_json: { page: '/dashboard' },
          occurred_at: '2026-01-19T12:00:00.000Z',
        },
        context
      );

      expect(result).toEqual(
        expect.objectContaining({
          id: 'ANL0000001',
          user_id: null,
          event_name: 'page_view',
        })
      );
      expect(analyticsEventRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: tenantId,
          user_id: userId,
          event_name: 'page_view',
          event_category: 'navigation',
          entity_type: 'report',
          entity_public_id: 'KPI0000001',
          severity: 'INFO',
          payload_json: { page: '/dashboard' },
          occurred_at: new Date('2026-01-19T12:00:00.000Z'),
        })
      );
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: tenantId,
          user_id: userId,
          action: 'CREATE',
          entity: 'analytics_event',
          entity_id: mockAnalyticsEvent.id,
          diff: {
            after: expect.objectContaining({
              id: 'ANL0000001',
              event_name: 'page_view',
            }),
          },
          ip_address: '127.0.0.1',
          user_agent: 'jest-test-agent',
        })
      );
    });
  });

  describe('updateAnalyticsEvent', () => {
    it('should update analytics event and audit log', async () => {
      const updated = {
        ...mockAnalyticsEvent,
        event_name: 'button_click',
        severity: 'WARNING',
        version: 2,
      };
      analyticsEventRepository.findById.mockResolvedValue(mockAnalyticsEvent);
      analyticsEventRepository.update.mockResolvedValue(updated);

      const result = await analyticsEventService.updateAnalyticsEvent(
        mockAnalyticsEvent.id,
        {
          event_name: 'button_click',
          severity: 'WARNING',
          version: 1,
        },
        context
      );

      expect(result).toEqual(
        expect.objectContaining({
          id: 'ANL0000001',
          event_name: 'button_click',
          severity: 'WARNING',
          version: 2,
        })
      );
      expect(analyticsEventRepository.update).toHaveBeenCalledWith(mockAnalyticsEvent.id, {
        version: 2,
        event_name: 'button_click',
        severity: 'WARNING',
      });
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: tenantId,
          user_id: userId,
          action: 'UPDATE',
          entity: 'analytics_event',
          entity_id: mockAnalyticsEvent.id,
          diff: expect.objectContaining({
            before: expect.objectContaining({ event_name: 'page_view', severity: 'INFO', version: 1 }),
            after: expect.objectContaining({
              event_name: 'button_click',
              severity: 'WARNING',
              version: 2,
            }),
          }),
        })
      );
    });
  });

  describe('deleteAnalyticsEvent', () => {
    it('should soft delete analytics event and audit log', async () => {
      analyticsEventRepository.findById.mockResolvedValue(mockAnalyticsEvent);
      analyticsEventRepository.softDelete.mockResolvedValue({
        ...mockAnalyticsEvent,
        deleted_at: new Date(),
      });

      await analyticsEventService.deleteAnalyticsEvent(mockAnalyticsEvent.id, context);

      expect(analyticsEventRepository.softDelete).toHaveBeenCalledWith(mockAnalyticsEvent.id);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: tenantId,
          user_id: userId,
          action: 'DELETE',
          entity: 'analytics_event',
          entity_id: mockAnalyticsEvent.id,
          diff: {
            before: expect.objectContaining({
              id: 'ANL0000001',
              event_name: 'page_view',
            }),
          },
        })
      );
    });
  });
});
