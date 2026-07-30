/**
 * Mortuary Custody tab billing-sections scan (`/mortuary?panel=custody`).
 *
 * Custody list/detail inherits case payer + billing_status (continuity).
 * No module cashier; billable fees post via persistMortuaryBillableEventBilling.
 */

jest.mock('@repositories/mortuary-workspace/mortuary-workspace.repository');

const mortuaryWorkspaceRepository = require('@repositories/mortuary-workspace/mortuary-workspace.repository');
const mortuaryWorkspaceService = require('@services/mortuary-workspace/mortuary-workspace.service');
const {
  isMortuaryCustodyLogisticsEvent,
  persistMortuaryBillableEventBilling,
} = require('@lib/billing/mortuary-billing');

const now = new Date('2026-07-30T10:00:00.000Z');

const custodyRow = {
  id: 'custody-uuid-1',
  human_friendly_id: 'MCE0001',
  facility_id: 'facility-1',
  event_type: 'TRANSFER',
  event_at: now,
  actor_name: 'Officer A',
  actor_role: 'MORTUARY_STAFF',
  location_label: 'Cold Room A',
  reason: 'Slot move',
  notes: null,
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
      first_name: 'Custody',
      last_name: 'Patient',
    },
    deceased_profile: {
      id: 'dec-1',
      human_friendly_id: 'DEC0001',
      display_name: 'Custody Patient',
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

describe('mortuary-workspace Custody billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mortuaryWorkspaceRepository.findSummary.mockResolvedValue({
      total_cases: 1,
      identification_pending: 0,
      in_storage: 1,
      release_ready: 0,
      unsettled_billing: 1,
    });
    mortuaryWorkspaceRepository.findQueueCounts.mockResolvedValue({});
    mortuaryWorkspaceRepository.findLookups.mockResolvedValue({
      facilities: [],
      storageUnits: [],
      storageSlots: [],
      deceasedProfiles: [],
      patients: [],
      sourceWorkflows: [],
    });
    mortuaryWorkspaceRepository.findItems.mockResolvedValue({
      items: [custodyRow],
      total: 1,
    });
  });

  it('custody panel maps patient_id + billing_status continuity (parity)', async () => {
    const data = await mortuaryWorkspaceService.getWorkspace(
      { panel: 'custody', page: 1, limit: 20 },
      { tenant_id: 'tenant-1', facility_id: 'facility-1', user_id: 'user-1' },
    );

    expect(data.filters.panel).toBe('custody');
    expect(data.items).toHaveLength(1);
    const item = data.items[0];
    expect(item.resource).toBe('mortuary-custody-events');
    expect(item.patient_id).toBe('PAT0001');
    expect(item.billing_status).toBe('UNSETTLED');
    expect(item.billing_reference_id).toBe('inv-mort-1');
    expect(item.billable_events).toHaveLength(1);
    expect(item.billable_events[0].billing_reference_id).toBe('inv-mort-1');
    expect(item.mortuary_case.billing_status).toBe('UNSETTLED');
    expect(item.mortuary_case.patient_id).toBe('PAT0001');
  });

  it('TRANSFER custody event is logistics — no cash ledger helper required', () => {
    expect(isMortuaryCustodyLogisticsEvent('TRANSFER')).toBe(true);
    expect(typeof persistMortuaryBillableEventBilling).toBe('function');
  });

  it('unauthorized cashier paths are absent from workspace service exports', () => {
    expect(mortuaryWorkspaceService.receivePayment).toBeUndefined();
    expect(mortuaryWorkspaceService.collectPayment).toBeUndefined();
    expect(mortuaryWorkspaceService.issueInvoice).toBeUndefined();
  });
});
