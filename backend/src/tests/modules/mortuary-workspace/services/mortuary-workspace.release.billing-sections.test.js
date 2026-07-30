/**
 * Mortuary Release tab billing-sections scan (`/mortuary?panel=release`).
 *
 * Release list/detail inherits case payer + billing_status (continuity).
 * Unsettled billing queue lives on this panel. No module cashier; release
 * fees post via persistMortuaryBillableEventBilling.
 */

jest.mock('@repositories/mortuary-workspace/mortuary-workspace.repository');
jest.mock('@prisma/client', () => ({}));
jest.mock('@lib/billing/identifiers', () => ({
  resolvePublicIdentifier: (...values) => {
    for (const value of values) {
      if (
        typeof value === 'string' &&
        value.trim() &&
        !/^[0-9a-f-]{36}$/i.test(value.trim())
      ) {
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
  isMortuaryReleaseBlockedByOutstandingBilling,
  persistMortuaryBillableEventBilling,
  MORTUARY_CHARGE_KEYS,
  resolveMortuaryChargeKey,
} = require('@lib/billing/mortuary-billing');

const now = new Date('2026-07-30T10:00:00.000Z');

const releaseRow = {
  id: 'release-uuid-1',
  human_friendly_id: 'MRA0001',
  facility_id: 'facility-1',
  status: 'PENDING_APPROVAL',
  recipient_name: 'Next of Kin',
  recipient_relationship: 'Spouse',
  verification_reference: 'ID-99',
  funeral_service_name: 'City Funeral',
  release_method: 'FAMILY',
  approved_by_name: null,
  approved_at: null,
  released_at: null,
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
    status: 'READY_FOR_RELEASE',
    identification_status: 'VERIFIED',
    received_at: now,
    release_ready_at: now,
    released_at: null,
    billing_status: 'UNSETTLED',
    patient: {
      id: 'patient-uuid-1',
      human_friendly_id: 'PAT0001',
      first_name: 'Release',
      last_name: 'Patient',
    },
    deceased_profile: {
      id: 'dec-1',
      human_friendly_id: 'DEC0001',
      display_name: 'Release Patient',
      external_reference: null,
    },
    billable_events: [
      {
        id: 'mbe-uuid-rel',
        human_friendly_id: 'MBE0002',
        event_type: 'RELEASE_FEE',
        description: 'Release preparation',
        amount: '75.00',
        currency: 'UGX',
        status: 'PENDING',
        billing_reference_id: 'inv-mort-rel-1',
        charged_at: now,
        settled_at: null,
      },
    ],
  },
};

describe('mortuary-workspace Release billing-sections scan', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mortuaryWorkspaceRepository.findSummary.mockResolvedValue({
      total_cases: 1,
      identification_pending: 0,
      in_storage: 0,
      release_ready: 1,
      unsettled_billing: 1,
    });
    mortuaryWorkspaceRepository.findQueueCounts.mockResolvedValue({
      UNSETTLED_BILLING: 1,
      RELEASE_READY: 1,
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
      items: [releaseRow],
      total: 1,
    });
  });

  it('release panel maps patient_id + billing_status continuity (parity)', async () => {
    const data = await mortuaryWorkspaceService.getWorkspace(
      { panel: 'release' },
      1,
      20,
      undefined,
      'desc',
      { tenant_id: 'tenant-1', facility_id: 'facility-1', user_id: 'user-1' },
    );

    expect(data.filters.panel).toBe('release');
    expect(data.items).toHaveLength(1);
    const item = data.items[0];
    expect(item.resource).toBe('mortuary-release-authorisations');
    expect(item.patient_id).toBe('PAT0001');
    expect(item.billing_status).toBe('PENDING');
    expect(item.billing_reference_id).toBe('inv-mort-rel-1');
    expect(item.billable_events).toHaveLength(1);
    expect(item.billable_events[0].billing_reference_id).toBe('inv-mort-rel-1');
    expect(item.billable_events[0].event_type).toBe('RELEASE_FEE');
    expect(item.mortuary_case.billing_status).toBe('PENDING');
    expect(item.mortuary_case.patient_id).toBe('PAT0001');
    expect(item.recipient_name).toBe('Next of Kin');
    expect(isMortuaryReleaseBlockedByOutstandingBilling(item.billing_status)).toBe(
      true,
    );
  });

  it('unsettled billing queue is scoped to release panel', async () => {
    const data = await mortuaryWorkspaceService.getWorkspace(
      { panel: 'release' },
      1,
      20,
      undefined,
      'desc',
      { tenant_id: 'tenant-1', facility_id: 'facility-1', user_id: 'user-1' },
    );
    const summaryUnsettled = (data.summary || []).find(
      (row) => row.id === 'unsettled_billing',
    );
    const queueUnsettled = (data.queue_summaries || []).find(
      (row) => row.queue === 'UNSETTLED_BILLING',
    );
    expect(summaryUnsettled?.value).toBe(1);
    expect(queueUnsettled?.count).toBe(1);
    expect(queueUnsettled?.panel).toBe('release');
  });

  it('RELEASE_FEE maps to MORTUARY_RELEASE and posts via shared helper', () => {
    expect(resolveMortuaryChargeKey('RELEASE_FEE')).toBe(
      MORTUARY_CHARGE_KEYS.RELEASE,
    );
    expect(typeof persistMortuaryBillableEventBilling).toBe('function');
    expect(isMortuaryReleaseBlockedByOutstandingBilling('UNSETTLED')).toBe(
      true,
    );
  });

  it('unauthorized cashier paths are absent from workspace service exports', () => {
    expect(mortuaryWorkspaceService.receivePayment).toBeUndefined();
    expect(mortuaryWorkspaceService.collectPayment).toBeUndefined();
    expect(mortuaryWorkspaceService.issueInvoice).toBeUndefined();
    expect(mortuaryWorkspaceService.approveRelease).toBeUndefined();
  });
});
