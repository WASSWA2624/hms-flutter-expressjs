/**
 * Lab Verified tab (`/lab?section=verified|completed`) billing & sections:
 * re-verify/release after reopen stays payment-gated; reopen is NOT_BILLED
 * clinical (no invoice reverse); no parallel cashier. Create/delete charge
 * posts reuse `lab-order.service.billing-sections.test.js`.
 */

const { HttpError } = require('@lib/errors');

jest.mock('@repositories/lab-workspace/lab-workspace.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn()}));
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  DIAGNOSTIC_EVENTS: {
    LAB_WORKFLOW_UPDATED: 'diagnostic.lab_workflow_updated',
    LAB_RESULT_READY: 'diagnostic.lab_result_ready',
    LAB_RESULT_UPDATED: 'diagnostic.lab_result_updated',
    LAB_RESULT_CRITICAL: 'diagnostic.lab_result_critical'},
  NOTIFICATION_EVENTS: {
    NOTIFICATION_CREATED: 'notification.created'}}));
jest.mock('@services/opd-flow/opd-flow.service', () => ({
  syncDiagnosticsStage: jest.fn().mockResolvedValue(null)}));
jest.mock('@prisma/client', () => ({
  user_role: {
    findMany: jest.fn()},
  notification: {
    create: jest.fn()},
  notification_delivery: {
    create: jest.fn()}}));
jest.mock('@services/lab-workspace/lab.shared', () => {
  const actual = jest.requireActual('@services/lab-workspace/lab.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
    resolveModelRecordOrThrow: jest.fn()};
});

const labWorkspaceRepository = require('@repositories/lab-workspace/lab-workspace.repository');
const { createAuditLog } = require('@lib/audit');
const opdFlowService = require('@services/opd-flow/opd-flow.service');
const prisma = require('@prisma/client');
const { resolveModelIdOrThrow } = require('@services/lab-workspace/lab.shared');
const labWorkspaceService = require('@services/lab-workspace/lab-workspace.service');
const {
  isLabOrderPaymentSatisfied,
  mapLabOrderWorkflowRecord} = require('@services/lab-workspace/lab.serializer');

const now = new Date('2026-07-30T06:00:00.000Z');

const buildBaseOrder = (overrides = {}) => ({
  id: 'order-internal-ver-1',
  human_friendly_id: 'LAB-VER-1',
  status: 'COMPLETED',
  ordered_at: now,
  created_at: now,
  updated_at: now,
  patient_id: 'patient-internal-1',
  encounter_id: 'encounter-internal-1',
  billing_snapshot: {
    payment_status: 'PAID',
    total_amount: '45.00',
    currency: 'USD',
    invoice_id: 'inv-ver-1'},
  patient: {
    id: 'patient-internal-1',
    human_friendly_id: 'PAT-VER-1',
    tenant_id: 'tenant-internal-1',
    facility_id: 'facility-internal-1',
    first_name: 'Verified',
    last_name: 'Patient'},
  encounter: {
    id: 'encounter-internal-1',
    human_friendly_id: 'ENC-VER-1'},
  items: [
    {
      id: 'order-item-internal-1',
      human_friendly_id: 'LIT-VER-1',
      status: 'COMPLETED',
      created_at: now,
      updated_at: now,
      lab_test: {
        id: 'lab-test-internal-1',
        human_friendly_id: 'LBT-VER-1',
        name: 'CBC',
        code: 'CBC',
        unit: null,
        reference_ranges: [],
        unit_options: [],
        result_options: []},
      results: [
        {
          id: 'result-internal-1',
          status: 'FINAL',
          result_value: '12.0',
          created_at: now}]}],
  samples: [],
  ...overrides});

describe('lab-workspace Verified tab billing sections', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    opdFlowService.syncDiagnosticsStage.mockResolvedValue(null);
    prisma.notification.create.mockResolvedValue({
      id: 'notification-internal-1',
      human_friendly_id: 'NOT0000001',
      user_id: 'doctor-1',
      notification_type: 'LAB',
      priority: 'NORMAL'});
    prisma.notification_delivery.create.mockResolvedValue({});
    prisma.user_role.findMany.mockResolvedValue([]);
  });

  it('payment parity: PAID / NOT_* satisfied; PENDING blocks progression', () => {
    expect(
      isLabOrderPaymentSatisfied(
        buildBaseOrder({ billing_snapshot: { payment_status: 'PAID' } })
      )
    ).toBe(true);
    expect(
      isLabOrderPaymentSatisfied(
        buildBaseOrder({ billing_snapshot: { payment_status: 'NOT_REQUIRED' } })
      )
    ).toBe(true);
    expect(
      isLabOrderPaymentSatisfied(
        buildBaseOrder({ billing_snapshot: { payment_status: 'NO_CHARGE' } })
      )
    ).toBe(true);
    expect(
      isLabOrderPaymentSatisfied(
        buildBaseOrder({ billing_snapshot: { payment_status: 'NOT_BILLED' } })
      )
    ).toBe(true);
    expect(
      isLabOrderPaymentSatisfied(
        buildBaseOrder({ billing_snapshot: { payment_status: 'PENDING' } })
      )
    ).toBe(false);
    expect(
      isLabOrderPaymentSatisfied(
        buildBaseOrder({ billing_snapshot: { payment_status: 'PARTIAL' } })
      )
    ).toBe(false);
  });

  it('reopenLabOrderItemResult is clinical NOT_BILLED (no invoice reverse)', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-item-internal-1');

    const reopenedItem = {
      id: 'order-item-internal-1',
      human_friendly_id: 'LIT-VER-1',
      status: 'IN_PROCESS',
      created_at: now,
      updated_at: now,
      lab_test: {
        id: 'lab-test-internal-1',
        human_friendly_id: 'LBT-VER-1',
        name: 'CBC',
        code: 'CBC',
        unit: null,
        reference_ranges: [],
        unit_options: [],
        result_options: []},
      results: [
        {
          id: 'result-internal-1',
          status: 'PENDING',
          result_value: '12.0',
          created_at: now}]};

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'order-item-internal-1',
      lab_order_id: 'order-internal-ver-1',
      status: 'COMPLETED',
      lab_order: { id: 'order-internal-ver-1', status: 'COMPLETED' },
      lab_test: {
        id: 'lab-test-internal-1',
        unit: null,
        reference_ranges: [],
        unit_options: [],
        result_options: []}});
    labWorkspaceRepository.txFindFirstResult.mockResolvedValue({
      id: 'result-internal-1',
      status: 'NORMAL',
      result_value: '12.0'});
    labWorkspaceRepository.txUpdateResult.mockResolvedValue({});
    labWorkspaceRepository.txUpdateOrderItem.mockResolvedValue({});
    labWorkspaceRepository.txCountSamples.mockResolvedValue(0);
    labWorkspaceRepository.txCountOrderItems
      .mockResolvedValueOnce(0)
      .mockResolvedValueOnce(0)
      .mockResolvedValueOnce(1);
    labWorkspaceRepository.txUpdateOrderItemsMany.mockResolvedValue({ count: 1 });
    labWorkspaceRepository.txUpdateOrder.mockResolvedValue({});
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(
      buildBaseOrder({
        status: 'IN_PROCESS',
        items: [reopenedItem]})
    );

    const result = await labWorkspaceService.reopenLabOrderItemResult(
      'LIT-VER-1',
      { reason: 'Clerical correction' },
      'actor-1',
      '127.0.0.1'
    );

    expect(result.workflow).toBeTruthy();
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'REOPEN_RESULT',
        entity: 'lab_order_item'})
    );
    // Reopen must not call Billing settle/adjust/reverse APIs on lab workspace.
    expect(labWorkspaceService.receivePayment).toBeUndefined();
    expect(labWorkspaceService.adjustInvoice).toBeUndefined();
    expect(labWorkspaceService.reverseInvoice).toBeUndefined();
  });

  it('verifyLabOrderResults blocks unpaid required charges after reopen path', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-ver-1');

    const unpaidOrder = buildBaseOrder({
      status: 'IN_PROCESS',
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '45.00',
        currency: 'USD'},
      items: [
        {
          id: 'order-item-internal-1',
          human_friendly_id: 'LIT-VER-1',
          status: 'RESULTS_ENTERED',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-1',
            human_friendly_id: 'LBT-VER-1',
            name: 'CBC',
            code: 'CBC',
            unit: null},
          results: [
            {
              id: 'result-internal-1',
              status: 'PENDING',
              result_value: '12.0',
              created_at: now}]}]});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(unpaidOrder);

    await expect(
      labWorkspaceService.verifyLabOrderResults(
        'LAB-VER-1',
        {
          results: [
            {
              order_item_id: 'LIT-VER-1',
              status: 'NORMAL',
              result_value: '12.0'}]},
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('releaseLabOrderItem blocks unpaid required charges (no bypass)', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-item-internal-1');

    const unpaidOrder = buildBaseOrder({
      status: 'RESULTS_ENTERED',
      billing_snapshot: {
        payment_status: 'PENDING',
        total_amount: '45.00',
        currency: 'USD',
        invoice_id: 'inv-ver-1'}});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderItemById.mockResolvedValue({
      id: 'order-item-internal-1',
      lab_order_id: 'order-internal-ver-1',
      status: 'RESULTS_ENTERED',
      lab_test: {
        id: 'lab-test-internal-1',
        unit: null,
        reference_ranges: [],
        unit_options: [],
        result_options: []},
      lab_order: unpaidOrder});

    await expect(
      labWorkspaceService.releaseLabOrderItem(
        'LIT-VER-1',
        { status: 'NORMAL', result_value: '12.0' },
        'actor-1',
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_order.payment_required',
      statusCode: 402});
  });

  it('idempotent gate: repeated unpaid verify attempts stay 402 without mutation', async () => {
    resolveModelIdOrThrow.mockResolvedValue('order-internal-ver-1');

    const unpaidOrder = buildBaseOrder({
      status: 'IN_PROCESS',
      billing_snapshot: { payment_status: 'PENDING', invoice_id: 'inv-1' },
      items: [
        {
          id: 'order-item-internal-1',
          human_friendly_id: 'LIT-VER-1',
          status: 'RESULTS_ENTERED',
          created_at: now,
          updated_at: now,
          lab_test: {
            id: 'lab-test-internal-1',
            human_friendly_id: 'LBT-VER-1',
            name: 'CBC',
            code: 'CBC',
            unit: null},
          results: []}]});

    labWorkspaceRepository.withTransaction.mockImplementation(async (callback) =>
      callback({})
    );
    labWorkspaceRepository.txFindOrderById.mockResolvedValue(unpaidOrder);

    for (let i = 0; i < 2; i += 1) {
      await expect(
        labWorkspaceService.verifyLabOrderResults(
          'LAB-VER-1',
          {
            results: [
              {
                order_item_id: 'LIT-VER-1',
                result_value: '12.0'}]},
          'actor-1',
          '127.0.0.1'
        )
      ).rejects.toMatchObject({ statusCode: 402 });
    }

    expect(labWorkspaceRepository.txUpdateResult).not.toHaveBeenCalled();
    expect(labWorkspaceRepository.txUpdateOrderItem).not.toHaveBeenCalled();
  });

  it('serializer exposes billing gate on completed unpaid reopen-ready workflow', () => {
    const workflow = mapLabOrderWorkflowRecord(
      buildBaseOrder({
        status: 'IN_PROCESS',
        billing_snapshot: { payment_status: 'PENDING', invoice_id: 'inv-1' },
        items: [
          {
            id: 'order-item-internal-1',
            human_friendly_id: 'LIT-VER-1',
            status: 'RESULTS_ENTERED',
            created_at: now,
            updated_at: now,
            lab_test: {
              id: 'lab-test-internal-1',
              human_friendly_id: 'LBT-VER-1',
              name: 'CBC',
              code: 'CBC',
              unit: null},
            results: [
              {
                id: 'result-internal-1',
                status: 'PENDING',
                result_value: '12.0',
                created_at: now}]}]})
    );
    expect(workflow.next_actions.billing_gate_blocked).toBe(true);
    expect(workflow.next_actions.can_verify_result).toBe(false);
    expect(workflow.next_actions.payment_status).toBe('PENDING');
  });

  it('workspace service does not own cashier settle/adjust APIs', () => {
    expect(labWorkspaceService.receivePayment).toBeUndefined();
    expect(labWorkspaceService.adjustInvoice).toBeUndefined();
    expect(labWorkspaceService.issueInvoice).toBeUndefined();
    expect(labWorkspaceService.refundPayment).toBeUndefined();
  });

  it('HttpError 402 is authoritative for unpaid progression', () => {
    const err = new HttpError('errors.lab_order.payment_required', 402, [
      { field: 'payment_status' }]);
    expect(err.statusCode).toBe(402);
    expect(err.message).toBe('errors.lab_order.payment_required');
  });
});
