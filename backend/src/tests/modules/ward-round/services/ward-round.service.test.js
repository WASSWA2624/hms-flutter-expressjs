/**
 * Ward Round service tests
 */

const wardRoundService = require('../../../../modules/ward-round/services/ward-round.service');
const wardRoundRepository = require('../../../../modules/ward-round/repositories/ward-round.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('../../../../modules/ward-round/repositories/ward-round.repository');
jest.mock('@lib/audit');

describe('Ward Round Service', () => {
  const mockUserId = 'user-id';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listWardRounds', () => {
    it('should list ward rounds with pagination', async () => {
      const mockWardRounds = [{ id: '1' }, { id: '2' }];
      wardRoundRepository.findMany.mockResolvedValue(mockWardRounds);
      wardRoundRepository.count.mockResolvedValue(2);
      const result = await wardRoundService.listWardRounds({}, 1, 10, 'created_at', 'desc', mockUserId, mockIpAddress);
      expect(result.wardRounds).toEqual(mockWardRounds);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 10,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply filters correctly', async () => {
      const filters = { admission_id: 'admission-id' };
      wardRoundRepository.findMany.mockResolvedValue([]);
      wardRoundRepository.count.mockResolvedValue(0);
      await wardRoundService.listWardRounds(filters, 1, 10, null, 'asc', mockUserId, mockIpAddress);
      expect(wardRoundRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining(filters),
        0,
        10,
        { created_at: 'desc' }
      );
    });
  });

  describe('getWardRoundById', () => {
    it('should return ward round by id', async () => {
      const mockWardRound = { id: 'test-id', notes: 'Patient stable' };
      wardRoundRepository.findById.mockResolvedValue(mockWardRound);
      const result = await wardRoundService.getWardRoundById('test-id', mockUserId, mockIpAddress);
      expect(result).toEqual(mockWardRound);
    });

    it('should throw HttpError if not found', async () => {
      wardRoundRepository.findById.mockResolvedValue(null);
      await expect(wardRoundService.getWardRoundById('non-existent', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('createWardRound', () => {
    it('should create ward round and audit log', async () => {
      const data = { admission_id: 'a-id', notes: 'Patient stable' };
      const mockCreated = { id: 'new-id', ...data };
      wardRoundRepository.create.mockResolvedValue(mockCreated);
      const result = await wardRoundService.createWardRound(data, mockUserId, mockIpAddress);
      expect(result).toEqual(mockCreated);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: mockUserId,
        action: 'CREATE',
        entity: 'ward_round',
        entity_id: mockCreated.id,
        diff: { after: mockCreated },
        ip_address: mockIpAddress
      });
    });
  });

  describe('updateWardRound', () => {
    it('should update ward round and create audit log', async () => {
      const before = { id: 'test-id', notes: 'Old notes' };
      const after = { id: 'test-id', notes: 'Updated notes' };
      wardRoundRepository.findById.mockResolvedValue(before);
      wardRoundRepository.update.mockResolvedValue(after);
      const result = await wardRoundService.updateWardRound('test-id', { notes: 'Updated notes' }, mockUserId, mockIpAddress);
      expect(result).toEqual(after);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError if not found', async () => {
      wardRoundRepository.findById.mockResolvedValue(null);
      await expect(wardRoundService.updateWardRound('non-existent', {}, mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('deleteWardRound', () => {
    it('should soft delete ward round and create audit log', async () => {
      const before = { id: 'test-id' };
      wardRoundRepository.findById.mockResolvedValue(before);
      wardRoundRepository.softDelete.mockResolvedValue({});
      await wardRoundService.deleteWardRound('test-id', mockUserId, mockIpAddress);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: mockUserId,
        action: 'DELETE',
        entity: 'ward_round',
        entity_id: 'test-id',
        diff: { before },
        ip_address: mockIpAddress
      });
    });

    it('should throw HttpError if not found', async () => {
      wardRoundRepository.findById.mockResolvedValue(null);
      await expect(wardRoundService.deleteWardRound('non-existent', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });
});
