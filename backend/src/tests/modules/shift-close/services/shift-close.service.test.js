jest.mock('@repositories/shift-close/shift-close.repository');
jest.mock('@repositories/office-context/office-context.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(async () => ({})),
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier),
}));
jest.mock('@lib/last-office/events', () => ({
  LAST_OFFICE_EVENTS: {
    LAST_OFFICE_SHIFT_CLOSE_APPROVED: 'last_office.shift_close.approved',
    LAST_OFFICE_SHIFT_CLOSE_SUBMITTED: 'last_office.shift_close.submitted',
  },
  emitLastOfficeEvent: jest.fn(async () => ({})),
}));
jest.mock('@lib/telemetry/metrics', () => ({
  recordWorkflowEvent: jest.fn(),
}));
jest.mock('@middlewares/auth.middleware', () => ({
  getUserPermissions: jest.fn(),
}));

const shiftCloseRepository = require('@repositories/shift-close/shift-close.repository');
const { createAuditLog } = require('@lib/audit');
const { emitLastOfficeEvent } = require('@lib/last-office/events');
const { getUserPermissions } = require('@middlewares/auth.middleware');
const shiftCloseService = require('@services/shift-close/shift-close.service');

const buildShiftClose = (overrides = {}) => ({
  id: 'shift-close-uuid',
  human_friendly_id: 'SCL-001',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  branch_id: null,
  office_context_id: 'office-context-1',
  shift_id: 'shift-1',
  closed_by_user_id: 'user-billing',
  approved_by_user_id: null,
  status: 'SUBMITTED',
  totals_json: { cash_sales: 120 },
  reconciliation_json: { discrepancies: [] },
  expected_amount: '120.00',
  actual_amount: '120.00',
  variance_amount: '0.00',
  submitted_at: '2026-04-09T08:00:00.000Z',
  approved_at: null,
  notes: null,
  evidence_json: { till: 'TILL-1' },
  etag: 'etag-1',
  version: 1,
  created_at: '2026-04-09T08:00:00.000Z',
  updated_at: '2026-04-09T08:00:00.000Z',
  deleted_at: null,
  ...overrides,
});

describe('shift-close.service approval rules', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('rejects approval when the actor lacks an approval permission', async () => {
    shiftCloseRepository.findById.mockResolvedValue(buildShiftClose());
    getUserPermissions.mockReturnValue([]);

    const approvalAttempt = shiftCloseService.approveShiftClose('SCL-001', {}, {
        tenant_id: 'tenant-1',
        user_id: 'user-ops',
        user: { role: 'NURSE', roles: ['NURSE'] },
      });

    await expect(approvalAttempt).rejects.toMatchObject({ statusCode: 403 });

    expect(shiftCloseRepository.update).not.toHaveBeenCalled();
  });

  it('approves a submitted shift close and emits the workflow event', async () => {
    const current = buildShiftClose();
    const updated = buildShiftClose({
      status: 'APPROVED',
      approved_by_user_id: 'user-ops',
      approved_at: '2026-04-09T08:30:00.000Z',
      notes: 'Balanced and approved',
      version: 2,
      etag: 'etag-2',
    });

    shiftCloseRepository.findById.mockResolvedValue(current);
    shiftCloseRepository.update.mockResolvedValue(updated);
    getUserPermissions.mockReturnValue(['last_office:approve']);

    const result = await shiftCloseService.approveShiftClose(
      'SCL-001',
      { notes: 'Balanced and approved' },
      {
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        user_id: 'user-ops',
        user: { role: 'OPERATIONS', roles: ['OPERATIONS'] },
        ip_address: '127.0.0.1',
        user_agent: 'jest',
      }
    );

    expect(shiftCloseRepository.update).toHaveBeenCalledWith(
      'shift-close-uuid',
      expect.objectContaining({
        status: 'APPROVED',
        approved_by_user_id: 'user-ops',
        version: 2,
      })
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'UPDATE',
        entity: 'shift_close',
        entity_id: 'shift-close-uuid',
      })
    );
    expect(emitLastOfficeEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
      })
    );
    expect(result).toEqual(expect.objectContaining({
      id: 'SCL-001',
      status: 'APPROVED',
      approved_by_user_id: 'user-ops',
    }));
  });
});
