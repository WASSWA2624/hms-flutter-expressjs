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
const billingService = require('@services/billing/billing.service');

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
    const updateApproval = jest.fn(async () => ({
      id: 'app-1',
      status: 'APPROVED',
      approval_type: 'ADJUSTMENT'}));

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
          update: updateApproval}};
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
    expect(updateApproval).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'app-1' },
        data: expect.objectContaining({ status: 'APPROVED' })})
    );
    expect(result.approval.status).toBe('APPROVED');
    expect(result.execution.type).toBe('ADJUSTMENT');
    expect(publishBillingRealtimeUpdate).toHaveBeenCalled();
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

    billingRepository.updateApproval.mockResolvedValue({
      id: 'app-3',
      status: 'REJECTED',
      approval_type: 'VOID',
      reason: 'Insufficient documentation'});
    billingRepository.findApprovalById.mockResolvedValue({
      id: 'app-3',
      human_friendly_id: 'APP0003',
      status: 'REJECTED',
      approval_type: 'VOID',
      reason: 'Insufficient documentation'});

    const result = await billingService.rejectApproval(
      'APP0003',
      { reason: 'Insufficient documentation' },
      { id: 'approver-1', tenant_id: 'tenant-1', facility_id: 'facility-1' },
      '127.0.0.1'
    );

    expect(billingRepository.updateApproval).toHaveBeenCalledWith(
      'app-3',
      expect.objectContaining({ status: 'REJECTED' })
    );
    expect(billingRepository.withTransaction).not.toHaveBeenCalled();
    expect(result.approval.status).toBe('REJECTED');
  });
});
