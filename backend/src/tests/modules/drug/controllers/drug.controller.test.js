/**
 * Drug controller tests
 *
 * @module tests/modules/drug/controllers
 * @description Tests for drug controller request handlers
 * Per testing.mdc: Controller tests must mock service layer
 */

const drugController = require('@controllers/drug/drug.controller');
const drugService = require('@services/drug/drug.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/drug/drug.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_LIMIT: 20
}));

describe('Drug Controller', () => {
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

  describe('listDrugs', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = {
        drugs: [{ id: '1', name: 'Paracetamol', code: 'PARA500' }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };
      drugService.listDrugs.mockResolvedValue(mockResult);

      await drugController.listDrugs(mockReq, mockRes);

      expect(drugService.listDrugs).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.drug.list.success',
        mockResult.drugs,
        mockResult.pagination
      );
    });

    it('should parse query parameters correctly', async () => {
      mockReq.query = {
        page: '2',
        limit: '50',
        sort_by: 'name',
        order: 'asc',
        tenant_id: '123',
        name: 'Paracetamol',
        code: 'PARA500',
        form: 'Tablet',
        strength: '500mg',
        search: 'para'
      };
      drugService.listDrugs.mockResolvedValue({
        drugs: [],
        pagination: { page: 2, limit: 50, total: 0 }
      });

      await drugController.listDrugs(mockReq, mockRes);

      expect(drugService.listDrugs).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: '123',
          name: 'Paracetamol',
          code: 'PARA500',
          form: 'Tablet',
          strength: '500mg',
          search: 'para'
        }),
        2,
        50,
        'name',
        'asc',
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
    });

    it('should use default page and limit when not provided', async () => {
      drugService.listDrugs.mockResolvedValue({
        drugs: [],
        pagination: {}
      });

      await drugController.listDrugs(mockReq, mockRes);

      expect(drugService.listDrugs).toHaveBeenCalledWith(
        expect.anything(),
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
    });
  });

  describe('getDrugById', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const mockDrug = { id: '123', name: 'Paracetamol', code: 'PARA500' };
      drugService.getDrugById.mockResolvedValue(mockDrug);

      await drugController.getDrugById(mockReq, mockRes);

      expect(drugService.getDrugById).toHaveBeenCalledWith(
        '123',
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.drug.get.success', mockDrug);
    });
  });

  describe('createDrug', () => {
    it('should call service and send success response', async () => {
      const mockData = {
        tenant_id: '123',
        name: 'Paracetamol',
        code: 'PARA500',
        form: 'Tablet',
        strength: '500mg'
      };
      const mockDrug = { id: '456', ...mockData };
      mockReq.body = mockData;
      drugService.createDrug.mockResolvedValue(mockDrug);

      await drugController.createDrug(mockReq, mockRes);

      expect(drugService.createDrug).toHaveBeenCalledWith(
        mockData,
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.drug.create.success', mockDrug);
    });
  });

  describe('updateDrug', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const updateData = { name: 'Paracetamol Updated' };
      const mockDrug = { id: '123', ...updateData };
      mockReq.body = updateData;
      drugService.updateDrug.mockResolvedValue(mockDrug);

      await drugController.updateDrug(mockReq, mockRes);

      expect(drugService.updateDrug).toHaveBeenCalledWith(
        '123',
        updateData,
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.drug.update.success', mockDrug);
    });
  });

  describe('deleteDrug', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      drugService.deleteDrug.mockResolvedValue();

      await drugController.deleteDrug(mockReq, mockRes);

      expect(drugService.deleteDrug).toHaveBeenCalledWith(
        '123',
        'user-123',
        '127.0.0.1',
        mockReq.user
      );
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
