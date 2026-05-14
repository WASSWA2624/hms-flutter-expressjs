/**
 * KPI snapshot service tests
 *
 * @module tests/modules/kpi-snapshot/services
 * @description Tests for KPI snapshot service layer
 */

const kpiSnapshotService = require('@modules/kpi-snapshot/services/kpi-snapshot.service');
const kpiSnapshotRepository = require('@modules/kpi-snapshot/repositories/kpi-snapshot.repository');
const { createAuditLog } = require('@lib/audit');

jest.mock('@modules/kpi-snapshot/repositories/kpi-snapshot.repository');
jest.mock('@lib/audit');

describe('KPI Snapshot Service', () => {
  const tenantId = '660e8400-e29b-41d4-a716-446655440000';
  const userId = '550e8400-e29b-41d4-a716-446655440000';
  const user = { id: userId, tenant_id: tenantId };
  const context = {
    user,
    user_id: userId,
    ip_address: '127.0.0.1',
    user_agent: 'jest-test-agent',
  };

  const mockKpiSnapshot = {
    id: '550e8400-e29b-41d4-a716-446655440001',
    human_friendly_id: 'KPI0000001',
    tenant_id: tenantId,
    name: 'Revenue',
    metric_key: 'daily_revenue',
    metric_group: 'finance',
    threshold_state: 'NORMAL',
    value: '12500.50',
    recorded_at: new Date('2026-01-19T12:00:00.000Z'),
    created_at: new Date('2026-01-19T12:00:00.000Z'),
    updated_at: new Date('2026-01-19T12:00:00.000Z'),
    deleted_at: null,
    version: 1,
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listKpiSnapshots', () => {
    it('should list KPI snapshots with pagination', async () => {
      kpiSnapshotRepository.findMany.mockResolvedValue([mockKpiSnapshot]);
      kpiSnapshotRepository.count.mockResolvedValue(1);

      const result = await kpiSnapshotService.listKpiSnapshots({}, 1, 20, 'created_at', 'desc', user);

      expect(result.kpiSnapshots).toEqual([
        expect.objectContaining({
          id: 'KPI0000001',
          display_id: 'KPI0000001',
          name: 'Revenue',
          metric_key: 'daily_revenue',
          metric_group: 'finance',
          threshold_state: 'NORMAL',
          value: 12500.5,
        }),
      ]);
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false,
      });
    });

    it('should apply date range filters', async () => {
      kpiSnapshotRepository.findMany.mockResolvedValue([mockKpiSnapshot]);
      kpiSnapshotRepository.count.mockResolvedValue(1);

      await kpiSnapshotService.listKpiSnapshots(
        {
          from: '2026-01-01T00:00:00Z',
          to: '2026-01-31T23:59:59Z',
          metric_key: 'daily_revenue',
        },
        1,
        20,
        null,
        'asc',
        user
      );

      expect(kpiSnapshotRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            tenant_id: tenantId,
            metric_key: 'daily_revenue',
            recorded_at: expect.objectContaining({
              gte: expect.any(Date),
              lte: expect.any(Date),
            }),
          }),
        })
      );
    });
  });

  describe('getKpiSnapshotById', () => {
    it('should get KPI snapshot by ID', async () => {
      kpiSnapshotRepository.findById.mockResolvedValue(mockKpiSnapshot);

      const result = await kpiSnapshotService.getKpiSnapshotById(mockKpiSnapshot.id, user);

      expect(result).toEqual(
        expect.objectContaining({
          id: 'KPI0000001',
          value: 12500.5,
        })
      );
    });
  });

  describe('createKpiSnapshot', () => {
    it('should create KPI snapshot and audit log', async () => {
      kpiSnapshotRepository.create.mockResolvedValue(mockKpiSnapshot);

      const result = await kpiSnapshotService.createKpiSnapshot(
        {
          name: 'Revenue',
          metric_key: 'daily_revenue',
          metric_group: 'finance',
          threshold_state: 'NORMAL',
          value: '12500.50',
          recorded_at: '2026-01-19T12:00:00.000Z',
        },
        context
      );

      expect(result).toEqual(
        expect.objectContaining({
          id: 'KPI0000001',
          value: 12500.5,
        })
      );
      expect(kpiSnapshotRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: tenantId,
          name: 'Revenue',
          metric_key: 'daily_revenue',
          metric_group: 'finance',
          threshold_state: 'NORMAL',
          value: '12500.50',
          recorded_at: new Date('2026-01-19T12:00:00.000Z'),
        })
      );
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: tenantId,
          user_id: userId,
          action: 'CREATE',
          entity: 'kpi_snapshot',
          entity_id: mockKpiSnapshot.id,
          diff: {
            after: expect.objectContaining({
              id: 'KPI0000001',
              value: 12500.5,
            }),
          },
          ip_address: '127.0.0.1',
          user_agent: 'jest-test-agent',
        })
      );
    });
  });

  describe('updateKpiSnapshot', () => {
    it('should update KPI snapshot and audit log', async () => {
      const updated = {
        ...mockKpiSnapshot,
        value: '15000.00',
        version: 2,
      };
      kpiSnapshotRepository.findById.mockResolvedValue(mockKpiSnapshot);
      kpiSnapshotRepository.update.mockResolvedValue(updated);

      const result = await kpiSnapshotService.updateKpiSnapshot(
        mockKpiSnapshot.id,
        {
          value: '15000.00',
          version: 1,
        },
        context
      );

      expect(result).toEqual(
        expect.objectContaining({
          id: 'KPI0000001',
          value: 15000,
          version: 2,
        })
      );
      expect(kpiSnapshotRepository.update).toHaveBeenCalledWith(mockKpiSnapshot.id, {
        version: 2,
        value: '15000.00',
      });
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: tenantId,
          user_id: userId,
          action: 'UPDATE',
          entity: 'kpi_snapshot',
          entity_id: mockKpiSnapshot.id,
          diff: expect.objectContaining({
            before: expect.objectContaining({ value: '12500.50', version: 1 }),
            after: expect.objectContaining({ value: '15000.00', version: 2 }),
          }),
        })
      );
    });
  });

  describe('deleteKpiSnapshot', () => {
    it('should soft delete KPI snapshot and audit log', async () => {
      kpiSnapshotRepository.findById.mockResolvedValue(mockKpiSnapshot);
      kpiSnapshotRepository.softDelete.mockResolvedValue({
        ...mockKpiSnapshot,
        deleted_at: new Date(),
      });

      await kpiSnapshotService.deleteKpiSnapshot(mockKpiSnapshot.id, context);

      expect(kpiSnapshotRepository.softDelete).toHaveBeenCalledWith(mockKpiSnapshot.id);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: tenantId,
          user_id: userId,
          action: 'DELETE',
          entity: 'kpi_snapshot',
          entity_id: mockKpiSnapshot.id,
          diff: {
            before: expect.objectContaining({
              id: 'KPI0000001',
              value: 12500.5,
            }),
          },
        })
      );
    });
  });
});
