/**
 * Consent service tests
 *
 * @module tests/modules/consent/services
 * @description Tests for consent service
 * Per testing.mdc: Mock repository, test business logic
 */

const consentService = require('@services/consent/consent.service');
const consentRepository = require('@repositories/consent/consent.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/consent/consent.repository');
jest.mock('@lib/audit');

describe('Consent Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listConsents', () => {
    const mockConsents = [
      { id: '1', patient_id: 'patient-1', consent_type: 'TREATMENT', status: 'GRANTED' },
      { id: '2', patient_id: 'patient-2', consent_type: 'DATA_SHARING', status: 'PENDING' }
    ];

    it('should list consents with pagination', async () => {
      consentRepository.findMany.mockResolvedValue(mockConsents);
      consentRepository.count.mockResolvedValue(2);

      const result = await consentService.listConsents({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(result).toHaveProperty('consents', mockConsents);
      expect(result).toHaveProperty('pagination');
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply patient_id filter', async () => {
      const filters = { patient_id: 'patient-1' };
      consentRepository.findMany.mockResolvedValue(mockConsents);
      consentRepository.count.mockResolvedValue(2);

      await consentService.listConsents(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(consentRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ patient_id: 'patient-1' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should apply consent_type filter', async () => {
      const filters = { consent_type: 'TREATMENT' };
      consentRepository.findMany.mockResolvedValue(mockConsents);
      consentRepository.count.mockResolvedValue(2);

      await consentService.listConsents(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(consentRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ consent_type: 'TREATMENT' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should apply status filter', async () => {
      const filters = { status: 'GRANTED' };
      consentRepository.findMany.mockResolvedValue(mockConsents);
      consentRepository.count.mockResolvedValue(2);

      await consentService.listConsents(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(consentRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'GRANTED' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle repository errors', async () => {
      consentRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        consentService.listConsents({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getConsentById', () => {
    const consentId = '550e8400-e29b-41d4-a716-446655440000';
    const mockConsent = { id: consentId, patient_id: 'patient-1', consent_type: 'TREATMENT', status: 'GRANTED' };

    it('should get consent by ID', async () => {
      consentRepository.findById.mockResolvedValue(mockConsent);

      const result = await consentService.getConsentById(consentId, 'requester-id', '127.0.0.1');

      expect(result).toEqual(mockConsent);
    });

    it('should throw HttpError if consent not found', async () => {
      consentRepository.findById.mockResolvedValue(null);

      await expect(
        consentService.getConsentById(consentId, 'requester-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.consent.not_found',
        statusCode: 404
      });
    });
  });

  describe('createConsent', () => {
    const consentData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      consent_type: 'TREATMENT',
      status: 'GRANTED',
      granted_at: new Date('2026-01-19')
    };

    const createdConsent = { id: '550e8400-e29b-41d4-a716-446655440002', ...consentData };

    it('should create new consent', async () => {
      consentRepository.create.mockResolvedValue(createdConsent);
      createAuditLog.mockResolvedValue(true);

      const result = await consentService.createConsent(consentData, 'creator-id', '127.0.0.1');

      expect(result).toEqual(createdConsent);
    });

    it('should create audit log for consent creation', async () => {
      consentRepository.create.mockResolvedValue(createdConsent);
      createAuditLog.mockResolvedValue(true);

      await consentService.createConsent(consentData, 'creator-id', '127.0.0.1');
      await new Promise(resolve => setImmediate(resolve));

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'creator-id',
        action: 'CREATE',
        entity: 'consent',
        entity_id: createdConsent.id,
        diff: { after: createdConsent },
        ip_address: '127.0.0.1'
      });
    });
  });

  describe('updateConsent', () => {
    const consentId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { status: 'REVOKED', revoked_at: new Date('2026-01-19') };
    const beforeConsent = { id: consentId, status: 'GRANTED', revoked_at: null };
    const afterConsent = { id: consentId, status: 'REVOKED', revoked_at: new Date('2026-01-19') };

    it('should update consent', async () => {
      consentRepository.findById.mockResolvedValue(beforeConsent);
      consentRepository.update.mockResolvedValue(afterConsent);
      createAuditLog.mockResolvedValue(true);

      const result = await consentService.updateConsent(consentId, updateData, 'updater-id', '127.0.0.1');

      expect(result).toEqual(afterConsent);
    });

    it('should throw HttpError if consent not found', async () => {
      consentRepository.findById.mockResolvedValue(null);

      await expect(
        consentService.updateConsent(consentId, updateData, 'updater-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.consent.not_found',
        statusCode: 404
      });
    });

    it('should create audit log for consent update', async () => {
      consentRepository.findById.mockResolvedValue(beforeConsent);
      consentRepository.update.mockResolvedValue(afterConsent);
      createAuditLog.mockResolvedValue(true);

      await consentService.updateConsent(consentId, updateData, 'updater-id', '127.0.0.1');
      await new Promise(resolve => setImmediate(resolve));

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'updater-id',
        action: 'UPDATE',
        entity: 'consent',
        entity_id: consentId,
        diff: { before: beforeConsent, after: afterConsent },
        ip_address: '127.0.0.1'
      });
    });
  });

  describe('deleteConsent', () => {
    const consentId = '550e8400-e29b-41d4-a716-446655440000';
    const mockConsent = { id: consentId, status: 'GRANTED' };

    it('should delete consent', async () => {
      consentRepository.findById.mockResolvedValue(mockConsent);
      consentRepository.softDelete.mockResolvedValue({ ...mockConsent, deleted_at: new Date() });
      createAuditLog.mockResolvedValue(true);

      await consentService.deleteConsent(consentId, 'deleter-id', '127.0.0.1');

      expect(consentRepository.softDelete).toHaveBeenCalledWith(consentId);
    });

    it('should throw HttpError if consent not found', async () => {
      consentRepository.findById.mockResolvedValue(null);

      await expect(
        consentService.deleteConsent(consentId, 'deleter-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.consent.not_found',
        statusCode: 404
      });
    });

    it('should create audit log for consent deletion', async () => {
      consentRepository.findById.mockResolvedValue(mockConsent);
      consentRepository.softDelete.mockResolvedValue({ ...mockConsent, deleted_at: new Date() });
      createAuditLog.mockResolvedValue(true);

      await consentService.deleteConsent(consentId, 'deleter-id', '127.0.0.1');
      await new Promise(resolve => setImmediate(resolve));

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'deleter-id',
        action: 'DELETE',
        entity: 'consent',
        entity_id: consentId,
        diff: { before: mockConsent },
        ip_address: '127.0.0.1'
      });
    });
  });
});
