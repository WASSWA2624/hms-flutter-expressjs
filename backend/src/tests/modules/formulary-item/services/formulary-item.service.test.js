const formularyItemService = require('@services/formulary-item/formulary-item.service');
const formularyItemRepository = require('@repositories/formulary-item/formulary-item.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/formulary-item/formulary-item.repository');
jest.mock('@lib/audit');

describe('Formulary Item Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  describe('listFormularyItems', () => {
    it('should list formulary items with pagination', async () => {
      formularyItemRepository.findMany.mockResolvedValue([{ id: '1' }]);
      formularyItemRepository.count.mockResolvedValue(1);

      const result = await formularyItemService.listFormularyItems({}, 1, 20, null, 'asc', mockUserId, mockIpAddress);
      expect(result.formularyItems).toHaveLength(1);
      expect(result.pagination.total).toBe(1);
    });
  });

  describe('getFormularyItemById', () => {
    it('should get formulary item by id', async () => {
      const mock = { id: '123' };
      formularyItemRepository.findById.mockResolvedValue(mock);
      expect(await formularyItemService.getFormularyItemById('123', mockUserId, mockIpAddress)).toEqual(mock);
    });

    it('should throw if not found', async () => {
      formularyItemRepository.findById.mockResolvedValue(null);
      await expect(formularyItemService.getFormularyItemById('123', mockUserId, mockIpAddress)).rejects.toThrow(HttpError);
    });
  });

  describe('createFormularyItem', () => {
    it('should create formulary item and log audit', async () => {
      const mock = { id: '123', drug_id: '456', is_active: true };
      formularyItemRepository.create.mockResolvedValue(mock);

      const result = await formularyItemService.createFormularyItem({ drug_id: '456' }, mockUserId, mockIpAddress);
      expect(result).toEqual(mock);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({ action: 'CREATE', entity: 'formulary_item' }));
    });
  });

  describe('updateFormularyItem', () => {
    it('should update formulary item and log audit', async () => {
      const mockBefore = { id: '123', is_active: true };
      const mockAfter = { id: '123', is_active: false };
      formularyItemRepository.findById.mockResolvedValue(mockBefore);
      formularyItemRepository.update.mockResolvedValue(mockAfter);

      const result = await formularyItemService.updateFormularyItem('123', { is_active: false }, mockUserId, mockIpAddress);
      expect(result).toEqual(mockAfter);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({ action: 'UPDATE' }));
    });
  });

  describe('deleteFormularyItem', () => {
    it('should soft delete formulary item and log audit', async () => {
      const mock = { id: '123' };
      formularyItemRepository.findById.mockResolvedValue(mock);
      formularyItemRepository.softDelete.mockResolvedValue({ id: '123', deleted_at: new Date() });

      await formularyItemService.deleteFormularyItem('123', mockUserId, mockIpAddress);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({ action: 'DELETE' }));
    });
  });
});
