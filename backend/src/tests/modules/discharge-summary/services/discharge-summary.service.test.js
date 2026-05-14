/**
 * Discharge summary service tests
 *
 * @module tests/modules/discharge-summary/services
 * Per testing.mdc: Mock all repository and external dependencies
 */

const { HttpError } = require('@lib/errors');

jest.mock('@repositories/discharge-summary/discharge-summary.repository');
jest.mock('@lib/audit');

const dischargeSummaryRepository = require('@repositories/discharge-summary/discharge-summary.repository');
const { createAuditLog } = require('@lib/audit');
const dischargeSummaryService = require('@services/discharge-summary/discharge-summary.service');

describe('Discharge Summary Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  describe('listDischargeSummaries', () => {
    it('should list with pagination', async () => {
      const mockRecords = [{ id: 'discharge-1' }, { id: 'discharge-2' }];
      dischargeSummaryRepository.findMany.mockResolvedValue(mockRecords);
      dischargeSummaryRepository.count.mockResolvedValue(10);

      const result = await dischargeSummaryService.listDischargeSummaries(
        {},
        1,
        20,
        'created_at',
        'desc',
        'user-123',
        '127.0.0.1'
      );

      expect(result.dischargeSummaries).toEqual(mockRecords);
      expect(result.pagination.total).toBe(10);
    });
  });

  describe('getDischargeSummaryById', () => {
    it('should get by ID', async () => {
      const mockRecord = { id: 'discharge-123', summary: 'Summary' };
      dischargeSummaryRepository.findById.mockResolvedValue(mockRecord);

      const result = await dischargeSummaryService.getDischargeSummaryById(
        'discharge-123',
        'user-123',
        '127.0.0.1'
      );

      expect(result).toEqual(mockRecord);
    });

    it('should throw HttpError if not found', async () => {
      dischargeSummaryRepository.findById.mockResolvedValue(null);

      await expect(
        dischargeSummaryService.getDischargeSummaryById('discharge-123', 'user-123', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createDischargeSummary', () => {
    it('should create and audit log', async () => {
      const mockData = { admission_id: 'admission-123', summary: 'Summary', status: 'COMPLETED' };
      const mockRecord = { id: 'discharge-123', ...mockData };
      dischargeSummaryRepository.create.mockResolvedValue(mockRecord);

      const result = await dischargeSummaryService.createDischargeSummary(
        mockData,
        'user-123',
        '127.0.0.1'
      );

      expect(result).toEqual(mockRecord);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'CREATE',
          entity: 'discharge_summary'
        })
      );
    });
  });

  describe('updateDischargeSummary', () => {
    it('should update and audit log', async () => {
      const mockBefore = { id: 'discharge-123', summary: 'Old summary' };
      const mockAfter = { id: 'discharge-123', summary: 'New summary' };
      dischargeSummaryRepository.findById.mockResolvedValue(mockBefore);
      dischargeSummaryRepository.update.mockResolvedValue(mockAfter);

      const result = await dischargeSummaryService.updateDischargeSummary(
        'discharge-123',
        { summary: 'New summary' },
        'user-123',
        '127.0.0.1'
      );

      expect(result).toEqual(mockAfter);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('deleteDischargeSummary', () => {
    it('should delete and audit log', async () => {
      const mockRecord = { id: 'discharge-123', summary: 'Summary' };
      dischargeSummaryRepository.findById.mockResolvedValue(mockRecord);
      dischargeSummaryRepository.softDelete.mockResolvedValue(mockRecord);

      await dischargeSummaryService.deleteDischargeSummary('discharge-123', 'user-123', '127.0.0.1');

      expect(dischargeSummaryRepository.softDelete).toHaveBeenCalled();
      expect(createAuditLog).toHaveBeenCalled();
    });
  });
});
