/**
 * Imaging study controller tests
 *
 * @module tests/modules/imaging-study/controllers
 * @description Tests for imaging study controller operations
 * Per testing.mdc: Controller tests must mock service layer
 */

const imagingStudyController = require('@controllers/imaging-study/imaging-study.controller');
const imagingStudyService = require('@services/imaging-study/imaging-study.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/imaging-study/imaging-study.service');
jest.mock('@lib/response');

describe('Imaging Study Controller', () => {
  let mockReq, mockRes;

  beforeEach(() => {
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };
    jest.clearAllMocks();
  });

  describe('listImagingStudies', () => {
    it('should list imaging studies with pagination', async () => {
      const mockData = { imagingStudies: [], pagination: {} };
      imagingStudyService.listImagingStudies.mockResolvedValue(mockData);

      await imagingStudyController.listImagingStudies(mockReq, mockRes);

      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getImagingStudyById', () => {
    it('should get imaging study by id', async () => {
      mockReq.params.id = '123';
      const mockData = { id: '123', modality: 'XRAY' };
      imagingStudyService.getImagingStudyById.mockResolvedValue(mockData);

      await imagingStudyController.getImagingStudyById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createImagingStudy', () => {
    it('should create imaging study', async () => {
      const mockData = { id: '123' };
      imagingStudyService.createImagingStudy.mockResolvedValue(mockData);

      await imagingStudyController.createImagingStudy(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, expect.any(String), mockData);
    });
  });

  describe('updateImagingStudy', () => {
    it('should update imaging study', async () => {
      mockReq.params.id = '123';
      const mockData = { id: '123' };
      imagingStudyService.updateImagingStudy.mockResolvedValue(mockData);

      await imagingStudyController.updateImagingStudy(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteImagingStudy', () => {
    it('should delete imaging study', async () => {
      mockReq.params.id = '123';
      imagingStudyService.deleteImagingStudy.mockResolvedValue();

      await imagingStudyController.deleteImagingStudy(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalled();
    });
  });
});
