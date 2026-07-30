/**
 * Mortuary Reports tab billing-sections scan (`/mortuary?panel=reporting`).
 *
 * Post-mortem / reporting list inherits case payer + billing_status (continuity).
 * No module cashier; billable fees post via persistMortuaryBillableEventBilling.
 */

jest.mock('@repositories/mortuary-workspace/mortuary-workspace.repository');

const mortuaryWorkspaceRepository = require('@repositories/mortuary-workspace/mortuary-workspace.repository');
const mortuaryWorkspaceService = require('@services/mortuary-workspace/mortuary-workspace.service');
const {
  BILLABLE_SOURCE_MODULES,
} = require('@lib/billing/clinical-request-billing');
const {
  persistMortuaryBillableEventBilling,
  resolveMortuaryChargeKey,
  MORTUARY_CHARGE_KEYS,
} = require('@lib/billing/mortuary-billing');

const now = new Date('2026-07-30T10:00:00.000Z');

const reportingRow = {
  id: 'pm-uuid-1',
  human_friendly_id: 'MPM0001',
  facility_id: 'facility-1',
  requested_by_name: 'Dr. A',
  request_reason: 'Coroner request',
  status: 'SCHEDULED',
  diagnostics_reference_id: 'DX-9',
  scheduled_at: now,
  completed_at: null,
  report_received_at: null,
  created_at: now,
  updated_at: now,
  facility: {
    id: 'facility-1',
    human_friendly_id: 'FAC1',
    name: 'Demo Facility',
  },
  mortuary_case: {
    id: 'case-uuid-1',
    human_friendly_id: 'MOR0001',
    status: 'IN_STORAGE',
    identification_status: 'VERIFIED',
    received_at: now,
    release_ready_at: null,
    released_at: null,
    billing_status: 'UNSETTLED',
    patient: {
      id: 'patient-uuid-1',
      human_friendly_id: 'PAT0001',
      first_name: 'Reports',
      last_name: 'Patient',
    },
    deceased_profile: {
      id: 'dec-1',
      human_friendly_id: 'DEC0001',
      display_name: 'Reports Patient',
      external_reference: null,
    },
    billable_events: [
      {
        id: 'mbe-uuid-1',
        human_friendly_id: 'MBE0001',
        event_type: 'STORAGE_FEE',
        description: 'Cold storage day 1',
        amount: '50.00',
        currency: 'UGX',
        status: 'PENDING',
        billing_reference_id: 'inv-mort-1',
        charged_at: now,
        settled_at: null,
      },
    ],
  },
};

describe('mortuary-workspace Reports billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mortuaryWorkspaceRepository.findSummary.mockResolvedValue({
      total_cases: 1,
      identification_pending: 0,
      in_storage: 1,
      release_ready: 0,
      unsettled_billing: 1,
    });
    mortuaryWorkspaceRepository.findQueueCounts.mockResolvedValue({
      POST_MORTEM_PENDING: 1,
    });
    mortuaryWorkspaceRepository.findLookups.mockResolvedValue({
      facilities: [],
      storageUnits: [],
      storageSlots: [],
      deceasedProfiles: [],
      patients: [],
      sourceWorkflows: [],
    });
    mortuaryWorkspaceRepository.findItems.mockResolvedValue({
      items: [reportingRow],
      total: 1,
    });
  });

  it('reporting panel maps patient_id + billing_status continuity (parity)', async () => {
    const data = await mortuaryWorkspaceService.getWorkspace(
      { panel: 'reporting', page: 1, limit: 20 },
      { tenant_id: 'tenant-1', facility_id: 'facility-1', user_id: 'user-1' },
    );

    expect(data.filters.panel).toBe('reporting');
    expect(data.items).toHaveLength(1);
    const item = data.items[0];
    expect(item.resource).toBe('mortuary-post-mortem-requests');
    expect(item.patient_id).toBe('PAT0001');
    expect(item.billing_status).toBe('PENDING');
    expect(item.billing_reference_id).toBe('inv-mort-1');
    expect(item.billable_events).toHaveLength(1);
    expect(item.billable_events[0].billing_reference_id).toBe('inv-mort-1');
    expect(item.mortuary_case.billing_status).toBe('PENDING');
    expect(item.mortuary_case.patient_id).toBe('PAT0001');
  });

  it('mortuary fees resolve to MORTUARY charge keys (no second ledger)', () => {
    expect(BILLABLE_SOURCE_MODULES.MORTUARY).toBe('MORTUARY');
    expect(resolveMortuaryChargeKey('STORAGE_FEE')).toBe(
      MORTUARY_CHARGE_KEYS.STORAGE,
    );
    expect(resolveMortuaryChargeKey('EMBALMING')).toBe(
      MORTUARY_CHARGE_KEYS.EMBALMING,
    );
    expect(resolveMortuaryChargeKey('VIEWING')).toBe(
      MORTUARY_CHARGE_KEYS.VIEWING,
    );
    expect(resolveMortuaryChargeKey('RELEASE_CHARGE')).toBe(
      MORTUARY_CHARGE_KEYS.RELEASE,
    );
    expect(typeof persistMortuaryBillableEventBilling).toBe('function');
  });

  it('unauthorized cashier paths are absent from workspace service exports', () => {
    expect(mortuaryWorkspaceService.receivePayment).toBeUndefined();
    expect(mortuaryWorkspaceService.collectPayment).toBeUndefined();
    expect(mortuaryWorkspaceService.issueInvoice).toBeUndefined();
    expect(mortuaryWorkspaceService.adjustInvoice).toBeUndefined();
    expect(mortuaryWorkspaceService.refundPayment).toBeUndefined();
  });
});
