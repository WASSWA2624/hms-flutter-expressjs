/**
 * Imaging study service tests
 *
 * @module tests/modules/imaging-study/services
 * @description Tests for imaging study service operations
 * Per testing.mdc: Service tests must mock repository and audit
 */

const imagingStudyService = require('@services/imaging-study/imaging-study.service');
const imagingStudyRepository = require('@repositories/imaging-study/imaging-study.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/imaging-study/imaging-study.repository');
jest.mock('@lib/audit');

describe('Imaging Study Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listImagingStudies', () => {
    it('should list imaging studies with pagination', async () => {
      const mockData = [{ id: '1', modality: 'XRAY' }];
      imagingStudyRepository.findMany.mockResolvedValue(mockData);
      imagingStudyRepository.count.mockResolvedValue(1);

      const result = await imagingStudyService.listImagingStudies({}, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(result.imagingStudies).toEqual(mockData);
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1
      });
    });

    it('should apply filters correctly', async () => {
      imagingStudyRepository.findMany.mockResolvedValue([]);
      imagingStudyRepository.count.mockResolvedValue(0);

      await imagingStudyService.listImagingStudies({ modality: 'CT' }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(imagingStudyRepository.findMany).toHaveBeenCalledWith(
        { modality: 'CT' },
        0,
        20,
        { created_at: 'desc' },
      );
    });
  });

  describe('getImagingStudyById', () => {
    it('should return imaging study when found', async () => {
      const mockData = { id: '123', modality: 'XRAY' };
      imagingStudyRepository.findById.mockResolvedValue(mockData);

      const result = await imagingStudyService.getImagingStudyById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(mockData);
    });

    it('should throw HttpError when not found', async () => {
      imagingStudyRepository.findById.mockResolvedValue(null);

      await expect(
        imagingStudyService.getImagingStudyById('123', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createImagingStudy', () => {
    it('should create imaging study and audit log', async () => {
      const mockData = { radiology_order_id: '456', modality: 'XRAY' };
      const mockCreated = { id: '123', ...mockData };
      imagingStudyRepository.create.mockResolvedValue(mockCreated);

      const result = await imagingStudyService.createImagingStudy(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(mockCreated);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateImagingStudy', () => {
    it('should update imaging study and audit log', async () => {
      const mockBefore = { id: '123', modality: 'XRAY' };
      const mockAfter = { id: '123', modality: 'CT' };
      imagingStudyRepository.findById.mockResolvedValue(mockBefore);
      imagingStudyRepository.update.mockResolvedValue(mockAfter);

      const result = await imagingStudyService.updateImagingStudy('123', { modality: 'CT' }, mockUserId, mockIpAddress);

      expect(result).toEqual(mockAfter);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError when not found', async () => {
      imagingStudyRepository.findById.mockResolvedValue(null);

      await expect(
        imagingStudyService.updateImagingStudy('123', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteImagingStudy', () => {
    it('should delete imaging study and audit log', async () => {
      const mockData = { id: '123', modality: 'XRAY' };
      imagingStudyRepository.findById.mockResolvedValue(mockData);
      imagingStudyRepository.softDelete.mockResolvedValue(mockData);

      await imagingStudyService.deleteImagingStudy('123', mockUserId, mockIpAddress);

      expect(imagingStudyRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError when not found', async () => {
      imagingStudyRepository.findById.mockResolvedValue(null);

      await expect(
        imagingStudyService.deleteImagingStudy('123', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
