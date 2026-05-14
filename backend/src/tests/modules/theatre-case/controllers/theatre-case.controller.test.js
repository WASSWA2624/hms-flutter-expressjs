/**
 * Theatre case controller tests
 *
 * @module tests/modules/theatre-case/controllers
 * @description Tests for theatre case request handlers
 * Per testing.mdc: Controller tests must mock services
 */

const theatreCaseController = require('@controllers/theatre-case/theatre-case.controller');
const theatreCaseService = require('@services/theatre-case/theatre-case.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

// Mock dependencies
jest.mock('@services/theatre-case/theatre-case.service');
jest.mock('@lib/response');

describe('Theatre Case Controller', () => {
  let req, res;

  beforeEach(() => {
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
    jest.clearAllMocks();
  });

  describe('listTheatreCases', () => {
    const mockResult = {
      theatre_cases: [
        {
          id: '550e8400-e29b-41d4-a716-446655440000',
          encounter_id: '550e8400-e29b-41d4-a716-446655440001',
          scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
          status: 'SCHEDULED'
        }
      ],
      pagination: {
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      }
    };

    it('should list theatre cases with default pagination', async () => {
      req.query = {};
      theatreCaseService.listTheatreCases.mockResolvedValue(mockResult);

      await theatreCaseController.listTheatreCases(req, res);

      expect(theatreCaseService.listTheatreCases).toHaveBeenCalledWith(
        expect.any(Object),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.theatre_case.list.success',
        mockResult.theatre_cases,
        mockResult.pagination
      );
    });

    it('should list theatre cases with custom pagination', async () => {
      req.query = { page: '2', limit: '10', sort_by: 'scheduled_at', order: 'desc' };
      theatreCaseService.listTheatreCases.mockResolvedValue(mockResult);

      await theatreCaseController.listTheatreCases(req, res);

      expect(theatreCaseService.listTheatreCases).toHaveBeenCalledWith(
        expect.any(Object),
        2,
        10,
        'scheduled_at',
        'desc',
        'user-123',
        '127.0.0.1'
      );
    });

    it('should list theatre cases with filters', async () => {
      req.query = {
        encounter_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'SCHEDULED',
        scheduled_from: '2026-01-20T00:00:00.000Z',
        scheduled_to: '2026-01-20T23:59:59.000Z'
      };
      theatreCaseService.listTheatreCases.mockResolvedValue(mockResult);

      await theatreCaseController.listTheatreCases(req, res);

      expect(theatreCaseService.listTheatreCases).toHaveBeenCalledWith(
        expect.objectContaining({
          encounter_id: '550e8400-e29b-41d4-a716-446655440001',
          status: 'SCHEDULED',
          scheduled_from: '2026-01-20T00:00:00.000Z',
          scheduled_to: '2026-01-20T23:59:59.000Z'
        }),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getTheatreCaseById', () => {
    const mockTheatreCase = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
      status: 'SCHEDULED'
    };

    it('should get theatre case by id', async () => {
      req.params = { id: mockTheatreCase.id };
      theatreCaseService.getTheatreCaseById.mockResolvedValue(mockTheatreCase);

      await theatreCaseController.getTheatreCaseById(req, res);

      expect(theatreCaseService.getTheatreCaseById).toHaveBeenCalledWith(
        mockTheatreCase.id,
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.theatre_case.get.success',
        mockTheatreCase
      );
    });
  });

  describe('createTheatreCase', () => {
    const createData = {
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: '2026-01-20T10:00:00.000Z',
      status: 'SCHEDULED'
    };

    const mockCreatedTheatreCase = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData
    };

    it('should create theatre case', async () => {
      req.body = createData;
      theatreCaseService.createTheatreCase.mockResolvedValue(mockCreatedTheatreCase);

      await theatreCaseController.createTheatreCase(req, res);

      expect(theatreCaseService.createTheatreCase).toHaveBeenCalledWith(
        createData,
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.theatre_case.create.success',
        mockCreatedTheatreCase
      );
    });
  });

  describe('updateTheatreCase', () => {
    const updateData = {
      status: 'IN_PROGRESS'
    };

    const mockUpdatedTheatreCase = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      encounter_id: '550e8400-e29b-41d4-a716-446655440001',
      scheduled_at: new Date('2026-01-20T10:00:00.000Z'),
      status: 'IN_PROGRESS'
    };

    it('should update theatre case', async () => {
      req.params = { id: mockUpdatedTheatreCase.id };
      req.body = updateData;
      theatreCaseService.updateTheatreCase.mockResolvedValue(mockUpdatedTheatreCase);

      await theatreCaseController.updateTheatreCase(req, res);

      expect(theatreCaseService.updateTheatreCase).toHaveBeenCalledWith(
        mockUpdatedTheatreCase.id,
        updateData,
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.theatre_case.update.success',
        mockUpdatedTheatreCase
      );
    });
  });

  describe('deleteTheatreCase', () => {
    it('should delete theatre case', async () => {
      const id = '550e8400-e29b-41d4-a716-446655440000';
      req.params = { id };
      theatreCaseService.deleteTheatreCase.mockResolvedValue();

      await theatreCaseController.deleteTheatreCase(req, res);

      expect(theatreCaseService.deleteTheatreCase).toHaveBeenCalledWith(
        id,
        'user-123',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
