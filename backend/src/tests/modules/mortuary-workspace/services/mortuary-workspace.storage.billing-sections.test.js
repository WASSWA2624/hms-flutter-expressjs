/**
 * Mortuary Storage tab billing-sections scan (`/mortuary?panel=storage`).
 *
 * Storage assignments inherit case payer + billing_status (continuity).
 * Assign storage is logistics (STORAGE_ASSIGNED / NOT_REQUIRED).
 * No module cashier; billable fees post via persistMortuaryBillableEventBilling.
 */

jest.mock('@repositories/mortuary-workspace/mortuary-workspace.repository');
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: (...values) => {
    for (const value of values) {
      if (typeof value === 'string' && value.trim() && !/^[0-9a-f-]{36}$/i.test(value.trim())) {
        return value.trim();
      }
    }
    return null;
  },
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value || null),
}));

const mortuaryWorkspaceRepository = require('@repositories/mortuary-workspace/mortuary-workspace.repository');
const mortuaryWorkspaceService = require('@services/mortuary-workspace/mortuary-workspace.service');
const {
  isMortuaryCustodyLogisticsEvent,
  persistMortuaryBillableEventBilling,
  aggregateMortuaryCaseBillingStatus,
  resolveMortuaryChargeKey,
  MORTUARY_CHARGE_KEYS,
} = require('@lib/billing/mortuary-billing');

const now = new Date('2026-07-30T10:00:00.000Z');

const storageAssignmentRow = {
  id: 'assign-uuid-1',
  human_friendly_id: 'MSA0001',
  facility_id: 'facility-1',
  assignment_status: 'ACTIVE',
  assigned_at: now,
  ended_at: null,
  reason: null,
  created_at: now,
  updated_at: now,
  facility: {
    id: 'facility-1',
    human_friendly_id: 'FAC1',
    name: 'Demo Facility',
  },
  storage_unit: {
    id: 'unit-1',
    human_friendly_id: 'MSU0001',
    name: 'Cold Unit A',
  },
  storage_slot: {
    id: 'slot-1',
    human_friendly_id: 'MSS0001',
    label: 'Slot 12',
    slot_code: 'A-12',
    status: 'OCCUPIED',
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
      first_name: 'Storage',
      last_name: 'Patient',
    },
    deceased_profile: {
      id: 'dec-1',
      human_friendly_id: 'DEC0001',
      display_name: 'Storage Patient',
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

describe('mortuary-workspace Storage billing-sections scan', () => {
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
      items: [storageAssignmentRow],
      total: 1,
    });
  });

  it('storage panel maps patient_id + billing_status continuity (parity)', async () => {
    const data = await mortuaryWorkspaceService.getWorkspace(
      { panel: 'storage' },
      1,
      20,
      undefined,
      'desc',
      { tenant_id: 'tenant-1', facility_id: 'facility-1', user_id: 'user-1' },
    );

    expect(data.filters.panel).toBe('storage');
    expect(data.items).toHaveLength(1);
    const item = data.items[0];
    expect(item.resource).toBe('mortuary-storage-assignments');
    expect(item.patient_id).toBe('PAT0001');
    expect(item.billing_status).toBe('PENDING');
    expect(item.billing_reference_id).toBe('inv-mort-1');
    expect(item.billable_events).toHaveLength(1);
    expect(item.billable_events[0].billing_reference_id).toBe('inv-mort-1');
    expect(item.mortuary_case.billing_status).toBe('PENDING');
    expect(item.mortuary_case.patient_id).toBe('PAT0001');
  });

  it('STORAGE_ASSIGNED is logistics — no cash ledger helper required', () => {
    expect(isMortuaryCustodyLogisticsEvent('STORAGE_ASSIGNED')).toBe(true);
    expect(isMortuaryCustodyLogisticsEvent('MOVED')).toBe(true);
    expect(resolveMortuaryChargeKey('STORAGE_FEE')).toBe(
      MORTUARY_CHARGE_KEYS.STORAGE,
    );
    expect(typeof persistMortuaryBillableEventBilling).toBe('function');
    expect(aggregateMortuaryCaseBillingStatus(['PENDING'], 'UNSETTLED')).toBe(
      'PENDING',
    );
  });

  it('unauthorized cashier paths are absent from workspace service exports', () => {
    expect(mortuaryWorkspaceService.receivePayment).toBeUndefined();
    expect(mortuaryWorkspaceService.collectPayment).toBeUndefined();
    expect(mortuaryWorkspaceService.issueInvoice).toBeUndefined();
    expect(mortuaryWorkspaceService.applyDiscount).toBeUndefined();
  });
});
