/**
 * Asset service log service tests
 *
 * @module tests/modules/asset-service-log/services
 * @description Tests for asset service log service business logic layer
 */

const assetServiceLogService = require('../../../../modules/asset-service-log/services/asset-service-log.service');
const assetServiceLogRepository = require('../../../../modules/asset-service-log/repositories/asset-service-log.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock repository and audit
jest.mock('../../../../modules/asset-service-log/repositories/asset-service-log.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null)
}));

describe('Asset Service Log Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listAssetServiceLogs', () => {
    it('should list asset service logs with pagination', async () => {
      const mockLogs = [
        { id: '1', asset_id: 'asset-1', notes: 'Log 1' },
        { id: '2', asset_id: 'asset-1', notes: 'Log 2' }
      ];

      assetServiceLogRepository.findMany.mockResolvedValue(mockLogs);
      assetServiceLogRepository.count.mockResolvedValue(2);

      const result = await assetServiceLogService.listAssetServiceLogs(
        {},
        1,
        20,
        'created_at',
        'desc',
        mockUserId,
        mockIpAddress
      );

      expect(result.assetServiceLogs).toEqual([
        expect.objectContaining(mockLogs[0]),
        expect.objectContaining(mockLogs[1])
      ]);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply filters correctly', async () => {
      assetServiceLogRepository.findMany.mockResolvedValue([]);
      assetServiceLogRepository.count.mockResolvedValue(0);

      const filters = {
        asset_id: '123',
        search: 'maintenance'
      };

      await assetServiceLogService.listAssetServiceLogs(
        filters,
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress
      );

      expect(assetServiceLogRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          asset_id: '123',
          OR: expect.arrayContaining([
            { human_friendly_id: { contains: 'MAINTENANCE' } },
            { notes: { contains: 'maintenance' } },
            { asset: { name: { contains: 'maintenance' } } },
            { asset: { asset_tag: { contains: 'maintenance' } } }
          ])
        }),
        0,
        20,
        { created_at: 'asc' },
        expect.any(Object)
      );
    });

    it('should throw HttpError on repository error', async () => {
      assetServiceLogRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        assetServiceLogService.listAssetServiceLogs({}, 1, 20, null, 'asc', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getAssetServiceLogById', () => {
    it('should get asset service log by ID', async () => {
      const mockLog = { id: '1', asset_id: 'asset-1', notes: 'Service log' };
      assetServiceLogRepository.findById.mockResolvedValue(mockLog);

      const result = await assetServiceLogService.getAssetServiceLogById('1', mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining(mockLog));
      expect(assetServiceLogRepository.findById).toHaveBeenCalledWith('1', expect.any(Object));
    });

    it('should throw HttpError when asset service log not found', async () => {
      assetServiceLogRepository.findById.mockResolvedValue(null);

      await expect(
        assetServiceLogService.getAssetServiceLogById('non-existent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createAssetServiceLog', () => {
    it('should create asset service log and log audit', async () => {
      const mockData = {
        asset_id: '123',
        notes: 'New service log',
        serviced_at: '2026-01-19T10:00:00Z'
      };

      const mockCreated = { id: '1', ...mockData };
      assetServiceLogRepository.create.mockResolvedValue(mockCreated);

      const result = await assetServiceLogService.createAssetServiceLog(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining(mockCreated));
      expect(assetServiceLogRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          asset_id: '123',
          notes: 'New service log',
          serviced_at: expect.any(Date)
        }),
        expect.any(Object)
      );
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: mockUserId,
          action: 'CREATE',
          entity: 'asset_service_log',
          entity_id: '1',
          ip_address: mockIpAddress
        })
      );
    });

    it('should handle datetime conversion', async () => {
      const mockData = {
        asset_id: '123',
        serviced_at: '2026-01-19T10:00:00Z'
      };

      assetServiceLogRepository.create.mockResolvedValue({ id: '1' });

      await assetServiceLogService.createAssetServiceLog(mockData, mockUserId, mockIpAddress);

      expect(assetServiceLogRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          serviced_at: expect.any(Date)
        }),
        expect.any(Object)
      );
    });
  });

  describe('updateAssetServiceLog', () => {
    it('should update asset service log and log audit', async () => {
      const mockBefore = { id: '1', asset_id: 'asset-1', notes: 'Old notes' };
      const mockAfter = { id: '1', asset_id: 'asset-1', notes: 'Updated notes' };

      assetServiceLogRepository.findById.mockResolvedValue(mockBefore);
      assetServiceLogRepository.update.mockResolvedValue(mockAfter);

      const result = await assetServiceLogService.updateAssetServiceLog(
        '1',
        { notes: 'Updated notes' },
        mockUserId,
        mockIpAddress
      );

      expect(result).toEqual(expect.objectContaining(mockAfter));
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: mockUserId,
          action: 'UPDATE',
          entity: 'asset_service_log',
          diff: { before: mockBefore, after: mockAfter }
        })
      );
    });

    it('should throw HttpError when asset service log not found', async () => {
      assetServiceLogRepository.findById.mockResolvedValue(null);

      await expect(
        assetServiceLogService.updateAssetServiceLog('non-existent', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteAssetServiceLog', () => {
    it('should soft delete asset service log and log audit', async () => {
      const mockBefore = { id: '1', asset_id: 'asset-1', notes: 'Service log' };

      assetServiceLogRepository.findById.mockResolvedValue(mockBefore);
      assetServiceLogRepository.softDelete.mockResolvedValue({});

      await assetServiceLogService.deleteAssetServiceLog('1', mockUserId, mockIpAddress);

      expect(assetServiceLogRepository.softDelete).toHaveBeenCalledWith('1');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: mockUserId,
          action: 'DELETE',
          entity: 'asset_service_log',
          entity_id: '1',
          diff: { before: mockBefore }
        })
      );
    });

    it('should throw HttpError when asset service log not found', async () => {
      assetServiceLogRepository.findById.mockResolvedValue(null);

      await expect(
        assetServiceLogService.deleteAssetServiceLog('non-existent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
