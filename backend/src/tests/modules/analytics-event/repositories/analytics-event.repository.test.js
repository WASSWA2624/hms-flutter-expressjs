/**
 * Analytics event repository tests
 *
 * @module tests/modules/analytics-event/repositories
 * @description Tests for analytics event repository operations
 * Per testing.mdc: Comprehensive repository tests with mocked Prisma client
 */

const analyticsEventRepository = require('@modules/analytics-event/repositories/analytics-event.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  analytics_event: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Analytics Event Repository', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  const mockAnalyticsEvent = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    tenant_id: '660e8400-e29b-41d4-a716-446655440000',
    user_id: '770e8400-e29b-41d4-a716-446655440000',
    event_name: 'page_view',
    payload_json: { page: '/dashboard' },
    occurred_at: new Date(),
    created_at: new Date(),
    updated_at: new Date(),
    deleted_at: null,
    version: 1
  };

  describe('findById', () => {
    it('should find analytics event by ID', async () => {
      prisma.analytics_event.findFirst.mockResolvedValue(mockAnalyticsEvent);

      const result = await analyticsEventRepository.findById(mockAnalyticsEvent.id);

      expect(result).toEqual(mockAnalyticsEvent);
    });

    it('should return null if analytics event not found', async () => {
      prisma.analytics_event.findFirst.mockResolvedValue(null);

      const result = await analyticsEventRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });
  });

  describe('findMany', () => {
    it('should find analytics events with default parameters', async () => {
      prisma.analytics_event.findMany.mockResolvedValue([mockAnalyticsEvent]);

      const result = await analyticsEventRepository.findMany();

      expect(result).toEqual([mockAnalyticsEvent]);
    });
  });

  describe('count', () => {
    it('should count analytics events', async () => {
      prisma.analytics_event.count.mockResolvedValue(10);

      const result = await analyticsEventRepository.count();

      expect(result).toBe(10);
    });
  });

  describe('create', () => {
    it('should create analytics event', async () => {
      const createData = {
        tenant_id: mockAnalyticsEvent.tenant_id,
        event_name: mockAnalyticsEvent.event_name,
        payload_json: mockAnalyticsEvent.payload_json
      };
      prisma.analytics_event.create.mockResolvedValue(mockAnalyticsEvent);

      const result = await analyticsEventRepository.create(createData);

      expect(result).toEqual(mockAnalyticsEvent);
    });
  });

  describe('update', () => {
    it('should update analytics event', async () => {
      const updateData = { event_name: 'button_click' };
      const updated = { ...mockAnalyticsEvent, ...updateData };
      prisma.analytics_event.update.mockResolvedValue(updated);

      const result = await analyticsEventRepository.update(mockAnalyticsEvent.id, updateData);

      expect(result).toEqual(updated);
    });
  });

  describe('softDelete', () => {
    it('should soft delete analytics event', async () => {
      const deleted = { ...mockAnalyticsEvent, deleted_at: new Date() };
      prisma.analytics_event.update.mockResolvedValue(deleted);

      const result = await analyticsEventRepository.softDelete(mockAnalyticsEvent.id);

      expect(result.deleted_at).toBeTruthy();
    });
  });
});
