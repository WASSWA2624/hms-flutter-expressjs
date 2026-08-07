const {
  transferDiscrepancyQuantity,
  deriveTransferStatus,
  isTransferReceiveLeg,
  aggregateTransferGroups,
  createPharmacyTransferDatasetRunners,
} = require('@lib/reports/pharmacy-transfer-analytics');

const mockFindMany = jest.fn();

jest.mock('@prisma/client', () => ({
  stock_movement: {
    findMany: (...args) => mockFindMany(...args),
  },
}));

describe('pharmacy transfer analytics', () => {
  beforeEach(() => {
    mockFindMany.mockReset();
  });

  test('discrepancy math is absolute difference', () => {
    expect(transferDiscrepancyQuantity(10, 7)).toBe(3);
    expect(transferDiscrepancyQuantity(7, 10)).toBe(3);
    expect(transferDiscrepancyQuantity(5, 5)).toBe(0);
  });

  test('status derives from paired receipts only', () => {
    expect(deriveTransferStatus({ hasShip: true, hasReceive: false })).toBe('PENDING');
    expect(deriveTransferStatus({ hasShip: true, hasReceive: true })).toBe('COMPLETED');
    expect(deriveTransferStatus({ hasShip: false, hasReceive: false })).toBeNull();
  });

  test('receive leg detected when facility_id matches to_facility_id', () => {
    expect(
      isTransferReceiveLeg({ facility_id: 'B', from_facility_id: 'A', to_facility_id: 'B' })
    ).toBe(true);
    expect(
      isTransferReceiveLeg({ facility_id: 'A', from_facility_id: 'A', to_facility_id: 'B' })
    ).toBe(false);
  });

  test('aggregateTransferGroups marks pending completed and discrepancy', () => {
    const groups = aggregateTransferGroups([
      {
        id: 'ship-1',
        transfer_group_id: 'g1',
        facility_id: 'A',
        from_facility_id: 'A',
        to_facility_id: 'B',
        quantity: 10,
        occurred_at: '2026-08-01T10:00:00.000Z',
        inventory_item_id: 'item-1',
        inventory_item: { name: 'Amox' },
        from_facility: { name: 'Main' },
        to_facility: { name: 'Annex' },
        facility: { name: 'Main' },
      },
      {
        id: 'recv-1',
        transfer_group_id: 'g1',
        facility_id: 'B',
        from_facility_id: 'A',
        to_facility_id: 'B',
        quantity: 8,
        occurred_at: '2026-08-01T12:00:00.000Z',
        inventory_item_id: 'item-1',
        inventory_item: { name: 'Amox' },
        from_facility: { name: 'Main' },
        to_facility: { name: 'Annex' },
        facility: { name: 'Annex' },
      },
      {
        id: 'ship-2',
        transfer_group_id: 'g2',
        facility_id: 'A',
        from_facility_id: 'A',
        to_facility_id: 'B',
        quantity: 5,
        occurred_at: '2026-08-02T10:00:00.000Z',
        inventory_item_id: 'item-2',
        inventory_item: { name: 'Para' },
        from_facility: { name: 'Main' },
        to_facility: { name: 'Annex' },
        facility: { name: 'Main' },
      },
    ]);

    const completed = groups.find((row) => row.transfer_group_id === 'g1');
    const pending = groups.find((row) => row.transfer_group_id === 'g2');
    expect(completed.transfer_status).toBe('COMPLETED');
    expect(completed.discrepancy_quantity).toBe(2);
    expect(completed.has_discrepancy).toBe(true);
    expect(pending.transfer_status).toBe('PENDING');
    expect(pending.received_quantity).toBeNull();
  });

  test('TRANSFER filter excludes OUTBOUND+DISPENSE rows', async () => {
    mockFindMany.mockResolvedValue([]);
    const runners = createPharmacyTransferDatasetRunners(() => ({
      invalid: false,
      from: new Date('2026-08-01T00:00:00.000Z'),
      to: new Date('2026-08-07T23:59:59.999Z'),
      preset: 'custom',
    }));

    await runners.pharmacy_transfer_quantity(
      { tenant_id: 'tenant-1' },
      { date_preset: 'custom' }
    );

    expect(mockFindMany).toHaveBeenCalled();
    const where = mockFindMany.mock.calls[0][0].where;
    expect(where.movement_type).toBe('TRANSFER');
    expect(where.reason).toBeUndefined();
    expect(where.OR).toBeUndefined();
  });

  test('discrepancy dataset rows use abs shipped minus received', async () => {
    mockFindMany.mockResolvedValue([
      {
        id: 'ship-1',
        transfer_group_id: 'g1',
        facility_id: 'A',
        from_facility_id: 'A',
        to_facility_id: 'B',
        quantity: 12,
        occurred_at: '2026-08-01T10:00:00.000Z',
        inventory_item_id: 'item-1',
        inventory_item: { name: 'Amox' },
        from_facility: { name: 'Main' },
        to_facility: { name: 'Annex' },
        facility: { name: 'Main' },
      },
      {
        id: 'recv-1',
        transfer_group_id: 'g1',
        facility_id: 'B',
        from_facility_id: 'A',
        to_facility_id: 'B',
        quantity: 9,
        occurred_at: '2026-08-01T12:00:00.000Z',
        inventory_item_id: 'item-1',
        inventory_item: { name: 'Amox' },
        from_facility: { name: 'Main' },
        to_facility: { name: 'Annex' },
        facility: { name: 'Annex' },
      },
    ]);

    const runners = createPharmacyTransferDatasetRunners(() => ({
      invalid: false,
      from: new Date('2026-08-01T00:00:00.000Z'),
      to: new Date('2026-08-07T23:59:59.999Z'),
      preset: 'custom',
    }));

    const result = await runners.pharmacy_transfer_discrepancies(
      { tenant_id: 'tenant-1' },
      {}
    );
    expect(result.rows).toHaveLength(1);
    expect(result.rows[0].discrepancy_quantity).toBe(3);
    expect(result.summary.discrepancy_quantity).toBe(3);
  });
});
