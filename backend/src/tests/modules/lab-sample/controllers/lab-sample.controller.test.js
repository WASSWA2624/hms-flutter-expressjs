/**
 * Lab sample controller tests
 *
 * @module tests/modules/lab-sample/controllers
 * @description Tests for lab sample controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const labSampleController = require('@controllers/lab-sample/lab-sample.controller');
const labSampleService = require('@services/lab-sample/lab-sample.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/lab-sample/lab-sample.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Lab Sample Controller', () => {
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

  describe('listLabSamples', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        labSamples: [{ id: '1', lab_order_id: '456', status: 'PENDING' }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };
      labSampleService.listLabSamples.mockResolvedValue(mockResult);

      await labSampleController.listLabSamples(mockReq, mockRes);

      expect(labSampleService.listLabSamples).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.lab_sample.list.success',
        mockResult.labSamples,
        mockResult.pagination
      );
    });

    it('should parse query parameters correctly', async () => {
      mockReq.query = {
        page: '2',
        limit: '50',
        sort_by: 'status',
        order: 'asc',
        lab_order_id: '456',
        status: 'PENDING'
      };
      labSampleService.listLabSamples.mockResolvedValue({
        labSamples: [],
        pagination: { page: 2, limit: 50, total: 0 }
      });

      await labSampleController.listLabSamples(mockReq, mockRes);

      expect(labSampleService.listLabSamples).toHaveBeenCalledWith(
        expect.objectContaining({
          lab_order_id: '456',
          status: 'PENDING'
        }),
        2,
        50,
        'status',
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });

    it('should use default page and limit when not provided', async () => {
      labSampleService.listLabSamples.mockResolvedValue({
        labSamples: [],
        pagination: {}
      });

      await labSampleController.listLabSamples(mockReq, mockRes);

      expect(labSampleService.listLabSamples).toHaveBeenCalledWith(
        expect.objectContaining({ lab_order_id: undefined, status: undefined }),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getLabSampleById', () => {
    it('should call service and send success response', async () => {
      const mockLabSample = { id: '123', lab_order_id: '456', status: 'PENDING' };
      mockReq.params.id = '123';
      labSampleService.getLabSampleById.mockResolvedValue(mockLabSample);

      await labSampleController.getLabSampleById(mockReq, mockRes);

      expect(labSampleService.getLabSampleById).toHaveBeenCalledWith(
        '123',
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.lab_sample.get.success',
        mockLabSample
      );
    });
  });

  describe('createLabSample', () => {
    it('should call service and send created response', async () => {
      const mockData = {
        lab_order_id: '456',
        status: 'PENDING',
        collected_at: null,
        received_at: null
      };
      const mockLabSample = { id: '123', ...mockData };
      mockReq.body = mockData;
      labSampleService.createLabSample.mockResolvedValue(mockLabSample);

      await labSampleController.createLabSample(mockReq, mockRes);

      expect(labSampleService.createLabSample).toHaveBeenCalledWith(
        mockData,
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.lab_sample.create.success',
        mockLabSample
      );
    });
  });

  describe('updateLabSample', () => {
    it('should call service and send success response', async () => {
      const mockData = { status: 'COLLECTED' };
      const mockLabSample = { id: '123', lab_order_id: '456', ...mockData };
      mockReq.params.id = '123';
      mockReq.body = mockData;
      labSampleService.updateLabSample.mockResolvedValue(mockLabSample);

      await labSampleController.updateLabSample(mockReq, mockRes);

      expect(labSampleService.updateLabSample).toHaveBeenCalledWith(
        '123',
        mockData,
        'user-123',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.lab_sample.update.success',
        mockLabSample
      );
    });
  });

  describe('deleteLabSample', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      labSampleService.deleteLabSample.mockResolvedValue();

      await labSampleController.deleteLabSample(mockReq, mockRes);

      expect(labSampleService.deleteLabSample).toHaveBeenCalledWith(
        '123',
        'user-123',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
