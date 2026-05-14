/**
 * Ward Round controller tests
 */

const wardRoundController = require('../../../../modules/ward-round/controllers/ward-round.controller');
const wardRoundService = require('../../../../modules/ward-round/services/ward-round.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('../../../../modules/ward-round/services/ward-round.service');
jest.mock('@lib/response');

describe('Ward Round Controller', () => {
  let mockReq, mockRes;

  beforeEach(() => {
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-id' },
      ip: '127.0.0.1'
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
    jest.clearAllMocks();
  });

  describe('listWardRounds', () => {
    it('should list ward rounds', async () => {
      const mockResult = {
        wardRounds: [{ id: '1' }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };
      mockReq.query = { page: '1', limit: '20' };
      wardRoundService.listWardRounds.mockResolvedValue(mockResult);
      await wardRoundController.listWardRounds(mockReq, mockRes);
      expect(sendPaginated).toHaveBeenCalledWith(mockRes, 'messages.ward_round.list.success', mockResult.wardRounds, mockResult.pagination);
    });
  });

  describe('getWardRoundById', () => {
    it('should return ward round by id', async () => {
      const mockWardRound = { id: 'test-id', notes: 'Patient stable' };
      mockReq.params = { id: 'test-id' };
      wardRoundService.getWardRoundById.mockResolvedValue(mockWardRound);
      await wardRoundController.getWardRoundById(mockReq, mockRes);
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.ward_round.get.success', mockWardRound);
    });
  });

  describe('createWardRound', () => {
    it('should create ward round', async () => {
      const data = { admission_id: 'a-id', notes: 'Patient stable' };
      const mockCreated = { id: 'new-id', ...data };
      mockReq.body = data;
      wardRoundService.createWardRound.mockResolvedValue(mockCreated);
      await wardRoundController.createWardRound(mockReq, mockRes);
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.ward_round.create.success', mockCreated);
    });
  });

  describe('updateWardRound', () => {
    it('should update ward round', async () => {
      const mockUpdated = { id: 'test-id', notes: 'Updated notes' };
      mockReq.params = { id: 'test-id' };
      mockReq.body = { notes: 'Updated notes' };
      wardRoundService.updateWardRound.mockResolvedValue(mockUpdated);
      await wardRoundController.updateWardRound(mockReq, mockRes);
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.ward_round.update.success', mockUpdated);
    });
  });

  describe('deleteWardRound', () => {
    it('should delete ward round', async () => {
      mockReq.params = { id: 'test-id' };
      wardRoundService.deleteWardRound.mockResolvedValue();
      await wardRoundController.deleteWardRound(mockReq, mockRes);
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
