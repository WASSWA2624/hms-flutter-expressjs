/**
 * Transfer request service tests
 *
 * @module tests/modules/transfer-request/services
 * @description Tests for transfer request service business logic
 * Per testing.mdc: Service tests must mock repository and audit functions
 */

const transferRequestService = require('@services/transfer-request/transfer-request.service');
const transferRequestRepository = require('@repositories/transfer-request/transfer-request.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/transfer-request/transfer-request.repository');
jest.mock('@lib/audit');

describe('Transfer Request Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  describe('listTransferRequests', () => {
    it('should list transfer requests with pagination', async () => {
      const mockTransferRequests = [
        { id: '1', admission_id: 'adm-1', status: 'REQUESTED' }
      ];
      transferRequestRepository.findMany.mockResolvedValue(mockTransferRequests);
      transferRequestRepository.count.mockResolvedValue(1);

      const result = await transferRequestService.listTransferRequests(
        {},
        1,
        20,
        'created_at',
        'desc',
        mockUserId,
        mockIpAddress
      );

      expect(result.transferRequests).toEqual(mockTransferRequests);
      expect(result.pagination.total).toBe(1);
      expect(result.pagination.page).toBe(1);
      expect(result.pagination.limit).toBe(20);
      expect(result.pagination.totalPages).toBe(1);
      expect(result.pagination.hasNextPage).toBe(false);
      expect(result.pagination.hasPreviousPage).toBe(false);
      expect(transferRequestRepository.findMany).toHaveBeenCalled();
      expect(transferRequestRepository.count).toHaveBeenCalled();
    });

    it('should handle admission_id filter', async () => {
      transferRequestRepository.findMany.mockResolvedValue([]);
      transferRequestRepository.count.mockResolvedValue(0);

      await transferRequestService.listTransferRequests(
        { admission_id: 'adm-123' },
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress
      );

      expect(transferRequestRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ admission_id: 'adm-123' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle status filter', async () => {
      transferRequestRepository.findMany.mockResolvedValue([]);
      transferRequestRepository.count.mockResolvedValue(0);

      await transferRequestService.listTransferRequests(
        { status: 'APPROVED' },
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress
      );

      expect(transferRequestRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'APPROVED' }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should handle ward filters', async () => {
      transferRequestRepository.findMany.mockResolvedValue([]);
      transferRequestRepository.count.mockResolvedValue(0);

      await transferRequestService.listTransferRequests(
        { from_ward_id: 'ward-1', to_ward_id: 'ward-2' },
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress
      );

      expect(transferRequestRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          from_ward_id: 'ward-1',
          to_ward_id: 'ward-2'
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly with multiple pages', async () => {
      transferRequestRepository.findMany.mockResolvedValue([]);
      transferRequestRepository.count.mockResolvedValue(45);

      const result = await transferRequestService.listTransferRequests(
        {},
        2,
        20,
        'created_at',
        'desc',
        mockUserId,
        mockIpAddress
      );

      expect(result.pagination.totalPages).toBe(3);
      expect(result.pagination.hasNextPage).toBe(true);
      expect(result.pagination.hasPreviousPage).toBe(true);
    });

    it('should use default sort order when sortBy is not provided', async () => {
      transferRequestRepository.findMany.mockResolvedValue([]);
      transferRequestRepository.count.mockResolvedValue(0);

      await transferRequestService.listTransferRequests(
        {},
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress
      );

      expect(transferRequestRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        { created_at: 'desc' }
      );
    });

    it('should throw HttpError on repository error', async () => {
      transferRequestRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        transferRequestService.listTransferRequests({}, 1, 20, null, 'asc', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getTransferRequestById', () => {
    it('should get transfer request by id', async () => {
      const mockTransferRequest = {
        id: '123',
        admission_id: 'adm-123',
        status: 'REQUESTED'
      };
      transferRequestRepository.findById.mockResolvedValue(mockTransferRequest);

      const result = await transferRequestService.getTransferRequestById('123', mockUserId, mockIpAddress);

      expect(result).toEqual(mockTransferRequest);
      expect(transferRequestRepository.findById).toHaveBeenCalledWith('123');
    });

    it('should throw HttpError if transfer request not found', async () => {
      transferRequestRepository.findById.mockResolvedValue(null);

      await expect(
        transferRequestService.getTransferRequestById('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      transferRequestRepository.findById.mockRejectedValue(new Error('DB Error'));

      await expect(
        transferRequestService.getTransferRequestById('123', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createTransferRequest', () => {
    it('should create transfer request and log audit', async () => {
      const mockData = {
        admission_id: 'adm-123',
        from_ward_id: 'ward-1',
        to_ward_id: 'ward-2',
        status: 'REQUESTED'
      };
      const mockTransferRequest = { id: '456', ...mockData };
      transferRequestRepository.create.mockResolvedValue(mockTransferRequest);

      const result = await transferRequestService.createTransferRequest(
        mockData,
        mockUserId,
        mockIpAddress
      );

      expect(result).toEqual(mockTransferRequest);
      expect(transferRequestRepository.create).toHaveBeenCalledWith(
        expect.objectContaining(mockData)
      );
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: mockUserId,
          action: 'CREATE',
          entity: 'transfer_request',
          entity_id: '456',
          ip_address: mockIpAddress
        })
      );
    });

    it('should set default status to REQUESTED if not provided', async () => {
      const mockData = {
        admission_id: 'adm-123',
        from_ward_id: 'ward-1',
        to_ward_id: 'ward-2'
      };
      const mockTransferRequest = { id: '456', ...mockData, status: 'REQUESTED' };
      transferRequestRepository.create.mockResolvedValue(mockTransferRequest);

      await transferRequestService.createTransferRequest(mockData, mockUserId, mockIpAddress);

      expect(transferRequestRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'REQUESTED' })
      );
    });

    it('should set default requested_at if not provided', async () => {
      const mockData = {
        admission_id: 'adm-123',
        from_ward_id: 'ward-1',
        to_ward_id: 'ward-2'
      };
      const mockTransferRequest = { id: '456', ...mockData };
      transferRequestRepository.create.mockResolvedValue(mockTransferRequest);

      await transferRequestService.createTransferRequest(mockData, mockUserId, mockIpAddress);

      expect(transferRequestRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({ requested_at: expect.any(String) })
      );
    });

    it('should throw HttpError on repository error', async () => {
      transferRequestRepository.create.mockRejectedValue(new Error('DB Error'));

      await expect(
        transferRequestService.createTransferRequest({}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('updateTransferRequest', () => {
    it('should update transfer request and log audit', async () => {
      const mockBefore = {
        id: '123',
        admission_id: 'adm-123',
        status: 'REQUESTED'
      };
      const mockAfter = {
        id: '123',
        admission_id: 'adm-123',
        status: 'APPROVED'
      };
      transferRequestRepository.findById.mockResolvedValue(mockBefore);
      transferRequestRepository.update.mockResolvedValue(mockAfter);

      const result = await transferRequestService.updateTransferRequest(
        '123',
        { status: 'APPROVED' },
        mockUserId,
        mockIpAddress
      );

      expect(result).toEqual(mockAfter);
      expect(transferRequestRepository.update).toHaveBeenCalledWith('123', { status: 'APPROVED' });
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: mockUserId,
          action: 'UPDATE',
          entity: 'transfer_request',
          entity_id: '123',
          diff: { before: mockBefore, after: mockAfter },
          ip_address: mockIpAddress
        })
      );
    });

    it('should throw HttpError if transfer request not found', async () => {
      transferRequestRepository.findById.mockResolvedValue(null);

      await expect(
        transferRequestService.updateTransferRequest('nonexistent', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      const mockBefore = { id: '123', status: 'REQUESTED' };
      transferRequestRepository.findById.mockResolvedValue(mockBefore);
      transferRequestRepository.update.mockRejectedValue(new Error('DB Error'));

      await expect(
        transferRequestService.updateTransferRequest('123', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteTransferRequest', () => {
    it('should soft delete transfer request and log audit', async () => {
      const mockTransferRequest = {
        id: '123',
        admission_id: 'adm-123',
        status: 'REQUESTED'
      };
      transferRequestRepository.findById.mockResolvedValue(mockTransferRequest);
      transferRequestRepository.softDelete.mockResolvedValue({
        ...mockTransferRequest,
        deleted_at: new Date()
      });

      await transferRequestService.deleteTransferRequest('123', mockUserId, mockIpAddress);

      expect(transferRequestRepository.softDelete).toHaveBeenCalledWith('123');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: mockUserId,
          action: 'DELETE',
          entity: 'transfer_request',
          entity_id: '123',
          diff: { before: mockTransferRequest },
          ip_address: mockIpAddress
        })
      );
    });

    it('should throw HttpError if transfer request not found', async () => {
      transferRequestRepository.findById.mockResolvedValue(null);

      await expect(
        transferRequestService.deleteTransferRequest('nonexistent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      const mockTransferRequest = { id: '123', status: 'REQUESTED' };
      transferRequestRepository.findById.mockResolvedValue(mockTransferRequest);
      transferRequestRepository.softDelete.mockRejectedValue(new Error('DB Error'));

      await expect(
        transferRequestService.deleteTransferRequest('123', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
