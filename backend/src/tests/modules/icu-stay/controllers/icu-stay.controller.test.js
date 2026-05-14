/**
 * ICU Stay controller tests
 *
 * @module tests/modules/icu-stay/controllers
 * @description Tests for ICU stay controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const icuStayController = require('@controllers/icu-stay/icu-stay.controller');
const icuStayService = require('@services/icu-stay/icu-stay.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/icu-stay/icu-stay.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('ICU Stay Controller', () => {
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

  describe('listIcuStays', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        icu_stays: [{ id: '1', admission_id: '100' }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };
      icuStayService.listIcuStays.mockResolvedValue(mockResult);

      await icuStayController.listIcuStays(mockReq, mockRes);

      expect(icuStayService.listIcuStays).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.icu_stay.list.success',
        mockResult.icu_stays,
        mockResult.pagination
      );
    });

    it('should parse query parameters correctly', async () => {
      mockReq.query = {
        page: '2',
        limit: '50',
        sort_by: 'started_at',
        order: 'asc',
        admission_id: '123',
        started_at_from: '2024-01-01T00:00:00.000Z',
        started_at_to: '2024-01-31T23:59:59.999Z',
        is_active: 'true'
      };
      icuStayService.listIcuStays.mockResolvedValue({
        icu_stays: [],
        pagination: { page: 2, limit: 50, total: 0 }
      });

      await icuStayController.listIcuStays(mockReq, mockRes);

      expect(icuStayService.listIcuStays).toHaveBeenCalledWith(
        expect.objectContaining({
          admission_id: '123',
          started_at_from: '2024-01-01T00:00:00.000Z',
          started_at_to: '2024-01-31T23:59:59.999Z',
          is_active: 'true'
        }),
        2,
        50,
        'started_at',
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });

    it('should use default page and limit when not provided', async () => {
      icuStayService.listIcuStays.mockResolvedValue({
        icu_stays: [],
        pagination: {}
      });

      await icuStayController.listIcuStays(mockReq, mockRes);

      expect(icuStayService.listIcuStays).toHaveBeenCalledWith(
        expect.anything(),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1'
      );
    });
  });

  describe('getIcuStayById', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const mockIcuStay = { id: '123', admission_id: '456' };
      icuStayService.getIcuStayById.mockResolvedValue(mockIcuStay);

      await icuStayController.getIcuStayById(mockReq, mockRes);

      expect(icuStayService.getIcuStayById).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.icu_stay.get.success', mockIcuStay);
    });
  });

  describe('createIcuStay', () => {
    it('should call service and send 201 response', async () => {
      mockReq.body = { admission_id: '123', started_at: '2024-01-01T10:00:00.000Z' };
      const mockIcuStay = { id: '456', ...mockReq.body };
      icuStayService.createIcuStay.mockResolvedValue(mockIcuStay);

      await icuStayController.createIcuStay(mockReq, mockRes);

      expect(icuStayService.createIcuStay).toHaveBeenCalledWith(mockReq.body, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.icu_stay.create.success', mockIcuStay);
    });
  });

  describe('updateIcuStay', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      mockReq.body = { ended_at: '2024-01-02T10:00:00.000Z' };
      const mockIcuStay = { id: '123', admission_id: '456', ...mockReq.body };
      icuStayService.updateIcuStay.mockResolvedValue(mockIcuStay);

      await icuStayController.updateIcuStay(mockReq, mockRes);

      expect(icuStayService.updateIcuStay).toHaveBeenCalledWith('123', mockReq.body, 'user-123', '127.0.0.1');
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.icu_stay.update.success', mockIcuStay);
    });
  });

  describe('deleteIcuStay', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      icuStayService.deleteIcuStay.mockResolvedValue();

      await icuStayController.deleteIcuStay(mockReq, mockRes);

      expect(icuStayService.deleteIcuStay).toHaveBeenCalledWith('123', 'user-123', '127.0.0.1');
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
