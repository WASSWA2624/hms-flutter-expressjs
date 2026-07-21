jest.mock('@repositories/claims-workspace/claims-workspace.repository', () => ({
  countClaims: jest.fn(),
  findManyClaims: jest.fn(),
  countPreAuthorizations: jest.fn(),
  findManyPreAuthorizations: jest.fn(),
  countCoveragePlans: jest.fn(),
  findManyCoveragePlans: jest.fn(),
  findManyInsuranceCompanies: jest.fn(),
  findManyInvoices: jest.fn(),
  countEnrollments: jest.fn(),
  countInvoicesReadyToClaim: jest.fn()}));

const claimsWorkspaceRepository = require('@repositories/claims-workspace/claims-workspace.repository');
const claimsWorkspaceService = require('@services/claims-workspace/claims-workspace.service');

const user = { id: 'user-1', tenant_id: 'tenant-1', facility_id: 'facility-1' };

const preAuth = (overrides = {}) => ({
  id: 'auth-1',
  human_friendly_id: 'AUTH0001',
  coverage_plan_id: 'plan-1',
  coverage_plan: { id: 'plan-1', human_friendly_id: 'COV0001', name: 'Corporate Plan', provider_name: 'Acme', tenant_id: 'tenant-1' },
  patient_id: 'patient-1',
  patient: { id: 'patient-1', human_friendly_id: 'PAT0001', first_name: 'Ada', last_name: 'Lovelace' },
  status: 'PENDING',
  approved_amount: '500000',
  consumed_amount: '125000',
  requested_at: new Date('2026-05-17T08:00:00.000Z'),
  created_at: new Date('2026-05-17T08:00:00.000Z'),
  ...overrides});

const claim = (overrides = {}) => ({
  id: 'claim-1',
  human_friendly_id: 'CLM0001',
  coverage_plan_id: 'plan-1',
  coverage_plan: { id: 'plan-1', human_friendly_id: 'COV0001', name: 'Corporate Plan', provider_name: 'Acme', tenant_id: 'tenant-1' },
  invoice_id: 'invoice-1',
  invoice: {
    id: 'invoice-1',
    human_friendly_id: 'INV0001',
    tenant_id: 'tenant-1',
    facility_id: 'facility-1',
    currency: 'UGX',
    total_amount: '125000',
    patient: { id: 'patient-1', human_friendly_id: 'PAT0001', first_name: 'Ada', last_name: 'Lovelace' }},
  status: 'SUBMITTED',
  submitted_at: new Date('2026-05-18T09:00:00.000Z'),
  created_at: new Date('2026-05-18T09:00:00.000Z'),
  ...overrides});

describe('claims-workspace.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getWorkspace', () => {
    it('aggregates authorization and claim status counts', async () => {
      claimsWorkspaceRepository.countPreAuthorizations.mockImplementation(async (where) => {
        const map = { PENDING: 3, APPROVED: 2, DENIED: 1, EXPIRED: 0 };
        return map[where.status] ?? 0;
      });
      claimsWorkspaceRepository.countClaims.mockImplementation(async (where) => {
        const map = { SUBMITTED: 4, APPROVED: 1, PARTIAL: 0, REJECTED: 2, PAID: 5, CANCELLED: 1 };
        return map[where.status] ?? 0;
      });
      claimsWorkspaceRepository.findManyPreAuthorizations.mockResolvedValue([preAuth()]);
      claimsWorkspaceRepository.findManyClaims.mockResolvedValue([claim()]);
      claimsWorkspaceRepository.countEnrollments.mockResolvedValue(2);
      claimsWorkspaceRepository.countInvoicesReadyToClaim.mockResolvedValue(3);

      const result = await claimsWorkspaceService.getWorkspace({}, user);

      expect(result.summary.authorization_pending).toBe(3);
      expect(result.summary.claims_submitted).toBe(4);
      expect(result.summary.eligibility_pending).toBe(2);
      expect(result.summary.claims_to_submit).toBe(3);
      expect(result.summary.denied_resubmission).toBe(3); // 1 denied + 2 rejected
      expect(result.summary.paid_closed).toBe(6); // 5 paid + 1 cancelled
      // pending auth + denied + submitted + approved + partial + rejected + eligibility + to-submit
      expect(result.summary.workload).toBe(3 + 1 + 4 + 1 + 0 + 2 + 2 + 3);
      expect(result.timeline).toHaveLength(2);
      expect(result.timeline[0].type).toBe('CLAIM'); // newer submitted_at sorts first
    });
  });

  describe('getWorkItems', () => {
    it('merges and sorts claims and authorizations by recency', async () => {
      claimsWorkspaceRepository.findManyPreAuthorizations.mockResolvedValue([preAuth()]);
      claimsWorkspaceRepository.findManyClaims.mockResolvedValue([claim()]);

      const result = await claimsWorkspaceService.getWorkItems({}, 1, 20, user);

      expect(result.items).toHaveLength(2);
      expect(result.items[0].type).toBe('CLAIM');
      expect(result.items[1].type).toBe('PRE_AUTH');
      expect(result.items[1].remaining_amount).toBe('375000.00');
      expect(result.pagination.total).toBe(2);
    });

    it('restricts to claims only when kind=CLAIM', async () => {
      claimsWorkspaceRepository.findManyClaims.mockResolvedValue([claim()]);

      const result = await claimsWorkspaceService.getWorkItems({ kind: 'CLAIM' }, 1, 20, user);

      expect(claimsWorkspaceRepository.findManyPreAuthorizations).not.toHaveBeenCalled();
      expect(result.items.every((item) => item.type === 'CLAIM')).toBe(true);
    });
  });

  describe('getLookups', () => {
    it('returns coverage plans and billable invoices', async () => {
      claimsWorkspaceRepository.findManyCoveragePlans.mockResolvedValue([
        { id: 'plan-1', human_friendly_id: 'COV0001', name: 'Corporate Plan', provider_name: 'Acme', coverage_percentage: 80, tenant_id: 'tenant-1' }]);
      claimsWorkspaceRepository.findManyInsuranceCompanies.mockResolvedValue([
        { id: 'co-1', human_friendly_id: 'INS0001', name: 'Acme', code: 'ACME', is_active: true }]);
      claimsWorkspaceRepository.findManyInvoices.mockResolvedValue([
        claim().invoice]);

      const result = await claimsWorkspaceService.getLookups({}, user);

      expect(result.coverage_plans).toHaveLength(1);
      expect(result.insurance_companies).toHaveLength(1);
      expect(result.coverage_plans[0].coverage_percentage).toBe(80);
      expect(result.invoices).toHaveLength(1);
      expect(result.invoices[0].total_amount).toBe('125000.00');
    });
  });

  describe('getAuthorizationContext', () => {
    it('rejects when no context identifier is provided', async () => {
      await expect(
        claimsWorkspaceService.getAuthorizationContext({}, 1, 20, user)
      ).rejects.toMatchObject({ statusCode: 400 });
    });
  });
});
