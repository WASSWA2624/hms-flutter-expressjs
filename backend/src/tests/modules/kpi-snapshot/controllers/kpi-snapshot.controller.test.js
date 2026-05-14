/**
 * KPI snapshot controller tests
 *
 * @module tests/modules/kpi-snapshot/controllers
 * @description Tests for KPI snapshot controllers
 * Per testing.mdc: Comprehensive controller tests with mocked service
 */

const kpiSnapshotController = require('@modules/kpi-snapshot/controllers/kpi-snapshot.controller');
const kpiSnapshotService = require('@modules/kpi-snapshot/services/kpi-snapshot.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');

// Mock service and response helpers
jest.mock('@modules/kpi-snapshot/services/kpi-snapshot.service');
jest.mock('@lib/response');

describe('KPI Snapshot Controller', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  const mockReq = {
    query: {},
    params: {},
    body: {},
    user: { id: 'user-id-123' },
    ip: '127.0.0.1',
    get: jest.fn(() => 'jest-test-agent')
  };

  const mockRes = {};

  const mockKpiSnapshot = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    tenant_id: '660e8400-e29b-41d4-a716-446655440000',
    name: 'Revenue',
    value: '12500.50',
    recorded_at: new Date(),
    created_at: new Date(),
    updated_at: new Date(),
    deleted_at: null,
    version: 1
  };

  describe('listKpiSnapshots', () => {
    it('should list KPI snapshots', async () => {
      const mockResult = {
        kpiSnapshots: [mockKpiSnapshot],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      kpiSnapshotService.listKpiSnapshots.mockResolvedValue(mockResult);

      await kpiSnapshotController.listKpiSnapshots(mockReq, mockRes);

      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.kpi_snapshot.list.success',
        mockResult.kpiSnapshots,
        mockResult.pagination
      );
    });
  });

  describe('getKpiSnapshotById', () => {
    it('should get KPI snapshot by ID', async () => {
      mockReq.params = { id: mockKpiSnapshot.id };
      kpiSnapshotService.getKpiSnapshotById.mockResolvedValue(mockKpiSnapshot);

      await kpiSnapshotController.getKpiSnapshotById(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.kpi_snapshot.get.success',
        mockKpiSnapshot
      );
    });
  });

  describe('createKpiSnapshot', () => {
    it('should create KPI snapshot', async () => {
      mockReq.body = {
        tenant_id: mockKpiSnapshot.tenant_id,
        name: mockKpiSnapshot.name,
        value: mockKpiSnapshot.value
      };
      kpiSnapshotService.createKpiSnapshot.mockResolvedValue(mockKpiSnapshot);

      await kpiSnapshotController.createKpiSnapshot(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.kpi_snapshot.create.success',
        mockKpiSnapshot
      );
    });
  });

  describe('updateKpiSnapshot', () => {
    it('should update KPI snapshot', async () => {
      mockReq.params = { id: mockKpiSnapshot.id };
      mockReq.body = { value: '15000.00' };
      const updated = { ...mockKpiSnapshot, value: '15000.00' };
      kpiSnapshotService.updateKpiSnapshot.mockResolvedValue(updated);

      await kpiSnapshotController.updateKpiSnapshot(mockReq, mockRes);

      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.kpi_snapshot.update.success',
        updated
      );
    });
  });

  describe('deleteKpiSnapshot', () => {
    it('should delete KPI snapshot', async () => {
      mockReq.params = { id: mockKpiSnapshot.id };
      kpiSnapshotService.deleteKpiSnapshot.mockResolvedValue();

      await kpiSnapshotController.deleteKpiSnapshot(mockReq, mockRes);

      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
