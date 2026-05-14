/**
 * PACS link controller tests
 *
 * @module tests/modules/pacs-link/controllers
 * @description Tests for PACS link controller operations
 * Per testing.mdc: Controller tests must mock service layer
 */

const pacsLinkController = require('@controllers/pacs-link/pacs-link.controller');
const pacsLinkService = require('@services/pacs-link/pacs-link.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

jest.mock('@services/pacs-link/pacs-link.service');
jest.mock('@lib/response');

describe('PACS Link Controller', () => {
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

  describe('listPacsLinks', () => {
    it('should list PACS links with pagination', async () => {
      const mockData = { pacsLinks: [], pagination: {} };
      pacsLinkService.listPacsLinks.mockResolvedValue(mockData);

      await pacsLinkController.listPacsLinks(mockReq, mockRes);

      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getPacsLinkById', () => {
    it('should get PACS link by id', async () => {
      mockReq.params.id = '123';
      const mockData = { id: '123', url: 'https://pacs.example.com' };
      pacsLinkService.getPacsLinkById.mockResolvedValue(mockData);

      await pacsLinkController.getPacsLinkById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createPacsLink', () => {
    it('should create PACS link', async () => {
      const mockData = { id: '123' };
      pacsLinkService.createPacsLink.mockResolvedValue(mockData);

      await pacsLinkController.createPacsLink(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, expect.any(String), mockData);
    });
  });

  describe('updatePacsLink', () => {
    it('should update PACS link', async () => {
      mockReq.params.id = '123';
      const mockData = { id: '123' };
      pacsLinkService.updatePacsLink.mockResolvedValue(mockData);

      await pacsLinkController.updatePacsLink(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deletePacsLink', () => {
    it('should delete PACS link', async () => {
      mockReq.params.id = '123';
      pacsLinkService.deletePacsLink.mockResolvedValue();

      await pacsLinkController.deletePacsLink(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalled();
    });
  });
});
