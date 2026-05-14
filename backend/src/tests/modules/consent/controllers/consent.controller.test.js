/**
 * Consent controller tests
 *
 * @module tests/modules/consent/controllers
 * @description Tests for consent controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

const consentController = require('@controllers/consent/consent.controller');
const consentService = require('@services/consent/consent.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

// Mock dependencies
jest.mock('@services/consent/consent.service');
jest.mock('@lib/response');

describe('Consent Controller', () => {
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

  describe('listConsents', () => {
    const mockResult = {
      consents: [
        { id: '1', patient_id: 'patient-1', consent_type: 'TREATMENT', status: 'GRANTED' },
        { id: '2', patient_id: 'patient-2', consent_type: 'DATA_SHARING', status: 'PENDING' }
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

    it('should list consents with default pagination', async () => {
      consentService.listConsents.mockResolvedValue(mockResult);

      await consentController.listConsents(req, res);

      expect(consentService.listConsents).toHaveBeenCalledWith(
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
        'messages.consent.list.success',
        mockResult.consents,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      req.query = {
        patient_id: '550e8400-e29b-41d4-a716-446655440000',
        consent_type: 'TREATMENT',
        status: 'GRANTED'
      };
      consentService.listConsents.mockResolvedValue(mockResult);

      await consentController.listConsents(req, res);

      expect(consentService.listConsents).toHaveBeenCalledWith(
        expect.objectContaining({
          patient_id: '550e8400-e29b-41d4-a716-446655440000',
          consent_type: 'TREATMENT',
          status: 'GRANTED'
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
      consentService.listConsents.mockResolvedValue(mockResult);

      await consentController.listConsents(req, res);

      expect(consentService.listConsents).toHaveBeenCalledWith(
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

  describe('getConsentById', () => {
    const consentId = '550e8400-e29b-41d4-a716-446655440000';
    const mockConsent = { id: consentId, patient_id: 'patient-1', consent_type: 'TREATMENT', status: 'GRANTED' };

    it('should get consent by ID', async () => {
      req.params = { id: consentId };
      consentService.getConsentById.mockResolvedValue(mockConsent);

      await consentController.getConsentById(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.consent.get.success',
        mockConsent
      );
    });
  });

  describe('createConsent', () => {
    const consentData = {
      patient_id: '550e8400-e29b-41d4-a716-446655440000',
      consent_type: 'TREATMENT',
      status: 'GRANTED'
    };

    const createdConsent = { id: '550e8400-e29b-41d4-a716-446655440001', ...consentData };

    it('should create new consent', async () => {
      req.body = consentData;
      consentService.createConsent.mockResolvedValue(createdConsent);

      await consentController.createConsent(req, res);

      expect(consentService.createConsent).toHaveBeenCalledWith(
        expect.objectContaining({
          ...consentData,
          tenant_id: 'tenant-123'
        }),
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.consent.create.success',
        createdConsent
      );
    });

    it('should add tenant_id from user context', async () => {
      req.body = consentData;
      consentService.createConsent.mockResolvedValue(createdConsent);

      await consentController.createConsent(req, res);

      expect(consentService.createConsent).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-123'
        }),
        expect.any(String),
        expect.any(String)
      );
    });
  });

  describe('updateConsent', () => {
    const consentId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { status: 'REVOKED' };
    const updatedConsent = { id: consentId, ...updateData };

    it('should update consent', async () => {
      req.params = { id: consentId };
      req.body = updateData;
      consentService.updateConsent.mockResolvedValue(updatedConsent);

      await consentController.updateConsent(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.consent.update.success',
        updatedConsent
      );
    });
  });

  describe('deleteConsent', () => {
    const consentId = '550e8400-e29b-41d4-a716-446655440000';

    it('should delete consent', async () => {
      req.params = { id: consentId };
      consentService.deleteConsent.mockResolvedValue(undefined);

      await consentController.deleteConsent(req, res);

      expect(consentService.deleteConsent).toHaveBeenCalledWith(
        consentId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
