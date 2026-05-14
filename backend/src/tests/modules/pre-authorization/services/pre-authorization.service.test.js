/**
 * Pre-authorization service tests
 *
 * @module tests/modules/pre-authorization/services
 * @description Tests for pre-authorization service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const preAuthorizationService = require('@services/pre-authorization/pre-authorization.service');
const preAuthorizationRepository = require('@repositories/pre-authorization/pre-authorization.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/pre-authorization/pre-authorization.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: (...values) => {
    for (const value of values) {
      const normalized =
        typeof value === 'string'
          ? value.trim()
          : value == null
            ? ''
            : String(value).trim();
      if (normalized) return normalized;
    }
    return null;
  },
  resolveIdentifierForFilter: async ({ value }) => value,
  resolveIdentifierForPayload: async ({ value, nullable = false }) => {
    if (value === undefined) return undefined;
    if (value === null && nullable) return null;
    return value;
  },
  resolveEntityId: async ({ identifier }) => identifier,
}));

describe('Pre-Authorization Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  describe('listPreAuthorizations', () => {
    it('should list pre-authorizations with pagination', async () => {
      const mockAuths = [{ id: '1', status: 'PENDING' }];
      preAuthorizationRepository.findMany.mockResolvedValue(mockAuths);
      preAuthorizationRepository.count.mockResolvedValue(1);

      const result = await preAuthorizationService.listPreAuthorizations({}, 1, 20, 'created_at', 'desc', mockUserId, mockIpAddress);

      expect(result.pre_authorizations).toEqual(
        expect.arrayContaining(mockAuths.map((entry) => expect.objectContaining(entry)))
      );
      expect(result.pagination.total).toBe(1);
    });

    it('should throw HttpError on repository error', async () => {
      preAuthorizationRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        preAuthorizationService.listPreAuthorizations({}, 1, 20, null, 'asc', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getPreAuthorizationById', () => {
    it('should get pre-authorization by id', async () => {
      const mockAuth = { id: '123', status: 'PENDING' };
      preAuthorizationRepository.findById.mockResolvedValue(mockAuth);

      const result = await preAuthorizationService.getPreAuthorizationById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining(mockAuth));
    });

    it('should throw HttpError if pre-authorization not found', async () => {
      preAuthorizationRepository.findById.mockResolvedValue(null);

      await expect(
        preAuthorizationService.getPreAuthorizationById('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createPreAuthorization', () => {
    it('should create pre-authorization and log audit', async () => {
      const mockData = { coverage_plan_id: '123', status: 'PENDING' };
      const mockAuth = { id: '789', ...mockData };
      preAuthorizationRepository.create.mockResolvedValue(mockAuth);
      preAuthorizationRepository.findById.mockResolvedValue(mockAuth);

      const result = await preAuthorizationService.createPreAuthorization(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining(mockAuth));
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'pre_authorization'
      }));
    });
  });

  describe('updatePreAuthorization', () => {
    it('should update pre-authorization and log audit', async () => {
      const mockBefore = { id: '123', status: 'PENDING' };
      const mockAfter = { id: '123', status: 'APPROVED' };
      preAuthorizationRepository.findById
        .mockResolvedValueOnce(mockBefore)
        .mockResolvedValueOnce(mockAfter);
      preAuthorizationRepository.update.mockResolvedValue(mockAfter);

      const result = await preAuthorizationService.updatePreAuthorization('123', { status: 'APPROVED' }, mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining(mockAfter));
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'UPDATE',
        diff: { before: mockBefore, after: mockAfter }
      }));
    });

    it('should throw HttpError if pre-authorization not found', async () => {
      preAuthorizationRepository.findById.mockResolvedValue(null);

      await expect(
        preAuthorizationService.updatePreAuthorization('nonexistent', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deletePreAuthorization', () => {
    it('should soft delete pre-authorization and log audit', async () => {
      const mockAuth = { id: '123', status: 'PENDING' };
      preAuthorizationRepository.findById.mockResolvedValue(mockAuth);
      preAuthorizationRepository.softDelete.mockResolvedValue(mockAuth);

      await preAuthorizationService.deletePreAuthorization('123', mockUserId, mockIpAddress);

      expect(preAuthorizationRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'DELETE',
        entity: 'pre_authorization'
      }));
    });

    it('should throw HttpError if pre-authorization not found', async () => {
      preAuthorizationRepository.findById.mockResolvedValue(null);

      await expect(
        preAuthorizationService.deletePreAuthorization('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
