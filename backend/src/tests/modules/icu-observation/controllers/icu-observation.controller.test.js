/**
 * ICU Observation controller tests
 *
 * @module tests/modules/icu-observation/controllers
 * @description Tests for ICU observation controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const icuObservationController = require('@controllers/icu-observation/icu-observation.controller');
const icuObservationService = require('@services/icu-observation/icu-observation.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/icu-observation/icu-observation.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('ICU Observation Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listIcuObservations', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        icu_observations: [{ id: '1', icu_stay_id: '100' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      icuObservationService.listIcuObservations.mockResolvedValue(mockResult);

      await icuObservationController.listIcuObservations(mockReq, mockRes);

      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getIcuObservationById', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const mockObservation = { id: '123', icu_stay_id: '456' };
      icuObservationService.getIcuObservationById.mockResolvedValue(mockObservation);

      await icuObservationController.getIcuObservationById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.icu_observation.get.success', mockObservation);
    });
  });

  describe('createIcuObservation', () => {
    it('should call service and send 201 response', async () => {
      mockReq.body = { icu_stay_id: '123', observation: 'Test' };
      const mockObservation = { id: '456', ...mockReq.body };
      icuObservationService.createIcuObservation.mockResolvedValue(mockObservation);

      await icuObservationController.createIcuObservation(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.icu_observation.create.success', mockObservation);
    });
  });

  describe('updateIcuObservation', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      mockReq.body = { observation: 'Updated' };
      const mockObservation = { id: '123', observation: 'Updated' };
      icuObservationService.updateIcuObservation.mockResolvedValue(mockObservation);

      await icuObservationController.updateIcuObservation(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.icu_observation.update.success', mockObservation);
    });
  });

  describe('deleteIcuObservation', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      icuObservationService.deleteIcuObservation.mockResolvedValue();

      await icuObservationController.deleteIcuObservation(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
