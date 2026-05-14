/**
 * KPI snapshot repository tests
 *
 * @module tests/modules/kpi-snapshot/repositories
 * @description Tests for KPI snapshot repository operations
 */

const kpiSnapshotRepository = require('@modules/kpi-snapshot/repositories/kpi-snapshot.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  kpi_snapshot: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
}));

describe('KPI Snapshot Repository', () => {
  const includeMatcher = expect.objectContaining({
    tenant: expect.any(Object),
    facility: expect.any(Object),
    branch: expect.any(Object),
  });

  const mockKpiSnapshot = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    tenant_id: '660e8400-e29b-41d4-a716-446655440000',
    name: 'Revenue',
    metric_key: 'daily_revenue',
    metric_group: 'finance',
    threshold_state: 'NORMAL',
    value: '12500.50',
    recorded_at: new Date(),
    created_at: new Date(),
    updated_at: new Date(),
    deleted_at: null,
    version: 1,
  };

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find KPI snapshot by ID', async () => {
      prisma.kpi_snapshot.findFirst.mockResolvedValue(mockKpiSnapshot);

      const result = await kpiSnapshotRepository.findById(mockKpiSnapshot.id);

      expect(result).toEqual(mockKpiSnapshot);
      expect(prisma.kpi_snapshot.findFirst).toHaveBeenCalledWith({
        where: { id: mockKpiSnapshot.id, deleted_at: null },
        include: includeMatcher,
      });
    });

    it('should return null if KPI snapshot not found', async () => {
      prisma.kpi_snapshot.findFirst.mockResolvedValue(null);

      const result = await kpiSnapshotRepository.findById('non-existent-id');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.kpi_snapshot.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(kpiSnapshotRepository.findById('some-id')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find KPI snapshots with default parameters', async () => {
      prisma.kpi_snapshot.findMany.mockResolvedValue([mockKpiSnapshot]);

      const result = await kpiSnapshotRepository.findMany();

      expect(result).toEqual([mockKpiSnapshot]);
      expect(prisma.kpi_snapshot.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { recorded_at: 'desc' },
        include: includeMatcher,
      });
    });

    it('should apply filters correctly', async () => {
      prisma.kpi_snapshot.findMany.mockResolvedValue([mockKpiSnapshot]);

      await kpiSnapshotRepository.findMany({
        where: { tenant_id: mockKpiSnapshot.tenant_id },
      });

      expect(prisma.kpi_snapshot.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: mockKpiSnapshot.tenant_id,
        },
        skip: 0,
        take: 20,
        orderBy: { recorded_at: 'desc' },
        include: includeMatcher,
      });
    });
  });

  describe('count', () => {
    it('should count KPI snapshots', async () => {
      prisma.kpi_snapshot.count.mockResolvedValue(10);

      const result = await kpiSnapshotRepository.count();

      expect(result).toBe(10);
      expect(prisma.kpi_snapshot.count).toHaveBeenCalledWith({
        where: { deleted_at: null },
      });
    });
  });

  describe('create', () => {
    it('should create KPI snapshot', async () => {
      const createData = {
        tenant_id: mockKpiSnapshot.tenant_id,
        name: mockKpiSnapshot.name,
        metric_key: mockKpiSnapshot.metric_key,
        metric_group: mockKpiSnapshot.metric_group,
        threshold_state: mockKpiSnapshot.threshold_state,
        value: mockKpiSnapshot.value,
      };
      prisma.kpi_snapshot.create.mockResolvedValue(mockKpiSnapshot);

      const result = await kpiSnapshotRepository.create(createData);

      expect(result).toEqual(mockKpiSnapshot);
      expect(prisma.kpi_snapshot.create).toHaveBeenCalledWith({
        data: createData,
        include: includeMatcher,
      });
    });
  });

  describe('update', () => {
    it('should update KPI snapshot', async () => {
      const updateData = { value: '15000.00' };
      const updated = { ...mockKpiSnapshot, ...updateData };
      prisma.kpi_snapshot.update.mockResolvedValue(updated);

      const result = await kpiSnapshotRepository.update(mockKpiSnapshot.id, updateData);

      expect(result).toEqual(updated);
      expect(prisma.kpi_snapshot.update).toHaveBeenCalledWith({
        where: { id: mockKpiSnapshot.id },
        data: updateData,
        include: includeMatcher,
      });
    });
  });

  describe('softDelete', () => {
    it('should soft delete KPI snapshot', async () => {
      const deleted = { ...mockKpiSnapshot, deleted_at: new Date() };
      prisma.kpi_snapshot.update.mockResolvedValue(deleted);

      const result = await kpiSnapshotRepository.softDelete(mockKpiSnapshot.id);

      expect(result.deleted_at).toBeTruthy();
      expect(prisma.kpi_snapshot.update).toHaveBeenCalledWith({
        where: { id: mockKpiSnapshot.id },
        data: { deleted_at: expect.any(Date) },
      });
    });
  });
});
