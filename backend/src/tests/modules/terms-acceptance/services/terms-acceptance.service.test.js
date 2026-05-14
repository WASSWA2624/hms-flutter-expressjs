/**
 * Terms acceptance service tests
 *
 * @module tests/modules/terms-acceptance/services
 * @description Tests for terms acceptance service
 * Per testing.mdc: Mock repository, test business logic
 */

const termsAcceptanceService = require('@services/terms-acceptance/terms-acceptance.service');
const termsAcceptanceRepository = require('@repositories/terms-acceptance/terms-acceptance.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/terms-acceptance/terms-acceptance.repository');
jest.mock('@lib/audit');

describe('Terms Acceptance Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listTermsAcceptances', () => {
    const mockTermsAcceptances = [
      { id: '1', user_id: 'user-1', version_label: 'v1.0.0' },
      { id: '2', user_id: 'user-2', version_label: 'v1.0.0' }
    ];

    it('should list terms acceptances with pagination', async () => {
      termsAcceptanceRepository.findMany.mockResolvedValue(mockTermsAcceptances);
      termsAcceptanceRepository.count.mockResolvedValue(2);

      const result = await termsAcceptanceService.listTermsAcceptances({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(result).toHaveProperty('termsAcceptances', mockTermsAcceptances);
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

    it('should apply user_id filter', async () => {
      const filters = { user_id: 'user-1' };
      termsAcceptanceRepository.findMany.mockResolvedValue(mockTermsAcceptances);
      termsAcceptanceRepository.count.mockResolvedValue(2);

      await termsAcceptanceService.listTermsAcceptances(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(termsAcceptanceRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ user_id: 'user-1' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should apply version_label filter', async () => {
      const filters = { version_label: 'v1.0.0' };
      termsAcceptanceRepository.findMany.mockResolvedValue(mockTermsAcceptances);
      termsAcceptanceRepository.count.mockResolvedValue(2);

      await termsAcceptanceService.listTermsAcceptances(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(termsAcceptanceRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ version_label: 'v1.0.0' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle repository errors', async () => {
      termsAcceptanceRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        termsAcceptanceService.listTermsAcceptances({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getTermsAcceptanceById', () => {
    const taId = '550e8400-e29b-41d4-a716-446655440000';
    const mockTermsAcceptance = { id: taId, user_id: 'user-1', version_label: 'v1.0.0' };

    it('should get terms acceptance by ID', async () => {
      termsAcceptanceRepository.findById.mockResolvedValue(mockTermsAcceptance);

      const result = await termsAcceptanceService.getTermsAcceptanceById(taId, 'requester-id', '127.0.0.1');

      expect(result).toEqual(mockTermsAcceptance);
    });

    it('should throw HttpError if terms acceptance not found', async () => {
      termsAcceptanceRepository.findById.mockResolvedValue(null);

      await expect(
        termsAcceptanceService.getTermsAcceptanceById(taId, 'requester-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.terms_acceptance.not_found',
        statusCode: 404
      });
    });
  });

  describe('createTermsAcceptance', () => {
    const taData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      user_id: '550e8400-e29b-41d4-a716-446655440001',
      version_label: 'v1.0.0',
      accepted_at: new Date('2026-01-19')
    };

    const createdTermsAcceptance = { id: '550e8400-e29b-41d4-a716-446655440002', ...taData };

    it('should create new terms acceptance', async () => {
      termsAcceptanceRepository.create.mockResolvedValue(createdTermsAcceptance);
      createAuditLog.mockResolvedValue(true);

      const result = await termsAcceptanceService.createTermsAcceptance(taData, 'creator-id', '127.0.0.1');

      expect(result).toEqual(createdTermsAcceptance);
    });

    it('should create audit log for terms acceptance creation', async () => {
      termsAcceptanceRepository.create.mockResolvedValue(createdTermsAcceptance);
      createAuditLog.mockResolvedValue(true);

      await termsAcceptanceService.createTermsAcceptance(taData, 'creator-id', '127.0.0.1');
      await new Promise(resolve => setImmediate(resolve));

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'creator-id',
        action: 'CREATE',
        entity: 'terms_acceptance',
        entity_id: createdTermsAcceptance.id,
        diff: { after: createdTermsAcceptance },
        ip_address: '127.0.0.1'
      });
    });
  });

  describe('deleteTermsAcceptance', () => {
    const taId = '550e8400-e29b-41d4-a716-446655440000';
    const mockTermsAcceptance = { id: taId, version_label: 'v1.0.0' };

    it('should delete terms acceptance', async () => {
      termsAcceptanceRepository.findById.mockResolvedValue(mockTermsAcceptance);
      termsAcceptanceRepository.softDelete.mockResolvedValue({ ...mockTermsAcceptance, deleted_at: new Date() });
      createAuditLog.mockResolvedValue(true);

      await termsAcceptanceService.deleteTermsAcceptance(taId, 'deleter-id', '127.0.0.1');

      expect(termsAcceptanceRepository.softDelete).toHaveBeenCalledWith(taId);
    });

    it('should throw HttpError if terms acceptance not found', async () => {
      termsAcceptanceRepository.findById.mockResolvedValue(null);

      await expect(
        termsAcceptanceService.deleteTermsAcceptance(taId, 'deleter-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.terms_acceptance.not_found',
        statusCode: 404
      });
    });

    it('should create audit log for terms acceptance deletion', async () => {
      termsAcceptanceRepository.findById.mockResolvedValue(mockTermsAcceptance);
      termsAcceptanceRepository.softDelete.mockResolvedValue({ ...mockTermsAcceptance, deleted_at: new Date() });
      createAuditLog.mockResolvedValue(true);

      await termsAcceptanceService.deleteTermsAcceptance(taId, 'deleter-id', '127.0.0.1');
      await new Promise(resolve => setImmediate(resolve));

      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'deleter-id',
        action: 'DELETE',
        entity: 'terms_acceptance',
        entity_id: taId,
        diff: { before: mockTermsAcceptance },
        ip_address: '127.0.0.1'
      });
    });
  });
});
