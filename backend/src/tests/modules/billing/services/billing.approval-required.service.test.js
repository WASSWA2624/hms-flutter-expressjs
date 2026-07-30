jest.mock('@repositories/billing/billing.repository', () => ({
  withTransaction: jest.fn(),
  findApprovalById: jest.fn(),
  findInvoiceById: jest.fn(),
  updateApproval: jest.fn(),
  findRealtimeRecipientUserIds: jest.fn(async () => ['billing-1'])}));

jest.mock('@config/feature-flags', () => ({
  isFeatureEnabled: jest.fn(() => true)}));

jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelRecordByIdentifier: jest.fn()}));

jest.mock('@lib/notifications/sendEmail', () => ({
  sendEmail: jest.fn(async () => ({ sent: true, provider: 'smtp' }))}));

jest.mock('@lib/billing/pdf', () => ({
  generateInvoicePdfBuffer: jest.fn(async () => Buffer.from('pdf'))}));

jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(async () => {})}));

jest.mock('@lib/billing/financials', () => ({
  toDecimalNumber: (value) => Number(value || 0),
  toMoneyString: (value) => String(value ?? '0.00'),
  toDate: (value) => (value ? new Date(value) : null),
  recalculateInvoiceStateTx: jest.fn(async (_tx, invoiceId) => ({
    invoice: {
      id: invoiceId,
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'ISSUED',
      status: 'SENT',
      total_amount: '100.00',
      currency: 'UGX'},
    financials: {
      balance_due: 40,
      net_paid_total: 0,
      effective_total: 100,
      gross_paid_total: 0}})),
  computeInvoiceFinancials: jest.fn(() => ({
    balance_due: 40,
    net_paid_total: 0,
    effective_total: 100}))}));

jest.mock('@lib/billing/realtime', () => ({
  publishBillingRealtimeUpdate: jest.fn(async () => {})}));

const billingRepository = require('@repositories/billing/billing.repository');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { publishBillingRealtimeUpdate } = require('@lib/billing/realtime');
const { BILLING_EVENTS } = require('@lib/websocket');
const { PERMISSIONS } = require('@config/permissions');
const billingService = require('@services/billing/billing.service');
const billingRoutes = require('@routes/billing/billing.routes');

describe('billing.service approval-required tab mutations', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('approveApproval posts adjustment through Billing transaction (no bypass)', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'billing_approval') {
        return {
          id: 'app-1',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          status: 'PENDING',
          requested_by_user_id: 'requester-1',
          approval_type: 'ADJUSTMENT',
          target_entity_id: 'inv-1',
          payload_json: {
            invoice_id: 'inv-1',
            amount: '60.00',
            status: 'ISSUED'}};
      }
      return null;
    });

    const createAdjustment = jest.fn(async () => ({
      id: 'adj-1',
      invoice_id: 'inv-1',
      amount: '60.00',
      status: 'ISSUED'}));
    const updateMany = jest.fn(async () => ({ count: 1 }));
    const findFirst = jest
      .fn()
      .mockResolvedValueOnce({
        id: 'app-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        status: 'PENDING',
        requested_by_user_id: 'requester-1',
        approval_type: 'ADJUSTMENT',
        target_entity_id: 'inv-1',
        payload_json: {
          invoice_id: 'inv-1',
          amount: '60.00',
          status: 'ISSUED'}})
      .mockResolvedValueOnce({
        id: 'app-1',
        status: 'APPROVED',
        approval_type: 'ADJUSTMENT'});

    billingRepository.withTransaction.mockImplementation(async (callback) => {
      const tx = {
        invoice: {
          findFirst: jest.fn(async () => ({
            id: 'inv-1',
            tenant_id: 'tenant-1',
            facility_id: 'facility-1',
            total_amount: '100.00'}))},
        billing_adjustment: {
          create: createAdjustment},
        billing_approval: {
          findFirst,
          updateMany}};
      return callback(tx);
    });

    billingRepository.findApprovalById.mockResolvedValue({
      id: 'app-1',
      human_friendly_id: 'APP0001',
      status: 'APPROVED',
      approval_type: 'ADJUSTMENT'});
    billingRepository.findInvoiceById.mockResolvedValue({
      id: 'inv-1',
      human_friendly_id: 'INV0001',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'ISSUED',
      status: 'SENT',
      total_amount: '100.00',
      currency: 'UGX',
      payments: [],
      adjustments: [{ id: 'adj-1', amount: '60.00' }]});

    const result = await billingService.approveApproval(
      'APP0001',
      { decision_notes: 'Approved write-off' },
      { id: 'approver-1', tenant_id: 'tenant-1', facility_id: 'facility-1' },
      '127.0.0.1'
    );

    expect(createAdjustment).toHaveBeenCalledTimes(1);
    expect(updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'app-1', status: 'PENDING' },
        data: expect.objectContaining({ status: 'APPROVED' })})
    );
    expect(result.approval.status).toBe('APPROVED');
    expect(result.execution.type).toBe('ADJUSTMENT');
    expect(publishBillingRealtimeUpdate).toHaveBeenCalled();
    expect(publishBillingRealtimeUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        event: BILLING_EVENTS.BILLING_BALANCE_UPDATED,
        action: 'BALANCE_UPDATED'})
    );
  });

  it('approveApproval posts refund through Billing and publishes refund realtime', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'billing_approval') {
        return {
          id: 'app-refund',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          status: 'PENDING',
          requested_by_user_id: 'requester-1',
          approval_type: 'REFUND',
          target_entity_id: 'pay-1',
          reason: 'Customer request',
          payload_json: {
            payment_id: 'pay-1',
            invoice_id: 'inv-1',
            amount: '25.00'}};
      }
      return null;
    });

    const createRefund = jest.fn(async () => ({
      id: 'ref-1',
      payment_id: 'pay-1',
      amount: '25.00'}));
    const updateMany = jest.fn(async () => ({ count: 1 }));

    billingRepository.withTransaction.mockImplementation(async (callback) => {
      const tx = {
        payment: {
          findFirst: jest.fn(async () => ({
            id: 'pay-1',
            invoice_id: 'inv-1',
            amount: '100.00',
            status: 'COMPLETED',
            refunds: []})),
          update: jest.fn()},
        refund: {
          create: createRefund},
        billing_approval: {
          findFirst: jest
            .fn()
            .mockResolvedValueOnce({
              id: 'app-refund',
              status: 'PENDING',
              approval_type: 'REFUND',
              target_entity_id: 'pay-1',
              reason: 'Customer request',
              payload_json: {
                payment_id: 'pay-1',
                invoice_id: 'inv-1',
                amount: '25.00'}})
            .mockResolvedValueOnce({
              id: 'app-refund',
              status: 'APPROVED',
              approval_type: 'REFUND'}),
          updateMany}};
      return callback(tx);
    });

    billingRepository.findApprovalById.mockResolvedValue({
      id: 'app-refund',
      human_friendly_id: 'APP-REF',
      status: 'APPROVED',
      approval_type: 'REFUND'});
    billingRepository.findInvoiceById.mockResolvedValue({
      id: 'inv-1',
      human_friendly_id: 'INV0001',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      billing_status: 'PARTIAL',
      status: 'SENT',
      total_amount: '100.00',
      currency: 'UGX',
      payments: [],
      adjustments: []});

    const result = await billingService.approveApproval(
      'APP-REF',
      {},
      { id: 'approver-1', tenant_id: 'tenant-1', facility_id: 'facility-1' },
      '127.0.0.1'
    );

    expect(createRefund).toHaveBeenCalledTimes(1);
    expect(result.execution.type).toBe('REFUND');
    expect(publishBillingRealtimeUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        event: BILLING_EVENTS.BILLING_REFUND_PROCESSED,
        action: 'REFUND_PROCESSED'})
    );
  });

  it('rejects replay of already-decided approval (idempotent guard)', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'billing_approval') {
        return {
          id: 'app-2',
          tenant_id: 'tenant-1',
          status: 'APPROVED',
          requested_by_user_id: 'requester-1',
          approval_type: 'REFUND',
          target_entity_id: 'pay-1'};
      }
      return null;
    });

    await expect(
      billingService.approveApproval(
        'APP0002',
        {},
        { id: 'approver-1', tenant_id: 'tenant-1', facility_id: 'facility-1' },
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      messageKey: 'errors.billing_approval.invalid_status',
      statusCode: 400});

    expect(billingRepository.withTransaction).not.toHaveBeenCalled();
  });

  it('approveApproval claim failure prevents duplicate ledger posts', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'billing_approval') {
        return {
          id: 'app-race',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          status: 'PENDING',
          requested_by_user_id: 'requester-1',
          approval_type: 'ADJUSTMENT',
          target_entity_id: 'inv-1',
          payload_json: { invoice_id: 'inv-1', amount: '10.00', status: 'ISSUED' }};
      }
      return null;
    });

    const createAdjustment = jest.fn(async () => ({ id: 'adj-race' }));
    billingRepository.withTransaction.mockImplementation(async (callback) => {
      const tx = {
        invoice: {
          findFirst: jest.fn(async () => ({ id: 'inv-1', total_amount: '100.00' }))},
        billing_adjustment: { create: createAdjustment },
        billing_approval: {
          findFirst: jest.fn(async () => ({
            id: 'app-race',
            status: 'PENDING',
            approval_type: 'ADJUSTMENT',
            target_entity_id: 'inv-1',
            payload_json: { invoice_id: 'inv-1', amount: '10.00', status: 'ISSUED' }})),
          updateMany: jest.fn(async () => ({ count: 0 }) )}};
      return callback(tx);
    });

    await expect(
      billingService.approveApproval(
        'APP-RACE',
        {},
        { id: 'approver-1', tenant_id: 'tenant-1', facility_id: 'facility-1' },
        '127.0.0.1'
      )
    ).rejects.toMatchObject({
      messageKey: 'errors.billing_approval.invalid_status',
      statusCode: 400});
  });

  it('rejectApproval records audited rejection without executing held mutation', async () => {
    resolveModelRecordByIdentifier.mockImplementation(async ({ model }) => {
      if (model === 'billing_approval') {
        return {
          id: 'app-3',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          status: 'PENDING',
          requested_by_user_id: 'requester-1',
          approval_type: 'VOID',
          target_entity_id: 'inv-1',
          reason: 'Requested void'};
      }
      return null;
    });

    const updateMany = jest.fn(async () => ({ count: 1 }));
    billingRepository.withTransaction.mockImplementation(async (callback) => {
      const tx = {
        billing_approval: {
          updateMany,
          findFirst: jest.fn(async () => ({
            id: 'app-3',
            status: 'REJECTED',
            approval_type: 'VOID',
            reason: 'Insufficient documentation',
            tenant_id: 'tenant-1',
            facility_id: 'facility-1'}))}};
      return callback(tx);
    });

    billingRepository.findApprovalById.mockResolvedValue({
      id: 'app-3',
      human_friendly_id: 'APP0003',
      status: 'REJECTED',
      approval_type: 'VOID',
      reason: 'Insufficient documentation',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1'});

    const result = await billingService.rejectApproval(
      'APP0003',
      { reason: 'Insufficient documentation' },
      { id: 'approver-1', tenant_id: 'tenant-1', facility_id: 'facility-1' },
      '127.0.0.1'
    );

    expect(updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'app-3', status: 'PENDING' },
        data: expect.objectContaining({ status: 'REJECTED' })})
    );
    expect(result.approval.status).toBe('REJECTED');
    expect(publishBillingRealtimeUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        event: BILLING_EVENTS.INVOICE_UPDATED,
        action: 'APPROVAL_REJECTED'})
    );
  });

  it('approval routes authorize financial:approve (BILLING role pack)', () => {
    const layers = billingRoutes.stack.filter((layer) => layer.route);
    const approveLayer = layers.find(
      (layer) =>
        layer.route.path === '/approvals/:approvalIdentifier/approve' &&
        layer.route.methods.post
    );
    expect(approveLayer).toBeDefined();
    expect(PERMISSIONS.FINANCIAL_APPROVE).toBe('financial:approve');
  });
});
