jest.mock('@repositories/maintenance-request/maintenance-request.repository');
jest.mock('@lib/billing/clinical-request-billing', () => ({
  upsertClinicalRequestBilling: jest.fn(),
  receiveClinicalRequestPayment: jest.fn(),
  adjustClinicalRequestBilling: jest.fn(),
}));
jest.mock('@lib/billing/financials', () => ({
  recalculateInvoiceBalances: jest.fn(),
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: (...values) =>
    values.find((entry) => typeof entry === 'string' && entry.trim()) || null,
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value || undefined),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value || undefined),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier),
}));
jest.mock('@prisma/client', () => ({
  user_role: {
    findMany: jest.fn().mockResolvedValue([]),
  },
  $transaction: jest.fn(),
  equipment_registry: {
    findUnique: jest.fn(),
  },
  user: {
    findUnique: jest.fn(),
  },
  maintenance_request: {
    update: jest.fn(),
  },
  equipment_work_order: {
    create: jest.fn(),
  },
}));
jest.mock('@lib/websocket', () => ({
  emitToUsers: jest.fn(),
  HOUSEKEEPING_EVENTS: {
    HOUSEKEEPING_WORKSPACE_UPDATED: 'HOUSEKEEPING_WORKSPACE_UPDATED',
    MAINTENANCE_REQUEST_TRIAGED: 'MAINTENANCE_REQUEST_TRIAGED',
    MAINTENANCE_REQUEST_CONVERTED: 'MAINTENANCE_REQUEST_CONVERTED',
  },
}));

const maintenanceRequestRepository = require('@repositories/maintenance-request/maintenance-request.repository');
const clinicalRequestBilling = require('@lib/billing/clinical-request-billing');
const financials = require('@lib/billing/financials');
const { createAuditLog } = require('@lib/audit');
const maintenanceRequestService = require('@services/maintenance-request/maintenance-request.service');

/**
 * Billing & sections scan for Housekeeping Maintenance requests tab.
 * Facility maintenance create / triage / complete / cancel stay NOT_BILLED
 * and must never post patient Billing ledger rows. Patient-billable room
 * turnover surcharges are not mounted on this tab.
 */
describe('maintenance-request Maintenance requests billing-sections scan', () => {
  const openRequest = {
    id: 'mr-uuid',
    human_friendly_id: 'MR-100',
    status: 'OPEN',
    description: 'Fix leaking tap',
    reported_at: new Date('2026-07-01T08:00:00.000Z'),
    resolved_at: null,
    facility_id: 'facility-uuid',
    asset_id: 'asset-uuid',
    created_at: new Date('2026-07-01T08:00:00.000Z'),
    updated_at: new Date('2026-07-01T08:00:00.000Z'),
    facility: {
      id: 'facility-uuid',
      human_friendly_id: 'FAC-001',
      name: 'Main Campus',
    },
    asset: {
      id: 'asset-uuid',
      human_friendly_id: 'AST-001',
      name: 'Tap-12',
      asset_tag: 'TAP-12',
      tenant_id: 'tenant-123',
    },
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('list Maintenance requests does not touch patient billing ledger', async () => {
    maintenanceRequestRepository.findMany.mockResolvedValue([openRequest]);
    maintenanceRequestRepository.count.mockResolvedValue(1);

    const data = await maintenanceRequestService.listMaintenanceRequests(
      {},
      1,
      20,
      'created_at',
      'desc'
    );

    expect(data.maintenanceRequests).toHaveLength(1);
    expect(data.maintenanceRequests[0].id).toBe('MR-100');
    expect(data.maintenanceRequests[0].status).toBe('OPEN');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('list Maintenance requests is idempotent on replay (no double billing post)', async () => {
    maintenanceRequestRepository.findMany.mockResolvedValue([openRequest]);
    maintenanceRequestRepository.count.mockResolvedValue(1);

    const first = await maintenanceRequestService.listMaintenanceRequests(
      {},
      1,
      20,
      undefined,
      'desc'
    );
    const second = await maintenanceRequestService.listMaintenanceRequests(
      {},
      1,
      20,
      undefined,
      'desc'
    );

    expect(first.maintenanceRequests).toEqual(second.maintenanceRequests);
    expect(maintenanceRequestRepository.findMany).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('serializes Maintenance requests without local paid flags or balances', async () => {
    maintenanceRequestRepository.findMany.mockResolvedValue([openRequest]);
    maintenanceRequestRepository.count.mockResolvedValue(1);

    const data = await maintenanceRequestService.listMaintenanceRequests(
      {},
      1,
      20,
      undefined,
      'desc'
    );
    const item = data.maintenanceRequests[0];

    expect(item).not.toHaveProperty('payment_status');
    expect(item).not.toHaveProperty('balance');
    expect(item).not.toHaveProperty('amount_due');
    expect(item).not.toHaveProperty('paid');
    expect(item).not.toHaveProperty('invoice_id');
  });

  it('Request maintenance create stays NOT_BILLED (no patient ledger post)', async () => {
    maintenanceRequestRepository.create.mockResolvedValue(openRequest);

    const result = await maintenanceRequestService.createMaintenanceRequest(
      {
        facility_id: 'FAC-001',
        asset_id: 'AST-001',
        status: 'OPEN',
        description: 'Fix leaking tap',
        reported_at: '2026-07-01T08:00:00.000Z',
      },
      'user-123',
      '127.0.0.1'
    );

    expect(result.id).toBe('MR-100');
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('balance');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'maintenance_request',
      })
    );
  });

  it('Complete request (update COMPLETED) stays NOT_BILLED', async () => {
    maintenanceRequestRepository.findById.mockResolvedValue(openRequest);
    maintenanceRequestRepository.update.mockResolvedValue({
      ...openRequest,
      status: 'COMPLETED',
      resolved_at: new Date('2026-07-01T10:00:00.000Z'),
    });

    const result = await maintenanceRequestService.updateMaintenanceRequest(
      'MR-100',
      { status: 'COMPLETED', resolved_at: '2026-07-01T10:00:00.000Z' },
      'user-123',
      '127.0.0.1'
    );

    expect(result.status).toBe('COMPLETED');
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('balance');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('Cancel request stays NOT_BILLED', async () => {
    maintenanceRequestRepository.findById.mockResolvedValue(openRequest);
    maintenanceRequestRepository.update.mockResolvedValue({
      ...openRequest,
      status: 'CANCELLED',
    });

    const result = await maintenanceRequestService.updateMaintenanceRequest(
      'MR-100',
      { status: 'CANCELLED' },
      'user-123',
      '127.0.0.1'
    );

    expect(result.status).toBe('CANCELLED');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('Triage handoff stays NOT_BILLED', async () => {
    maintenanceRequestRepository.findById.mockResolvedValue(openRequest);
    maintenanceRequestRepository.update.mockResolvedValue({
      ...openRequest,
      status: 'IN_PROGRESS',
      description: `${openRequest.description}\n\n[TRIAGE] sla_hours=4`,
    });

    const result = await maintenanceRequestService.triageMaintenanceRequest(
      'MR-100',
      {
        status: 'IN_PROGRESS',
        sla_hours: 4,
        triage_summary: 'Assigned for plumbing',
      },
      'user-123',
      '127.0.0.1'
    );

    expect(result.status).toBe('IN_PROGRESS');
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('balance');
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
    expect(financials.recalculateInvoiceBalances).not.toHaveBeenCalled();
  });

  it('create replay does not duplicate billing posts', async () => {
    maintenanceRequestRepository.create.mockResolvedValue(openRequest);

    const payload = {
      facility_id: 'FAC-001',
      status: 'OPEN',
      description: 'Replay request',
      reported_at: '2026-07-01T08:00:00.000Z',
    };

    await maintenanceRequestService.createMaintenanceRequest(
      payload,
      'user-123',
      '127.0.0.1'
    );
    await maintenanceRequestService.createMaintenanceRequest(
      payload,
      'user-123',
      '127.0.0.1'
    );

    expect(maintenanceRequestRepository.create).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('triage replay does not duplicate billing posts', async () => {
    maintenanceRequestRepository.findById.mockResolvedValue(openRequest);
    maintenanceRequestRepository.update.mockResolvedValue({
      ...openRequest,
      status: 'IN_PROGRESS',
    });

    await maintenanceRequestService.triageMaintenanceRequest(
      'MR-100',
      { status: 'IN_PROGRESS', triage_summary: 'replay-a' },
      'user-123',
      '127.0.0.1'
    );
    await maintenanceRequestService.triageMaintenanceRequest(
      'MR-100',
      { status: 'IN_PROGRESS', triage_summary: 'replay-b' },
      'user-123',
      '127.0.0.1'
    );

    expect(maintenanceRequestRepository.update).toHaveBeenCalledTimes(2);
    expect(clinicalRequestBilling.upsertClinicalRequestBilling).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
  });

  it('status parity: request status remains ops telemetry (NOT_BILLED), not ledger balance', async () => {
    maintenanceRequestRepository.findById.mockResolvedValue(openRequest);

    const result = await maintenanceRequestService.getMaintenanceRequestById('MR-100');

    expect(result.status).toBe('OPEN');
    expect(result).not.toHaveProperty('payment_status');
    expect(result).not.toHaveProperty('balance');
    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });

  it('read-only list path cannot settle or adjust via Maintenance request handlers', async () => {
    maintenanceRequestRepository.findMany.mockResolvedValue([openRequest]);
    maintenanceRequestRepository.count.mockResolvedValue(1);

    await maintenanceRequestService.listMaintenanceRequests({}, 1, 20, undefined, 'desc');

    expect(clinicalRequestBilling.receiveClinicalRequestPayment).not.toHaveBeenCalled();
    expect(clinicalRequestBilling.adjustClinicalRequestBilling).not.toHaveBeenCalled();
  });
});
