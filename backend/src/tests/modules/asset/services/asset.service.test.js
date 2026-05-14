/**
 * Asset service tests
 *
 * @module tests/modules/asset/services
 * @description Tests for asset service business logic layer
 */

const assetService = require('../../../../modules/asset/services/asset.service');
const assetRepository = require('../../../../modules/asset/repositories/asset.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock repository and audit
jest.mock('../../../../modules/asset/repositories/asset.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null)
}));

describe('Asset Service', () => {
  const mockUserId = 'user-123';
  const mockIpAddress = '127.0.0.1';

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listAssets', () => {
    it('should list assets with pagination', async () => {
      const mockAssets = [
        { id: '1', name: 'Asset 1', status: 'OPEN' },
        { id: '2', name: 'Asset 2', status: 'IN_PROGRESS' }
      ];

      assetRepository.findMany.mockResolvedValue(mockAssets);
      assetRepository.count.mockResolvedValue(2);

      const result = await assetService.listAssets(
        {},
        1,
        20,
        'created_at',
        'desc',
        mockUserId,
        mockIpAddress
      );

      expect(result.assets).toEqual([
        expect.objectContaining(mockAssets[0]),
        expect.objectContaining(mockAssets[1])
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
      assetRepository.findMany.mockResolvedValue([]);
      assetRepository.count.mockResolvedValue(0);

      const filters = {
        tenant_id: '123',
        facility_id: '456',
        name: 'Equipment',
        asset_tag: 'MED-001',
        status: 'OPEN',
        search: 'medical'
      };

      await assetService.listAssets(
        filters,
        1,
        20,
        null,
        'asc',
        mockUserId,
        mockIpAddress
      );

      expect(assetRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: '123',
          facility_id: '456',
          name: { contains: 'Equipment' },
          asset_tag: { contains: 'MED-001' },
          status: 'OPEN',
          OR: expect.arrayContaining([
            { human_friendly_id: { contains: 'MEDICAL' } },
            { name: { contains: 'medical' } },
            { asset_tag: { contains: 'medical' } }
          ])
        }),
        0,
        20,
        { created_at: 'asc' },
        expect.any(Object)
      );
    });

    it('should throw HttpError on repository error', async () => {
      assetRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        assetService.listAssets({}, 1, 20, null, 'asc', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getAssetById', () => {
    it('should get asset by ID', async () => {
      const mockAsset = { id: '1', name: 'Asset', status: 'OPEN' };
      assetRepository.findById.mockResolvedValue(mockAsset);

      const result = await assetService.getAssetById('1', mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining(mockAsset));
      expect(assetRepository.findById).toHaveBeenCalledWith('1', expect.any(Object));
    });

    it('should throw HttpError when asset not found', async () => {
      assetRepository.findById.mockResolvedValue(null);

      await expect(
        assetService.getAssetById('non-existent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createAsset', () => {
    it('should create asset and log audit', async () => {
      const mockData = {
        tenant_id: '123',
        name: 'New Asset',
        status: 'OPEN'
      };

      const mockCreated = { id: '1', ...mockData };
      assetRepository.create.mockResolvedValue(mockCreated);

      const result = await assetService.createAsset(mockData, mockUserId, mockIpAddress);

      expect(result).toEqual(expect.objectContaining(mockCreated));
      expect(assetRepository.create).toHaveBeenCalledWith(mockData, expect.any(Object));
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: mockUserId,
          action: 'CREATE',
          entity: 'asset',
          entity_id: '1',
          ip_address: mockIpAddress
        })
      );
    });
  });

  describe('updateAsset', () => {
    it('should update asset and log audit', async () => {
      const mockBefore = { id: '1', tenant_id: '123', name: 'Old Asset', status: 'OPEN' };
      const mockAfter = { id: '1', tenant_id: '123', name: 'Updated Asset', status: 'OPEN' };

      assetRepository.findById.mockResolvedValue(mockBefore);
      assetRepository.update.mockResolvedValue(mockAfter);

      const result = await assetService.updateAsset(
        '1',
        { name: 'Updated Asset' },
        mockUserId,
        mockIpAddress
      );

      expect(result).toEqual(expect.objectContaining(mockAfter));
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: mockUserId,
          action: 'UPDATE',
          entity: 'asset',
          diff: { before: mockBefore, after: mockAfter }
        })
      );
    });

    it('should throw HttpError when asset not found', async () => {
      assetRepository.findById.mockResolvedValue(null);

      await expect(
        assetService.updateAsset('non-existent', {}, mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteAsset', () => {
    it('should soft delete asset and log audit', async () => {
      const mockBefore = { id: '1', name: 'Asset', status: 'OPEN' };

      assetRepository.findById.mockResolvedValue(mockBefore);
      assetRepository.softDelete.mockResolvedValue({});

      await assetService.deleteAsset('1', mockUserId, mockIpAddress);

      expect(assetRepository.softDelete).toHaveBeenCalledWith('1');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          user_id: mockUserId,
          action: 'DELETE',
          entity: 'asset',
          entity_id: '1',
          diff: { before: mockBefore }
        })
      );
    });

    it('should throw HttpError when asset not found', async () => {
      assetRepository.findById.mockResolvedValue(null);

      await expect(
        assetService.deleteAsset('non-existent', mockUserId, mockIpAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
