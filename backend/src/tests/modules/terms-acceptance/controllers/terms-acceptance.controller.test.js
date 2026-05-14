/**
 * Terms acceptance controller tests
 *
 * @module tests/modules/terms-acceptance/controllers
 * @description Tests for terms acceptance controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

const termsAcceptanceController = require('@controllers/terms-acceptance/terms-acceptance.controller');
const termsAcceptanceService = require('@services/terms-acceptance/terms-acceptance.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

// Mock dependencies
jest.mock('@services/terms-acceptance/terms-acceptance.service');
jest.mock('@lib/response');

describe('Terms Acceptance Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'requester-id', tenant_id: 'tenant-123' },
      ip: '127.0.0.1'
    };

    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listTermsAcceptances', () => {
    const mockResult = {
      termsAcceptances: [
        { id: '1', user_id: 'user-1', version_label: 'v1.0.0' },
        { id: '2', user_id: 'user-2', version_label: 'v1.0.0' }
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

    it('should list terms acceptances with default pagination', async () => {
      termsAcceptanceService.listTermsAcceptances.mockResolvedValue(mockResult);

      await termsAcceptanceController.listTermsAcceptances(req, res);

      expect(termsAcceptanceService.listTermsAcceptances).toHaveBeenCalledWith(
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
        'messages.terms_acceptance.list.success',
        mockResult.termsAcceptances,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      req.query = {
        user_id: '550e8400-e29b-41d4-a716-446655440000',
        version_label: 'v1.0.0'
      };
      termsAcceptanceService.listTermsAcceptances.mockResolvedValue(mockResult);

      await termsAcceptanceController.listTermsAcceptances(req, res);

      expect(termsAcceptanceService.listTermsAcceptances).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: '550e8400-e29b-41d4-a716-446655440000',
          version_label: 'v1.0.0'
        }),
        expect.any(Number),
        expect.any(Number),
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
    });

    it('should apply pagination from query params', async () => {
      req.query = { page: '2', limit: '50' };
      termsAcceptanceService.listTermsAcceptances.mockResolvedValue(mockResult);

      await termsAcceptanceController.listTermsAcceptances(req, res);

      expect(termsAcceptanceService.listTermsAcceptances).toHaveBeenCalledWith(
        expect.any(Object),
        2,
        50,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
    });
  });

  describe('getTermsAcceptanceById', () => {
    const taId = '550e8400-e29b-41d4-a716-446655440000';
    const mockTermsAcceptance = { id: taId, user_id: 'user-1', version_label: 'v1.0.0' };

    it('should get terms acceptance by ID', async () => {
      req.params = { id: taId };
      termsAcceptanceService.getTermsAcceptanceById.mockResolvedValue(mockTermsAcceptance);

      await termsAcceptanceController.getTermsAcceptanceById(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.terms_acceptance.get.success',
        mockTermsAcceptance
      );
    });
  });

  describe('createTermsAcceptance', () => {
    const taData = {
      user_id: '550e8400-e29b-41d4-a716-446655440000',
      version_label: 'v1.0.0'
    };

    const createdTermsAcceptance = { id: '550e8400-e29b-41d4-a716-446655440001', ...taData };

    it('should create new terms acceptance', async () => {
      req.body = taData;
      termsAcceptanceService.createTermsAcceptance.mockResolvedValue(createdTermsAcceptance);

      await termsAcceptanceController.createTermsAcceptance(req, res);

      expect(termsAcceptanceService.createTermsAcceptance).toHaveBeenCalledWith(
        expect.objectContaining({
          ...taData,
          tenant_id: 'tenant-123'
        }),
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.terms_acceptance.create.success',
        createdTermsAcceptance
      );
    });

    it('should add tenant_id from user context', async () => {
      req.body = taData;
      termsAcceptanceService.createTermsAcceptance.mockResolvedValue(createdTermsAcceptance);

      await termsAcceptanceController.createTermsAcceptance(req, res);

      expect(termsAcceptanceService.createTermsAcceptance).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-123'
        }),
        expect.any(String),
        expect.any(String)
      );
    });
  });

  describe('deleteTermsAcceptance', () => {
    const taId = '550e8400-e29b-41d4-a716-446655440000';

    it('should delete terms acceptance', async () => {
      req.params = { id: taId };
      termsAcceptanceService.deleteTermsAcceptance.mockResolvedValue(undefined);

      await termsAcceptanceController.deleteTermsAcceptance(req, res);

      expect(termsAcceptanceService.deleteTermsAcceptance).toHaveBeenCalledWith(
        taId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
