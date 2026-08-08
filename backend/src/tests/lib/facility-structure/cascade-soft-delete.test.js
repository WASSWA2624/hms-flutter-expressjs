/**
 * Facility-structure cascade soft-delete helpers.
 */

jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  department: { findFirst: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
  unit: { findUnique: jest.fn(), update: jest.fn() },
  ward: { findFirst: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
  room: { findFirst: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
  bed: { findUnique: jest.fn(), update: jest.fn() },
  facility: { findFirst: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
}));

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const {
  softDeleteFacilityCascade,
  softDeleteDepartmentCascade,
  softDeleteWardCascade,
  softDeleteRoomCascade,
  softDeleteTenantStructureInTx,
  restoreTenantStructureInTx,
  restoreRoom,
  restoreUnit,
  restoreWard,
} = require('@lib/facility-structure/cascade-soft-delete');

const createTx = () => ({
  bed: { findMany: jest.fn(), updateMany: jest.fn() },
  room: { findMany: jest.fn(), updateMany: jest.fn() },
  unit: { findMany: jest.fn(), updateMany: jest.fn() },
  ward: { findMany: jest.fn(), updateMany: jest.fn() },
  department: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    update: jest.fn(),
    updateMany: jest.fn(),
  },
  facility: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    update: jest.fn(),
    updateMany: jest.fn(),
  },
});

describe('cascade-soft-delete', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('soft-deletes facility descendants then the facility', async () => {
    const tx = createTx();
    tx.facility.findFirst.mockResolvedValue({ id: 'fac-1' });
    tx.bed.findMany.mockResolvedValue([{ id: 'bed-1' }]);
    tx.room.findMany.mockResolvedValue([{ id: 'room-1' }]);
    tx.unit.findMany.mockResolvedValue([{ id: 'unit-1' }]);
    tx.ward.findMany.mockResolvedValue([{ id: 'ward-1' }]);
    tx.department.findMany.mockResolvedValue([{ id: 'dept-1' }]);
    tx.facility.update.mockResolvedValue({
      id: 'fac-1',
      deleted_at: new Date('2026-07-28T00:00:00.000Z'),
    });
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    const result = await softDeleteFacilityCascade('fac-1');

    expect(result.bedIds).toEqual(['bed-1']);
    expect(result.roomIds).toEqual(['room-1']);
    expect(result.unitIds).toEqual(['unit-1']);
    expect(result.wardIds).toEqual(['ward-1']);
    expect(result.departmentIds).toEqual(['dept-1']);
    expect(tx.bed.updateMany).toHaveBeenCalled();
    expect(tx.facility.update).toHaveBeenCalledWith({
      where: { id: 'fac-1' },
      data: { deleted_at: expect.any(Date) },
    });
  });

  it('soft-deletes department units in cascade', async () => {
    const tx = createTx();
    tx.department.findFirst.mockResolvedValue({ id: 'dept-1' });
    tx.unit.findMany.mockResolvedValue([{ id: 'unit-1' }, { id: 'unit-2' }]);
    tx.department.update.mockResolvedValue({ id: 'dept-1', deleted_at: new Date() });
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    const result = await softDeleteDepartmentCascade('dept-1');

    expect(result.unitIds).toEqual(['unit-1', 'unit-2']);
    expect(tx.unit.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['unit-1', 'unit-2'] }, deleted_at: null },
      data: { deleted_at: expect.any(Date) },
    });
  });

  it('soft-deletes ward rooms and beds in cascade', async () => {
    const tx = createTx();
    tx.ward.findFirst = jest.fn().mockResolvedValue({ id: 'ward-1' });
    tx.room.findMany.mockResolvedValue([{ id: 'room-1' }]);
    tx.bed.findMany.mockResolvedValue([{ id: 'bed-1' }, { id: 'bed-2' }]);
    tx.ward.update = jest.fn().mockResolvedValue({ id: 'ward-1', deleted_at: new Date() });
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    const result = await softDeleteWardCascade('ward-1');

    expect(result.roomIds).toEqual(['room-1']);
    expect(result.bedIds).toEqual(['bed-1', 'bed-2']);
  });

  it('soft-deletes room beds in cascade', async () => {
    const tx = createTx();
    tx.room.findFirst = jest.fn().mockResolvedValue({ id: 'room-1' });
    tx.bed.findMany.mockResolvedValue([{ id: 'bed-1' }]);
    tx.room.update = jest.fn().mockResolvedValue({ id: 'room-1', deleted_at: new Date() });
    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    const result = await softDeleteRoomCascade('room-1');

    expect(result.bedIds).toEqual(['bed-1']);
  });

  it('soft-deletes tenant structure and active facilities in-tx', async () => {
    const tx = createTx();
    tx.bed.findMany.mockResolvedValue([{ id: 'bed-1' }]);
    tx.room.findMany.mockResolvedValue([]);
    tx.unit.findMany.mockResolvedValue([]);
    tx.ward.findMany.mockResolvedValue([]);
    tx.department.findMany.mockResolvedValue([{ id: 'dept-1' }]);
    tx.facility.findMany.mockResolvedValue([
      { id: 'fac-1', tenant_id: 'ten-1', name: 'Main', facility_type: 'HOSPITAL', is_active: true },
    ]);

    const result = await softDeleteTenantStructureInTx(tx, 'ten-1', new Date());

    expect(result.facilities).toHaveLength(1);
    expect(tx.facility.updateMany).toHaveBeenCalled();
    expect(tx.bed.updateMany).toHaveBeenCalled();
    expect(tx.department.updateMany).toHaveBeenCalled();
    // Per-facility descendant pass after tenant-scoped structure soft-delete.
    expect(tx.bed.findMany.mock.calls.length).toBeGreaterThanOrEqual(2);
  });

  it('restores tenant facilities and structure matching deleted_at', async () => {
    const deletedAt = new Date('2026-08-08T12:00:00.000Z');
    const tx = createTx();
    tx.facility.findMany.mockResolvedValue([
      {
        id: 'fac-1',
        tenant_id: 'ten-1',
        name: 'Main',
        facility_type: 'HOSPITAL',
        is_active: true,
      },
    ]);

    const result = await restoreTenantStructureInTx(tx, 'ten-1', deletedAt);

    expect(result.facilities).toHaveLength(1);
    expect(tx.facility.updateMany).toHaveBeenCalledWith({
      where: { tenant_id: 'ten-1', deleted_at: deletedAt },
      data: { deleted_at: null },
    });
    expect(tx.department.updateMany).toHaveBeenCalledWith({
      where: { tenant_id: 'ten-1', deleted_at: deletedAt },
      data: { deleted_at: null },
    });
    expect(tx.unit.updateMany).toHaveBeenCalledWith({
      where: { tenant_id: 'ten-1', deleted_at: deletedAt },
      data: { deleted_at: null },
    });
    expect(tx.ward.updateMany).toHaveBeenCalledWith({
      where: { tenant_id: 'ten-1', deleted_at: deletedAt },
      data: { deleted_at: null },
    });
    expect(tx.room.updateMany).toHaveBeenCalledWith({
      where: { tenant_id: 'ten-1', deleted_at: deletedAt },
      data: { deleted_at: null },
    });
    expect(tx.bed.updateMany).toHaveBeenCalledWith({
      where: { tenant_id: 'ten-1', deleted_at: deletedAt },
      data: { deleted_at: null },
    });
  });

  it('blocks room restore when ward is deleted', async () => {
    prisma.room.findUnique.mockResolvedValue({
      id: 'room-1',
      ward_id: 'ward-1',
      facility_id: 'fac-1',
      deleted_at: new Date(),
    });
    prisma.ward.findFirst.mockResolvedValue(null);

    await expect(restoreRoom('room-1')).rejects.toBeInstanceOf(HttpError);
  });

  it('allows room restore without ward when facility is active', async () => {
    prisma.room.findUnique.mockResolvedValue({
      id: 'room-1',
      ward_id: null,
      facility_id: 'fac-1',
      deleted_at: new Date(),
    });
    prisma.facility.findFirst.mockResolvedValue({ id: 'fac-1' });
    prisma.room.update.mockResolvedValue({ id: 'room-1', deleted_at: null });

    const restored = await restoreRoom('room-1');

    expect(restored.deleted_at).toBeNull();
    expect(prisma.facility.findFirst).toHaveBeenCalledWith({
      where: { id: 'fac-1', deleted_at: null },
      select: { id: true },
    });
  });

  it('blocks unit restore when department is deleted', async () => {
    prisma.unit.findUnique.mockResolvedValue({
      id: 'unit-1',
      facility_id: 'fac-1',
      department_id: 'dept-1',
      deleted_at: new Date(),
    });
    prisma.facility.findFirst.mockResolvedValue({ id: 'fac-1' });
    prisma.department.findFirst.mockResolvedValue(null);

    await expect(restoreUnit('unit-1')).rejects.toBeInstanceOf(HttpError);
  });

  it('does not require optional department when restoring ward', async () => {
    prisma.ward.findUnique.mockResolvedValue({
      id: 'ward-1',
      facility_id: 'fac-1',
      deleted_at: new Date(),
    });
    prisma.facility.findFirst.mockResolvedValue({ id: 'fac-1' });
    prisma.ward.update.mockResolvedValue({ id: 'ward-1', deleted_at: null });

    const restored = await restoreWard('ward-1');

    expect(restored.deleted_at).toBeNull();
    expect(prisma.department.findFirst).not.toHaveBeenCalled();
  });
});
