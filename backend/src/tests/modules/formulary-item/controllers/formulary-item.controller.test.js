const formularyItemController = require('@controllers/formulary-item/formulary-item.controller');
const formularyItemService = require('@services/formulary-item/formulary-item.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/formulary-item/formulary-item.service');
jest.mock('@lib/response');
jest.mock('@config/constants', () => ({ DEFAULT_PAGE: 1, DEFAULT_PAGE_LIMIT: 20 }));

describe('Formulary Item Controller', () => {
  let mockReq, mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = { query: {}, params: {}, body: {}, user: { id: 'user-123' }, ip: '127.0.0.1' };
    mockRes = { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
  });

  describe('listFormularyItems', () => {
    it('should call service and send paginated response', async () => {
      const mockResult = { formularyItems: [{ id: '1' }], pagination: { page: 1, limit: 20, total: 1 } };
      formularyItemService.listFormularyItems.mockResolvedValue(mockResult);

      await formularyItemController.listFormularyItems(mockReq, mockRes);
      expect(sendPaginated).toHaveBeenCalledWith(mockRes, 'messages.formulary_item.list.success', mockResult.formularyItems, mockResult.pagination);
    });
  });

  describe('getFormularyItemById', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const mock = { id: '123' };
      formularyItemService.getFormularyItemById.mockResolvedValue(mock);

      await formularyItemController.getFormularyItemById(mockReq, mockRes);
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.formulary_item.get.success', mock);
    });
  });

  describe('createFormularyItem', () => {
    it('should call service and send success response', async () => {
      const mockData = { drug_id: '456', is_active: true };
      const mock = { id: '123', ...mockData };
      mockReq.body = mockData;
      formularyItemService.createFormularyItem.mockResolvedValue(mock);

      await formularyItemController.createFormularyItem(mockReq, mockRes);
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.formulary_item.create.success', mock);
    });
  });

  describe('updateFormularyItem', () => {
    it('should call service and send success response', async () => {
      mockReq.params.id = '123';
      const updateData = { is_active: false };
      const mock = { id: '123', ...updateData };
      mockReq.body = updateData;
      formularyItemService.updateFormularyItem.mockResolvedValue(mock);

      await formularyItemController.updateFormularyItem(mockReq, mockRes);
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.formulary_item.update.success', mock);
    });
  });

  describe('deleteFormularyItem', () => {
    it('should call service and send no content response', async () => {
      mockReq.params.id = '123';
      formularyItemService.deleteFormularyItem.mockResolvedValue();

      await formularyItemController.deleteFormularyItem(mockReq, mockRes);
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
