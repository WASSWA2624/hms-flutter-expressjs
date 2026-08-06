const { HttpError } = require('@lib/errors');

jest.mock('@lib/billing/clinical-request-billing', () => {
  const actual = jest.requireActual('@lib/billing/clinical-request-billing');
  return {
    ...actual,
    persistPharmacyOrderBilling: jest.fn(),
    reverseClinicalRequestBilling: jest.fn().mockResolvedValue(true)};
});
jest.mock('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
jest.mock('@repositories/facility-pharmacy-catalog/facility-pharmacy-catalog.repository', () => ({
  findDrugOfferings: jest.fn().mockResolvedValue([])}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn()}));
jest.mock('@lib/websocket', () => ({
  emitToUsers: jest.fn(),
  PHARMACY_EVENTS: {
    PHARMACY_WORKSPACE_UPDATED: 'pharmacy.workspace_updated',
    PHARMACY_ORDER_UPDATED: 'pharmacy.order_updated'},
  INVENTORY_EVENTS: {
    INVENTORY_STOCK_UPDATED: 'inventory.stock_updated'}}));
jest.mock('@prisma/client', () => ({
  user_role: {
    findMany: jest.fn()},
  inventory_stock: {
    fields: {
      reorder_level: 'reorder_level'}}}));
jest.mock('@services/pharmacy-workspace/pharmacy.shared', () => {
  const actual = jest.requireActual('@services/pharmacy-workspace/pharmacy.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
    resolveModelRecordOrThrow: jest.fn()};
});

const pharmacyWorkspaceRepository = require('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
const { createAuditLog } = require('@lib/audit');
const { emitToUsers } = require('@lib/websocket');
const prisma = require('@prisma/client');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow} = require('@services/pharmacy-workspace/pharmacy.shared');
const {
  persistPharmacyOrderBilling,
  reverseClinicalRequestBilling} = require('@lib/billing/clinical-request-billing');
const pharmacyWorkspaceService = require('@services/pharmacy-workspace/pharmacy-workspace.service');

const now = new Date('2026-02-27T10:20:00.000Z');
const mockUser = {
  id: 'actor-1',
  tenant_id: 'tenant-internal-1',
  facility_id: 'facility-internal-1',
  roles: ['PHARMACIST']};

const buildOrder = (overrides = {}) => ({
  id: 'order-internal-1',
  human_friendly_id: 'PHO0000001',
  status: 'ORDERED',
  ordered_at: now,
  created_at: now,
  updated_at: now,
  patient_id: 'patient-internal-1',
  encounter_id: 'encounter-internal-1',
  patient: {
    id: 'patient-internal-1',
    human_friendly_id: 'PAT0000001',
    tenant_id: 'tenant-internal-1',
    facility_id: 'facility-internal-1',
    first_name: 'Amina',
    last_name: 'Stone'},
  encounter: {
    id: 'encounter-internal-1',
    human_friendly_id: 'ENC0000001'},
  items: [
    {
      id: 'item-internal-1',
      human_friendly_id: 'POI0000001',
      pharmacy_order_id: 'order-internal-1',
      drug_id: 'drug-internal-1',
      quantity: 10,
      status: 'ACTIVE',
      dosage: '1 tab',
      frequency: 'ONCE',
      route: 'ORAL',
      created_at: now,
      updated_at: now,
      dispense_logs: [],
      drug: {
        id: 'drug-internal-1',
        human_friendly_id: 'DRG0000001',
        name: 'Paracetamol',
        code: 'PCM',
        inventory_maps: [
          {
            id: 'map-1',
            human_friendly_id: 'DIM0000001',
            drug_id: 'drug-internal-1',
            inventory_item_id: 'inventory-item-internal-1',
            is_default: true,
            deduction_factor: 1,
            inventory_item: {
              id: 'inventory-item-internal-1',
              human_friendly_id: 'INV0000001',
              tenant_id: 'tenant-internal-1',
              name: 'Paracetamol 500mg',
              category: 'MEDICATION',
              sku: 'PCM',
              unit: 'tablet'}}]}}],
  dispense_attestations: [],
  ...overrides});

const flushAsync = () => new Promise((resolve) => setImmediate(resolve));

describe('pharmacy-workspace.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    prisma.user_role.findMany.mockResolvedValue([
      { user_id: 'user-1' },
      { user_id: 'actor-1' },
      { user_id: 'user-2' }]);
  });

  it('resolves legacy pharmacy identifiers to workspace route', async () => {
    resolveModelRecordOrThrow.mockResolvedValue({
      id: '6b6ee0e3-f57e-4d2a-81d6-c7b87a235cdf',
      human_friendly_id: 'PHO0000009'});

    const resolved = await pharmacyWorkspaceService.resolveLegacyRouteIdentifier(
      'pharmacy-orders',
      '6b6ee0e3-f57e-4d2a-81d6-c7b87a235cdf',
      mockUser
    );

    expect(resolved).toEqual({
      id: 'PHO0000009',
      resource: 'orders',
      identifier: 'PHO0000009',
      route: '/pharmacy/orders/PHO0000009',
      matched_by: 'uuid'});
  });

  it('prepareDispense creates pending dispense logs and emits realtime updates', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    const orderBefore = buildOrder();
    const orderAfter = buildOrder({
      dispense_attestations: [
        {
          id: 'att-prep-1',
          human_friendly_id: 'PDA000001',
          pharmacy_order_id: 'order-internal-1',
          dispense_batch_ref: 'DSPBATCH001',
          phase: 'PREPARE',
          attested_by_user_id: 'actor-1',
          attested_role: 'PHARMACIST',
          attested_at: now,
          created_at: now,
          updated_at: now}],
      items: [
        {
          ...orderBefore.items[0],
          dispense_logs: [
            {
              id: 'dlog-1',
              human_friendly_id: 'DLOG0001',
              pharmacy_order_item_id: 'item-internal-1',
              dispense_batch_ref: 'DSPBATCH001',
              status: 'PENDING',
              quantity_dispensed: 2,
              created_at: now,
              updated_at: now}]}]});

    pharmacyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    pharmacyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(orderBefore)
      .mockResolvedValueOnce(orderAfter);
    pharmacyWorkspaceRepository.txFindDispenseAttestation
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null);
    pharmacyWorkspaceRepository.txCreateDispenseLog.mockResolvedValue({ id: 'dlog-1' });
    pharmacyWorkspaceRepository.txCreateDispenseAttestation.mockResolvedValue({ id: 'att-prep-1' });

    const result = await pharmacyWorkspaceService.prepareDispense(
      'PHO0000001',
      {
        dispense_batch_ref: 'DSPBATCH001',
        finalize: false,
        items: [{ order_item_id: 'POI0000001', quantity: 2 }]},
      'actor-1',
      'PHARMACIST',
      '127.0.0.1',
      mockUser
    );

    expect(result.dispense_batch_ref).toBe('DSPBATCH001');
    expect(pharmacyWorkspaceRepository.txCreateDispenseLog).toHaveBeenCalledTimes(1);

    await flushAsync();

    expect(emitToUsers).toHaveBeenCalledWith(
      ['user-1', 'user-2'],
      'pharmacy.workspace_updated',
      expect.objectContaining({
        action: 'PREPARE_DISPENSE'})
    );
  });

  it('prepareDispense rejects a new batch while another batch is pending attestation', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    const orderWithPendingBatch = buildOrder({
      dispense_attestations: [
        {
          id: 'att-prep-open-1',
          human_friendly_id: 'PDA000099',
          pharmacy_order_id: 'order-internal-1',
          dispense_batch_ref: 'DSPBATCH001',
          phase: 'PREPARE',
          attested_by_user_id: 'actor-1',
          attested_role: 'PHARMACIST',
          attested_at: now,
          created_at: now,
          updated_at: now}]});

    pharmacyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    pharmacyWorkspaceRepository.txFindOrderById.mockResolvedValue(orderWithPendingBatch);
    pharmacyWorkspaceRepository.txFindDispenseAttestation
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null);

    await expect(
      pharmacyWorkspaceService.prepareDispense(
        'PHO0000001',
        {
          dispense_batch_ref: 'DSPBATCH002',
          finalize: false,
          items: [{ order_item_id: 'POI0000001', quantity: 2 }]},
        'actor-2',
        'PHARMACIST',
        '127.0.0.1',
        {
          ...mockUser,
          id: 'actor-2'}
      )
    ).rejects.toBeInstanceOf(HttpError);

    expect(pharmacyWorkspaceRepository.txCreateDispenseLog).not.toHaveBeenCalled();
    expect(pharmacyWorkspaceRepository.txCreateDispenseAttestation).not.toHaveBeenCalled();
  });

  it('prepareDispense finalize voids a stuck pending batch and completes dispense', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    const pendingOrder = buildOrder({
      items: [
        {
          ...buildOrder().items[0],
          quantity: 11,
          dispense_logs: [
            {
              id: 'dlog-pending-1',
              human_friendly_id: 'DLOG0099',
              pharmacy_order_item_id: 'item-internal-1',
              dispense_batch_ref: 'DSPBATCH001',
              status: 'PENDING',
              quantity_dispensed: 1,
              created_at: now,
              updated_at: now}]}],
      dispense_attestations: [
        {
          id: 'att-prep-open-1',
          human_friendly_id: 'PDA000099',
          pharmacy_order_id: 'order-internal-1',
          dispense_batch_ref: 'DSPBATCH001',
          phase: 'PREPARE',
          attested_by_user_id: 'actor-1',
          attested_role: 'PHARMACIST',
          attested_at: now,
          created_at: now,
          updated_at: now}]});

    const afterVoid = buildOrder({
      items: [
        {
          ...buildOrder().items[0],
          quantity: 11,
          dispense_logs: [
            {
              id: 'dlog-pending-1',
              human_friendly_id: 'DLOG0099',
              pharmacy_order_item_id: 'item-internal-1',
              dispense_batch_ref: 'DSPBATCH001',
              status: 'CANCELLED',
              quantity_dispensed: 1,
              created_at: now,
              updated_at: now}]}],
      dispense_attestations: []});

    const afterPrepare = {
      ...afterVoid,
      dispense_attestations: [
        {
          id: 'att-prep-2',
          human_friendly_id: 'PDA000100',
          pharmacy_order_id: 'order-internal-1',
          dispense_batch_ref: 'DSPBATCH002',
          phase: 'PREPARE',
          attested_by_user_id: 'actor-1',
          attested_role: 'PHARMACIST',
          attested_at: now,
          created_at: now,
          updated_at: now}],
      items: [
        {
          ...afterVoid.items[0],
          dispense_logs: [
            ...afterVoid.items[0].dispense_logs,
            {
              id: 'dlog-2',
              human_friendly_id: 'DLOG0100',
              pharmacy_order_item_id: 'item-internal-1',
              dispense_batch_ref: 'DSPBATCH002',
              status: 'PENDING',
              quantity_dispensed: 1,
              created_at: now,
              updated_at: now}]}]};

    const afterFinalize = {
      ...afterPrepare,
      status: 'PARTIALLY_DISPENSED',
      dispense_attestations: [
        ...afterPrepare.dispense_attestations,
        {
          id: 'att-attest-2',
          human_friendly_id: 'PDA000101',
          pharmacy_order_id: 'order-internal-1',
          dispense_batch_ref: 'DSPBATCH002',
          phase: 'ATTEST',
          attested_by_user_id: 'actor-1',
          attested_role: 'PHARMACIST',
          attested_at: now,
          created_at: now,
          updated_at: now}],
      items: [
        {
          ...afterPrepare.items[0],
          dispense_logs: afterPrepare.items[0].dispense_logs.map((entry) =>
            entry.id === 'dlog-2'
              ? { ...entry, status: 'DISPENSED', dispensed_at: now }
              : entry
          )}]};

    pharmacyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    pharmacyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(pendingOrder)
      .mockResolvedValueOnce(afterVoid)
      .mockResolvedValueOnce(afterFinalize)
      .mockResolvedValueOnce(afterFinalize);
    pharmacyWorkspaceRepository.txFindDispenseAttestation
      .mockResolvedValueOnce(null) // existing prepare for new batch
      .mockResolvedValueOnce(null) // existing attest for new batch
      .mockResolvedValueOnce(pendingOrder.dispense_attestations[0]) // void pending prepare
      .mockResolvedValueOnce(afterPrepare.dispense_attestations[0]) // finalize prepare lookup
      .mockResolvedValueOnce(null); // finalize existing attest
    pharmacyWorkspaceRepository.txUpdateManyDispenseLogs.mockResolvedValue({ count: 1 });
    pharmacyWorkspaceRepository.txSoftDeleteDispenseAttestation.mockResolvedValue({});
    pharmacyWorkspaceRepository.txCreateDispenseLog.mockResolvedValue({ id: 'dlog-2' });
    pharmacyWorkspaceRepository.txCreateDispenseAttestation
      .mockResolvedValueOnce({ id: 'att-prep-2' })
      .mockResolvedValueOnce({ id: 'att-attest-2' });
    pharmacyWorkspaceRepository.txFindDispenseLogsByBatch.mockResolvedValue([
      {
        id: 'dlog-2',
        status: 'PENDING',
        quantity_dispensed: 1,
        pharmacy_order_item: afterPrepare.items[0]}]);
    pharmacyWorkspaceRepository.txFindStockByInventoryItemAndFacility.mockResolvedValue({
      id: 'stock-1',
      quantity: 100,
      inventory_item_id: 'inventory-item-internal-1',
      facility_id: 'facility-internal-1',
      inventory_item: {
        id: 'inventory-item-internal-1',
        human_friendly_id: 'INV0000001',
        tenant_id: 'tenant-internal-1',
        name: 'Paracetamol 500mg',
        category: 'MEDICATION',
        sku: 'PCM',
        unit: 'tablet'},
      facility: {
        id: 'facility-internal-1',
        human_friendly_id: 'FAC0000001',
        name: 'Main'}});
    pharmacyWorkspaceRepository.txUpdateInventoryStock.mockResolvedValue({ quantity: 99 });
    pharmacyWorkspaceRepository.txCreateStockMovement.mockResolvedValue({ id: 'move-1' });
    pharmacyWorkspaceRepository.txUpdateDispenseLog.mockResolvedValue({ id: 'dlog-2' });
    pharmacyWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-1' });
    pharmacyWorkspaceRepository.findInventoryStockMetrics.mockResolvedValue([]);
    pharmacyWorkspaceRepository.countOrders.mockResolvedValue(0);
    pharmacyWorkspaceRepository.countDispenseAttestations.mockResolvedValue(0);

    const result = await pharmacyWorkspaceService.prepareDispense(
      'PHO0000001',
      {
        dispense_batch_ref: 'DSPBATCH002',
        finalize: true,
        items: [{ order_item_id: 'POI0000001', quantity: 1 }]},
      'actor-1',
      'PHARMACIST',
      '127.0.0.1',
      mockUser
    );

    expect(result.dispense_batch_ref).toBe('DSPBATCH002');
    expect(pharmacyWorkspaceRepository.txUpdateManyDispenseLogs).toHaveBeenCalled();
    expect(pharmacyWorkspaceRepository.txSoftDeleteDispenseAttestation).toHaveBeenCalled();
    expect(pharmacyWorkspaceRepository.txCreateDispenseAttestation).toHaveBeenCalledTimes(2);
    expect(pharmacyWorkspaceRepository.txUpdateInventoryStock).toHaveBeenCalled();
  });

  it('prepareDispense allows a new batch after a prior batch was fully attested', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');

    const orderBefore = buildOrder({
      status: 'PARTIALLY_DISPENSED',
      items: [
        {
          ...buildOrder().items[0],
          quantity: 11,
          dispense_logs: [
            {
              id: 'dlog-1',
              human_friendly_id: 'DLOG0001',
              pharmacy_order_item_id: 'item-internal-1',
              dispense_batch_ref: 'DSPBATCH001',
              status: 'DISPENSED',
              quantity_dispensed: 5,
              created_at: now,
              updated_at: now}]}],
      dispense_attestations: [
        {
          id: 'att-prep-1',
          human_friendly_id: 'PDA000001',
          pharmacy_order_id: 'order-internal-1',
          dispense_batch_ref: 'DSPBATCH001',
          phase: 'PREPARE',
          attested_by_user_id: 'actor-1',
          attested_role: 'PHARMACIST',
          attested_at: now,
          created_at: now,
          updated_at: now},
        {
          id: 'att-attest-1',
          human_friendly_id: 'PDA000002',
          pharmacy_order_id: 'order-internal-1',
          dispense_batch_ref: 'DSPBATCH001',
          phase: 'ATTEST',
          attested_by_user_id: 'actor-2',
          attested_role: 'PHARMACIST',
          attested_at: now,
          created_at: now,
          updated_at: now}]});

    const orderAfter = {
      ...orderBefore,
      dispense_attestations: [
        ...orderBefore.dispense_attestations,
        {
          id: 'att-prep-2',
          human_friendly_id: 'PDA000003',
          pharmacy_order_id: 'order-internal-1',
          dispense_batch_ref: 'DSPBATCH002',
          phase: 'PREPARE',
          attested_by_user_id: 'actor-1',
          attested_role: 'PHARMACIST',
          attested_at: now,
          created_at: now,
          updated_at: now}],
      items: [
        {
          ...orderBefore.items[0],
          dispense_logs: [
            ...orderBefore.items[0].dispense_logs,
            {
              id: 'dlog-2',
              human_friendly_id: 'DLOG0002',
              pharmacy_order_item_id: 'item-internal-1',
              dispense_batch_ref: 'DSPBATCH002',
              status: 'PENDING',
              quantity_dispensed: 6,
              created_at: now,
              updated_at: now}]}]};

    pharmacyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    pharmacyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(orderBefore)
      .mockResolvedValueOnce(orderAfter);
    pharmacyWorkspaceRepository.txFindDispenseAttestation
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null);
    pharmacyWorkspaceRepository.txCreateDispenseLog.mockResolvedValue({ id: 'dlog-2' });
    pharmacyWorkspaceRepository.txCreateDispenseAttestation.mockResolvedValue({ id: 'att-prep-2' });

    const result = await pharmacyWorkspaceService.prepareDispense(
      'PHO0000001',
      {
        dispense_batch_ref: 'DSPBATCH002',
        finalize: false,
        items: [{ order_item_id: 'POI0000001', quantity: 6 }]},
      'actor-1',
      'PHARMACIST',
      '127.0.0.1',
      mockUser
    );

    expect(result.dispense_batch_ref).toBe('DSPBATCH002');
    expect(pharmacyWorkspaceRepository.txCreateDispenseLog).toHaveBeenCalledTimes(1);
    expect(pharmacyWorkspaceRepository.txCreateDispenseAttestation).toHaveBeenCalledTimes(1);
  });

  it('getPharmacyWorkbench applies inpatient location filter and serializes order location', async () => {
    const inpatientOrder = buildOrder({
      encounter: {
        id: 'encounter-internal-1',
        human_friendly_id: 'ENC0000001',
        encounter_type: 'IPD'}});

    pharmacyWorkspaceRepository.findManyOrders.mockResolvedValue([inpatientOrder]);
    pharmacyWorkspaceRepository.countOrders.mockResolvedValue(0);
    pharmacyWorkspaceRepository.countDispenseAttestations.mockResolvedValue(0);

    const result = await pharmacyWorkspaceService.getPharmacyWorkbench(
      { location: 'INPATIENT' },
      1,
      20,
      null,
      'desc',
      mockUser
    );

    expect(result.worklist).toHaveLength(1);
    expect(result.worklist[0].location).toBe('INPATIENT');
    expect(result.worklist[0].encounter_type).toBe('IPD');
    expect(result.summary).toHaveProperty('discharge_pending_queue');
    expect(result.summary).toHaveProperty('outpatient_queue');
    expect(result.summary).toHaveProperty('ward_queue');
    expect(result.summary).toHaveProperty('pending_payment_queue');

    const [whereArg] = pharmacyWorkspaceRepository.findManyOrders.mock.calls[0];
    expect(JSON.stringify(whereArg)).toContain('encounter_type');
    expect(JSON.stringify(whereArg)).toContain('IPD');
  });

  it('getPharmacyWorkbench discharge filter scopes to open inpatient orders', async () => {
    pharmacyWorkspaceRepository.findManyOrders.mockResolvedValue([]);
    pharmacyWorkspaceRepository.countOrders.mockResolvedValue(0);
    pharmacyWorkspaceRepository.countDispenseAttestations.mockResolvedValue(0);

    await pharmacyWorkspaceService.getPharmacyWorkbench(
      { location: 'DISCHARGE' },
      1,
      20,
      null,
      'desc',
      mockUser
    );

    const [whereArg] = pharmacyWorkspaceRepository.findManyOrders.mock.calls[0];
    const serialized = JSON.stringify(whereArg);
    expect(serialized).toContain('PARTIALLY_DISPENSED');
    expect(serialized).toContain('encounter_type');
  });

  it('getPharmacyWorkbench pending payment filter matches unsettled billing and scopes to open orders', async () => {
    pharmacyWorkspaceRepository.findManyOrders.mockResolvedValue([]);
    pharmacyWorkspaceRepository.countOrders.mockResolvedValue(0);
    pharmacyWorkspaceRepository.countDispenseAttestations.mockResolvedValue(0);

    await pharmacyWorkspaceService.getPharmacyWorkbench(
      { pending_payment: true },
      1,
      20,
      null,
      'desc',
      mockUser
    );

    const [whereArg] = pharmacyWorkspaceRepository.findManyOrders.mock.calls[0];
    const serialized = JSON.stringify(whereArg);
    expect(serialized).toContain('PENDING');
    expect(serialized).toContain('PARTIAL');
    expect(serialized).toContain('UNPAID');
    // Pending payment claims only open orders.
    expect(serialized).toContain('PARTIALLY_DISPENSED');
    expect(serialized).toContain('ORDERED');
  });

  it('getPharmacyWorkbench New orders exclude payment-gated orders', async () => {
    pharmacyWorkspaceRepository.findManyOrders.mockResolvedValue([]);
    pharmacyWorkspaceRepository.countOrders.mockResolvedValue(0);
    pharmacyWorkspaceRepository.countDispenseAttestations.mockResolvedValue(0);

    await pharmacyWorkspaceService.getPharmacyWorkbench(
      { status: 'ORDERED', payment_cleared: true },
      1,
      20,
      null,
      'desc',
      mockUser
    );

    const [whereArg] = pharmacyWorkspaceRepository.findManyOrders.mock.calls[0];
    expect(whereArg.status).toBe('ORDERED');
    expect(JSON.stringify(whereArg)).toContain('NOT');
  });

  it('getPharmacyWorkbench open_orders lists ORDERED and PARTIALLY_DISPENSED', async () => {
    pharmacyWorkspaceRepository.findManyOrders.mockResolvedValue([]);
    pharmacyWorkspaceRepository.countOrders.mockResolvedValue(0);
    pharmacyWorkspaceRepository.countDispenseAttestations.mockResolvedValue(0);

    await pharmacyWorkspaceService.getPharmacyWorkbench(
      { open_orders: true },
      1,
      20,
      null,
      'desc',
      mockUser
    );

    const [whereArg] = pharmacyWorkspaceRepository.findManyOrders.mock.calls[0];
    expect(whereArg.status).toBeUndefined();
    const serialized = JSON.stringify(whereArg);
    expect(serialized).toContain('ORDERED');
    expect(serialized).toContain('PARTIALLY_DISPENSED');
    // Pending KPI includes unpaid opens — do not force payment_cleared.
    expect(serialized).not.toContain('"NOT"');
  });

  it('getPharmacyWorkbench summary buckets keep search filters', async () => {
    pharmacyWorkspaceRepository.findManyOrders.mockResolvedValue([]);
    pharmacyWorkspaceRepository.countOrders.mockResolvedValue(1);
    pharmacyWorkspaceRepository.countDispenseAttestations.mockResolvedValue(0);

    await pharmacyWorkspaceService.getPharmacyWorkbench(
      { search: 'Noah', status: 'ORDERED', payment_cleared: true },
      1,
      20,
      null,
      'desc',
      mockUser
    );

    // countOrders is called for list total + each summary bucket; every call
    // should retain the search clause while section gates are bucket-specific.
    expect(pharmacyWorkspaceRepository.countOrders.mock.calls.length).toBeGreaterThan(1);
    for (const [whereArg] of pharmacyWorkspaceRepository.countOrders.mock.calls) {
      const serialized = JSON.stringify(whereArg);
      expect(serialized).toContain('Noah');
    }
  });

  it('getPharmacyWorkbench Completed orders are scoped to the current day', async () => {
    pharmacyWorkspaceRepository.findManyOrders.mockResolvedValue([]);
    pharmacyWorkspaceRepository.countOrders.mockResolvedValue(0);
    pharmacyWorkspaceRepository.countDispenseAttestations.mockResolvedValue(0);

    await pharmacyWorkspaceService.getPharmacyWorkbench(
      { status: 'DISPENSED', today_only: true },
      1,
      20,
      null,
      'desc',
      mockUser
    );

    const [whereArg] = pharmacyWorkspaceRepository.findManyOrders.mock.calls[0];
    expect(whereArg.status).toBe('DISPENSED');
    expect(JSON.stringify(whereArg)).toContain('updated_at');
  });

  it('getPharmacyWorkbench partial stock filter scopes to depleted or partially dispensed orders', async () => {
    pharmacyWorkspaceRepository.findManyOrders.mockResolvedValue([]);
    pharmacyWorkspaceRepository.countOrders.mockResolvedValue(0);
    pharmacyWorkspaceRepository.countDispenseAttestations.mockResolvedValue(0);

    await pharmacyWorkspaceService.getPharmacyWorkbench(
      { partial_stock: true, urgent: true },
      1,
      20,
      null,
      'desc',
      mockUser
    );

    const [whereArg] = pharmacyWorkspaceRepository.findManyOrders.mock.calls[0];
    const serialized = JSON.stringify(whereArg);
    expect(serialized).toContain('PARTIALLY_DISPENSED');
    expect(serialized).toContain('STAT');
  });

  it('attestDispense rejects same-user second attestation', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    pharmacyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback({}));
    pharmacyWorkspaceRepository.txFindOrderById.mockResolvedValue(buildOrder());
    pharmacyWorkspaceRepository.txFindDispenseAttestation
      .mockResolvedValueOnce({
        id: 'att-prep-1',
        phase: 'PREPARE',
        attested_by_user_id: 'actor-1'})
      .mockResolvedValueOnce(null);

    await expect(
      pharmacyWorkspaceService.attestDispense(
        'PHO0000001',
        { dispense_batch_ref: 'DSPBATCH001' },
        'actor-1',
        'PHARMACIST',
        '127.0.0.1',
        mockUser
      )
    ).rejects.toBeInstanceOf(HttpError);
  });

  it('recordOrderBilling persists billing through workspace service', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    const refreshedOrder = buildOrder();
    pharmacyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => {
      const tx = {
        patient: {
          findFirst: jest.fn().mockResolvedValue({
            id: 'patient-internal-1',
            tenant_id: 'tenant-internal-1',
            facility_id: 'facility-internal-1'})}};
      return callback(tx);
    });
    pharmacyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(buildOrder())
      .mockResolvedValueOnce(refreshedOrder);
    pharmacyWorkspaceRepository.countOrders.mockResolvedValue(1);
    pharmacyWorkspaceRepository.countDispenseAttestations.mockResolvedValue(0);

    const result = await pharmacyWorkspaceService.recordOrderBilling(
      'PHO0000001',
      { billing: { payment_status: 'PAID', total_amount: '10.00' } },
      'actor-1',
      'PHARMACIST',
      '127.0.0.1',
      mockUser
    );

    expect(persistPharmacyOrderBilling).toHaveBeenCalled();
    expect(result.workflow).toBeDefined();
    expect(result.order_summary).toHaveProperty('pending_payment_queue');
  });

  it('cancelPharmacyOrder cancels items and clears billing snapshot', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    const billedOrder = buildOrder({
      billing_snapshot: {
        payment_status: 'PENDING',
        invoice_id: 'invoice-1',
        line_items: [
          {
            id: 'drug-internal-1',
            label: 'Paracetamol',
            quantity: 10,
            unit_price: 100,
            line_total: '1000'}]}});
    const cancelledOrder = buildOrder({
      status: 'CANCELLED',
      billing_snapshot: null,
      items: [
        {
          ...billedOrder.items[0],
          status: 'CANCELLED'}]});

    const tx = {
      pharmacy_order_item: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 })},
      pharmacy_order: {
        update: jest.fn().mockResolvedValue({ id: 'order-internal-1' })}};

    pharmacyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback(tx)
    );
    pharmacyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(billedOrder)
      .mockResolvedValueOnce(cancelledOrder);
    pharmacyWorkspaceRepository.txUpdateManyDispenseLogs.mockResolvedValue({ count: 0 });
    pharmacyWorkspaceRepository.txUpdateOrder.mockResolvedValue({ id: 'order-internal-1' });
    pharmacyWorkspaceRepository.countOrders.mockResolvedValue(0);
    pharmacyWorkspaceRepository.countDispenseAttestations.mockResolvedValue(0);

    const result = await pharmacyWorkspaceService.cancelPharmacyOrder(
      'PHO0000001',
      { reason: 'Duplicate order; Out of stock' },
      'actor-1',
      'PHARMACIST',
      '127.0.0.1',
      mockUser
    );

    expect(tx.pharmacy_order_item.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { status: 'CANCELLED' }})
    );
    expect(pharmacyWorkspaceRepository.txUpdateOrder).toHaveBeenCalledWith(
      tx,
      'order-internal-1',
      { status: 'CANCELLED' }
    );
    expect(reverseClinicalRequestBilling).toHaveBeenCalled();
    expect(tx.pharmacy_order.update).toHaveBeenCalledWith({
      where: { id: 'order-internal-1' },
      data: { billing_snapshot: null }});
    expect(result.workflow.order.status).toBe('CANCELLED');
  });

  it('cancelPharmacyOrderItem rebuilds unpaid billing for remaining lines', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-1');
    const secondItem = {
      id: 'item-internal-2',
      human_friendly_id: 'POI0000002',
      pharmacy_order_id: 'order-internal-1',
      drug_id: 'drug-internal-2',
      quantity: 5,
      status: 'ACTIVE',
      dosage: '1 tab',
      frequency: 'ONCE',
      route: 'ORAL',
      created_at: now,
      updated_at: now,
      dispense_logs: [],
      drug: {
        id: 'drug-internal-2',
        human_friendly_id: 'DRG0000002',
        name: 'Amoxicillin',
        code: 'AMX',
        inventory_maps: []}};
    const orderBefore = buildOrder({
      billing_snapshot: {
        payment_status: 'PENDING',
        invoice_id: 'invoice-1',
        line_items: [
          {
            id: 'drug-internal-1',
            label: 'Paracetamol',
            quantity: 10,
            unit_price: 100,
            line_total: '1000'},
          {
            id: 'drug-internal-2',
            label: 'Amoxicillin',
            quantity: 5,
            unit_price: 200,
            line_total: '1000'}]},
      items: [buildOrder().items[0], secondItem]});
    const orderAfterCancel = {
      ...orderBefore,
      items: [
        { ...orderBefore.items[0], status: 'CANCELLED' },
        secondItem]};

    const tx = {
      pharmacy_order_item: {
        update: jest.fn().mockResolvedValue({ id: 'item-internal-1' })}};

    pharmacyWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback(tx)
    );
    pharmacyWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(orderBefore)
      .mockResolvedValueOnce(orderAfterCancel)
      .mockResolvedValueOnce(orderAfterCancel);
    pharmacyWorkspaceRepository.txUpdateManyDispenseLogs.mockResolvedValue({ count: 0 });
    pharmacyWorkspaceRepository.countOrders.mockResolvedValue(1);
    pharmacyWorkspaceRepository.countDispenseAttestations.mockResolvedValue(0);

    await pharmacyWorkspaceService.cancelPharmacyOrderItem(
      'PHO0000001',
      'POI0000001',
      { reason: 'Patient refused medication' },
      'actor-1',
      'PHARMACIST',
      '127.0.0.1',
      mockUser
    );

    expect(tx.pharmacy_order_item.update).toHaveBeenCalledWith({
      where: { id: 'item-internal-1' },
      data: { status: 'CANCELLED' }});
    expect(persistPharmacyOrderBilling).toHaveBeenCalled();
    const billingArg = persistPharmacyOrderBilling.mock.calls[0][1].billing;
    expect(billingArg.line_items).toHaveLength(1);
    expect(billingArg.line_items[0].id).toBe('drug-internal-2');
  });
});
