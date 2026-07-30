/**
 * Lab workspace Pending verification (`/lab?section=pending-verification`)
 * billing gates: verify/release must not bypass Billing payment status.
 */

jest.mock('@repositories/lab-workspace/lab-workspace.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined)}));
jest.mock('@lib/realtime', () => ({
  publishDomainEvent: jest.fn().mockResolvedValue(undefined)}));
jest.mock('@services/lab-workspace/lab.realtime', () => ({
  resolveLabRealtimeRecipients: jest.fn().mockResolvedValue([])}));
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  DIAGNOSTIC_EVENTS: {},
  NOTIFICATION_EVENTS: {}}));
jest.mock('@services/lab-workspace/lab.shared', () => {
  const actual = jest.requireActual('@services/lab-workspace/lab.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn()};
});

const labWorkspaceRepository = require('@repositories/lab-workspace/lab-workspace.repository');
const { resolveModelIdOrThrow } = require('@services/lab-workspace/lab.shared');
const {
  isLabOrderPaymentSatisfied,
  mapLabOrderWorkflowRecord} = require('@services/lab-workspace/lab.serializer');
const labWorkspaceService = require('@services/lab-workspace/lab-workspace.service');

const now = new Date('2026-07-30T08:00:00.000Z');

const buildOrder = (overrides = {}) => ({
  id: 'order-internal-pv-1',
  human_friendly_id: 'LAB-PV-1',
  patient_id: 'patient-internal-1',
  encounter_id: 'encounter-internal-1',
  status: 'IN_PROCESS',
  ordered_at: now,
  created_at: now,
  updated_at: now,
  billing_snapshot: {
    payment_status: 'PENDING',
    invoice_id: 'inv-pv-1',
    total_amount: '35.00',
    currency: 'USD'},
  patient: {
    id: 'patient-internal-1',
    human_friendly_id: 'PAT-PV-1',
    first_name: 'Pending',
    last_name: 'Verify',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1'},
  encounter: {
    id: 'encounter-internal-1',
    human_friendly_id: 'ENC-PV-1'},
  items: [
    {
      id: 'item-internal-pv-1',
      human_friendly_id: 'LIT-PV-1',
      status: 'IN_PROCESS',
      lab_order_id: 'order-internal-pv-1',
      created_at: now,
      updated_at: now,
      lab_test: {
        id: 'lab-test-1',
        human_friendly_id: 'LBT-1',
        name: 'Glucose',
        code: 'GLU',
        unit: 'mmol/L',
        result_kind: 'NUMERIC',
        reference_ranges: [],
        unit_options: [],
        result_options: []},
      results: [
        {
          id: 'result-pv-1',
          result_value: '5.4',
          status: 'ENTERED',
          created_at: now,
          updated_at: now}]}],
  samples: [
    {
      id: 'sample-pv-1',
      status: 'RECEIVED',
      collected_at: now,
      received_at: now,
      created_at: now,
      updated_at: now}],
  ...overrides});

describe('lab-workspace pending-verification billing gates', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('blocks verify-results when Billing payment_status is PENDING', async () => {
    resolveModelIdOrThrow
      .mockResolvedValueOnce('order-internal-pv-1')
      .mockResolvedValueOnce('item-internal-pv-1');
    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(buildOrder());

    await expect(
      labWorkspaceService.verifyLabOrderResults(
        'LAB-PV-1',
        {
          results: [
            {
              order_item_id: 'LIT-PV-1',
              result_value: '5.4'}]},
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('blocks releaseLabOrderItem when Billing payment_status is PENDING', async () => {
    resolveModelIdOrThrow.mockResolvedValue('item-internal-pv-1');
    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'item-internal-pv-1',
      status: 'IN_PROCESS',
      lab_order_id: 'order-internal-pv-1',
      lab_order: buildOrder(),
      lab_test: {
        id: 'lab-test-1',
        unit: 'mmol/L',
        result_kind: 'NUMERIC',
        reference_ranges: [],
        unit_options: [],
        result_options: []},
      results: [
        {
          id: 'result-pv-1',
          result_value: '5.4',
          status: 'ENTERED'}]});

    await expect(
      labWorkspaceService.releaseLabOrderItem(
        'LIT-PV-1',
        { result_value: '5.4' },
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('allows verify-results when payment_status is PAID (Billing parity)', async () => {
    const paidOrder = buildOrder({
      billing_snapshot: {
        payment_status: 'PAID',
        invoice_id: 'inv-pv-paid',
        total_amount: '35.00',
        currency: 'USD'}});
    expect(isLabOrderPaymentSatisfied(paidOrder)).toBe(true);

    resolveModelIdOrThrow
      .mockResolvedValueOnce('order-internal-pv-1')
      .mockResolvedValueOnce('item-internal-pv-1');
    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById
      .mockResolvedValueOnce(paidOrder)
      .mockResolvedValueOnce({
        ...paidOrder,
        status: 'COMPLETED',
        items: [
          {
            ...paidOrder.items[0],
            status: 'COMPLETED'}]});
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      ...paidOrder.items[0],
      lab_order: paidOrder,
      lab_test: paidOrder.items[0].lab_test});
    labWorkspaceRepository.txUpsertResult.mockResolvedValue({
      id: 'result-pv-1',
      result_value: '5.4',
      status: 'RELEASED'});
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({
      ...paidOrder.items[0],
      status: 'COMPLETED'});
    labWorkspaceRepository.txUpdateOrder.mockResolvedValue({
      ...paidOrder,
      status: 'COMPLETED'});

    const result = await labWorkspaceService.verifyLabOrderResults(
      'LAB-PV-1',
      {
        results: [
          {
            order_item_id: 'LIT-PV-1',
            result_value: '5.4'}]},
      'actor-1',
      '127.0.0.1'
    );
    expect(result?.workflow || result?.order || result).toBeTruthy();
  });

  it('serializer hides verify/release when billing gate blocked (results queue)', () => {
    const workflow = mapLabOrderWorkflowRecord(buildOrder());
    expect(workflow.next_actions.billing_gate_blocked).toBe(true);
    expect(workflow.next_actions.can_verify_result).toBe(false);
    expect(workflow.next_actions.can_release_result).toBe(false);
    expect(workflow.next_actions.can_verify_all).toBe(false);
    expect(workflow.next_actions.payment_status).toBe('PENDING');
  });

  it('explicit NOT_REQUIRED / NO_CHARGE / NOT_BILLED / PAID satisfy the gate', () => {
    for (const status of ['NOT_REQUIRED', 'NO_CHARGE', 'NOT_BILLED', 'PAID']) {
      expect(
        isLabOrderPaymentSatisfied({
          billing_snapshot: { payment_status: status }})
      ).toBe(true);
    }
    expect(
      isLabOrderPaymentSatisfied({
        billing_snapshot: { payment_status: 'PENDING' }})
    ).toBe(false);
  });

  it('idempotent gate: unpaid verify rejected twice without side effects', async () => {
    resolveModelIdOrThrow
      .mockResolvedValue('order-internal-pv-1');
    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(buildOrder());

    const payload = {
      results: [{ order_item_id: 'LIT-PV-1', result_value: '5.4' }]};

    await expect(
      labWorkspaceService.verifyLabOrderResults(
        'LAB-PV-1',
        payload,
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toMatchObject({ statusCode: 402 });
    await expect(
      labWorkspaceService.verifyLabOrderResults(
        'LAB-PV-1',
        payload,
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toMatchObject({ statusCode: 402 });

    expect(labWorkspaceRepository.txUpsertResult).not.toHaveBeenCalled();
    expect(labWorkspaceRepository.txUpdateOrderItem).not.toHaveBeenCalled();
  });

  it('lab workspace does not own receive-payment / adjust (no bypass cashier)', () => {
    expect(labWorkspaceService.receivePayment).toBeUndefined();
    expect(labWorkspaceService.adjustInvoice).toBeUndefined();
    expect(labWorkspaceService.verifyLabOrderResults).toEqual(expect.any(Function));
    expect(labWorkspaceService.releaseLabOrderItem).toEqual(expect.any(Function));
  });
});
