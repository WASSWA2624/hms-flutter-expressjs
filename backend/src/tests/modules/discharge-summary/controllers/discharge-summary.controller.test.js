/**
 * Discharge summary controller tests
 *
 * @module tests/modules/discharge-summary/controllers
 * Per testing.mdc: Mock all service dependencies
 */

jest.mock('@services/discharge-summary/discharge-summary.service');
jest.mock('@lib/response');

const dischargeSummaryService = require('@services/discharge-summary/discharge-summary.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const dischargeSummaryController = require('@controllers/discharge-summary/discharge-summary.controller');

describe('Discharge Summary Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };
  });

  describe('listDischargeSummaries', () => {
    it('should list successfully', async () => {
      const mockResult = {
        dischargeSummaries: [{ id: 'discharge-1' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      dischargeSummaryService.listDischargeSummaries.mockResolvedValue(mockResult);

      req.query = { page: '1', limit: '20' };

      await dischargeSummaryController.listDischargeSummaries(req, res);

      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getDischargeSummaryById', () => {
    it('should get by ID successfully', async () => {
      const mockRecord = { id: 'discharge-123', summary: 'Summary' };
      dischargeSummaryService.getDischargeSummaryById.mockResolvedValue(mockRecord);

      req.params = { id: 'discharge-123' };

      await dischargeSummaryController.getDischargeSummaryById(req, res);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createDischargeSummary', () => {
    it('should create successfully', async () => {
      const mockRecord = { id: 'discharge-123' };
      dischargeSummaryService.createDischargeSummary.mockResolvedValue(mockRecord);

      req.body = { admission_id: 'admission-123', summary: 'Summary', status: 'COMPLETED' };

      await dischargeSummaryController.createDischargeSummary(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.discharge_summary.create.success',
        mockRecord
      );
    });
  });

  describe('updateDischargeSummary', () => {
    it('should update successfully', async () => {
      const mockRecord = { id: 'discharge-123', summary: 'Updated' };
      dischargeSummaryService.updateDischargeSummary.mockResolvedValue(mockRecord);

      req.params = { id: 'discharge-123' };
      req.body = { summary: 'Updated' };

      await dischargeSummaryController.updateDischargeSummary(req, res);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteDischargeSummary', () => {
    it('should delete successfully', async () => {
      dischargeSummaryService.deleteDischargeSummary.mockResolvedValue();

      req.params = { id: 'discharge-123' };

      await dischargeSummaryController.deleteDischargeSummary(req, res);

      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
