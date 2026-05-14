/**
 * Provider schedule controller tests
 *
 * @module tests/modules/provider-schedule/controllers
 * @description Tests for provider schedule controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

const providerScheduleController = require('@controllers/provider-schedule/provider-schedule.controller');
const providerScheduleService = require('@services/provider-schedule/provider-schedule.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

// Mock dependencies
jest.mock('@services/provider-schedule/provider-schedule.service');
jest.mock('@lib/response');

describe('Provider Schedule Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'requester-id' },
      ip: '127.0.0.1'
    };

    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listProviderSchedules', () => {
    const mockResult = {
      schedules: [
        { id: '1', provider_user_id: 'provider-1', day_of_week: 1 },
        { id: '2', provider_user_id: 'provider-2', day_of_week: 3 }
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

    it('should list schedules with default pagination', async () => {
      providerScheduleService.listProviderSchedules.mockResolvedValue(mockResult);

      await providerScheduleController.listProviderSchedules(req, res);

      expect(providerScheduleService.listProviderSchedules).toHaveBeenCalledWith(
        expect.any(Object),
        DEFAULT_PAGE,
        DEFAULT_PAGE_LIMIT,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.provider_schedule.list.success',
        mockResult.schedules,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      req.query = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        provider_user_id: '550e8400-e29b-41d4-a716-446655440002',
        day_of_week: 1,
        page: '2',
        limit: '10',
        sort_by: 'day_of_week',
        order: 'desc'
      };
      providerScheduleService.listProviderSchedules.mockResolvedValue(mockResult);

      await providerScheduleController.listProviderSchedules(req, res);

      expect(providerScheduleService.listProviderSchedules).toHaveBeenCalledWith(
        {
          tenant_id: '550e8400-e29b-41d4-a716-446655440000',
          facility_id: '550e8400-e29b-41d4-a716-446655440001',
          provider_user_id: '550e8400-e29b-41d4-a716-446655440002',
          day_of_week: 1
        },
        2,
        10,
        'day_of_week',
        'desc',
        'requester-id',
        '127.0.0.1'
      );
    });
  });

  describe('getProviderScheduleById', () => {
    const mockSchedule = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      provider_user_id: 'provider-1',
      day_of_week: 1
    };

    it('should get schedule by ID', async () => {
      req.params.id = '550e8400-e29b-41d4-a716-446655440000';
      providerScheduleService.getProviderScheduleById.mockResolvedValue(mockSchedule);

      await providerScheduleController.getProviderScheduleById(req, res);

      expect(providerScheduleService.getProviderScheduleById).toHaveBeenCalledWith(
        '550e8400-e29b-41d4-a716-446655440000',
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.provider_schedule.get.success',
        mockSchedule
      );
    });
  });

  describe('createProviderSchedule', () => {
    const scheduleData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      provider_user_id: '550e8400-e29b-41d4-a716-446655440002',
      day_of_week: 1,
      start_time: '2026-01-20T08:00:00.000Z',
      end_time: '2026-01-20T17:00:00.000Z'
    };

    const createdSchedule = { id: '550e8400-e29b-41d4-a716-446655440000', ...scheduleData };

    it('should create a schedule', async () => {
      req.body = scheduleData;
      providerScheduleService.createProviderSchedule.mockResolvedValue(createdSchedule);

      await providerScheduleController.createProviderSchedule(req, res);

      expect(providerScheduleService.createProviderSchedule).toHaveBeenCalledWith(
        scheduleData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.provider_schedule.create.success',
        createdSchedule
      );
    });
  });

  describe('updateProviderSchedule', () => {
    const updateData = { day_of_week: 3 };
    const updatedSchedule = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      day_of_week: 3
    };

    it('should update a schedule', async () => {
      req.params.id = '550e8400-e29b-41d4-a716-446655440000';
      req.body = updateData;
      providerScheduleService.updateProviderSchedule.mockResolvedValue(updatedSchedule);

      await providerScheduleController.updateProviderSchedule(req, res);

      expect(providerScheduleService.updateProviderSchedule).toHaveBeenCalledWith(
        '550e8400-e29b-41d4-a716-446655440000',
        updateData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.provider_schedule.update.success',
        updatedSchedule
      );
    });
  });

  describe('deleteProviderSchedule', () => {
    it('should soft delete a schedule', async () => {
      req.params.id = '550e8400-e29b-41d4-a716-446655440000';
      providerScheduleService.deleteProviderSchedule.mockResolvedValue();

      await providerScheduleController.deleteProviderSchedule(req, res);

      expect(providerScheduleService.deleteProviderSchedule).toHaveBeenCalledWith(
        '550e8400-e29b-41d4-a716-446655440000',
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
