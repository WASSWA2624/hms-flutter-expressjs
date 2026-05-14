/**
 * PACS link service tests
 *
 * @module tests/modules/pacs-link/services
 * @description Tests for PACS link service operations
 * Per testing.mdc: Service tests must mock repository and audit
 */

const pacsLinkService = require('@services/pacs-link/pacs-link.service');
const pacsLinkRepository = require('@repositories/pacs-link/pacs-link.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/pacs-link/pacs-link.repository');
jest.mock('@lib/audit');

describe('PACS Link Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listPacsLinks', () => {
    it('should list PACS links with pagination', async () => {
      const mockData = [{ id: '1', url: 'https://pacs.example.com' }];
      pacsLinkRepository.findMany.mockResolvedValue(mockData);
      pacsLinkRepository.count.mockResolvedValue(1);

      const result = await pacsLinkService.listPacsLinks({}, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(result.pacsLinks).toEqual(mockData);
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1
      });
    });

    it('should apply filters correctly', async () => {
      pacsLinkRepository.findMany.mockResolvedValue([]);
      pacsLinkRepository.count.mockResolvedValue(0);

      await pacsLinkService.listPacsLinks({ imaging_study_id: '123' }, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(pacsLinkRepository.findMany).toHaveBeenCalledWith(
        { imaging_study_id: '123' },
        0,
        20,
        { created_at: 'desc' },
      );
    });
  });

  describe('getPacsLinkById', () => {
    it('should return PACS link when found', async () => {
      const mockData = { id: '123', url: 'https://pacs.example.com' };
      pacsLinkRepository.findById.mockResolvedValue(mockData);

      const result = await pacsLinkService.getPacsLinkById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(mockData);
    });

    it('should throw HttpError when not found', async () => {
      pacsLinkRepository.findById.mockResolvedValue(null);

      await expect(
        pacsLinkService.getPacsLinkById('123', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createPacsLink', () => {
    it('should create PACS link and audit log', async () => {
      const mockData = { imaging_study_id: '456', url: 'https://pacs.example.com' };
      const mockCreated = { id: '123', ...mockData };
      pacsLinkRepository.create.mockResolvedValue(mockCreated);

      const result = await pacsLinkService.createPacsLink(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(mockCreated);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updatePacsLink', () => {
    it('should update PACS link and audit log', async () => {
      const mockBefore = { id: '123', url: 'https://old.example.com' };
      const mockAfter = { id: '123', url: 'https://new.example.com' };
      pacsLinkRepository.findById.mockResolvedValue(mockBefore);
      pacsLinkRepository.update.mockResolvedValue(mockAfter);

      const result = await pacsLinkService.updatePacsLink('123', { url: 'https://new.example.com' }, mockUserId, mockIpAddress);

      expect(result).toEqual(mockAfter);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError when not found', async () => {
      pacsLinkRepository.findById.mockResolvedValue(null);

      await expect(
        pacsLinkService.updatePacsLink('123', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deletePacsLink', () => {
    it('should delete PACS link and audit log', async () => {
      const mockData = { id: '123', url: 'https://pacs.example.com' };
      pacsLinkRepository.findById.mockResolvedValue(mockData);
      pacsLinkRepository.softDelete.mockResolvedValue(mockData);

      await pacsLinkService.deletePacsLink('123', mockUserId, mockIpAddress);

      expect(pacsLinkRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('should throw HttpError when not found', async () => {
      pacsLinkRepository.findById.mockResolvedValue(null);

      await expect(
        pacsLinkService.deletePacsLink('123', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
