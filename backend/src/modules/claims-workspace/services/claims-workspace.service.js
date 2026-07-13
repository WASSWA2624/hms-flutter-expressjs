/**
 * Claims workspace service
 *
 * @module modules/claims-workspace/services
 * @description Orchestration layer for the insurance and claims workspace. It
 * aggregates pre-authorizations and insurance claims into a single audit-ready
 * workspace (summary counts, prioritised work queues, recent activity timeline),
 * exposes claim-preparation lookups, and surfaces authorization context for IPD
 * admission/encounter gates and OPD insured visits.
 *
 * Module boundary: this service is read-only. Coverage, pre-auth, and claim
 * mutations stay owned by the coverage-plan, pre-authorization, and
 * insurance-claim modules. Invoice balances stay owned by Billing.
 */

const claimsWorkspaceRepository = require('@repositories/claims-workspace/claims-workspace.repository');
const { HttpError } = require('@lib/errors');
const { resolvePublicIdentifier, resolveIdentifierForFilter } = require('@lib/billing/identifiers');
const { toMoneyString, toDecimalNumber } = require('@lib/billing/financials');

const AUTHORIZATION_STATUSES = [
  'PENDING',
  'APPROVED',
  'PARTIAL',
  'DENIED',
  'EXPIRED',
  'CANCELLED',
];
const CLAIM_STATUSES = [
  'SUBMITTED',
  'APPROVED',
  'PARTIAL',
  'REJECTED',
  'PAID',
  'CANCELLED',
];

const COVERAGE_SELECT = { id: true, human_friendly_id: true, name: true, provider_name: true, coverage_percentage: true, tenant_id: true };
const CLAIM_INCLUDE = {
  coverage_plan: { select: COVERAGE_SELECT },
  invoice: {
    select: {
      id: true,
      human_friendly_id: true,
      tenant_id: true,
      facility_id: true,
      patient_id: true,
      currency: true,
      total_amount: true,
      status: true,
      billing_status: true,
      patient: { select: { id: true, human_friendly_id: true, first_name: true, last_name: true } },
    },
  },
};
const PRE_AUTH_INCLUDE = {
  coverage_plan: { select: COVERAGE_SELECT },
  patient: { select: { id: true, human_friendly_id: true, first_name: true, last_name: true } },
  encounter: { select: { id: true, human_friendly_id: true } },
  admission: { select: { id: true, human_friendly_id: true } },
};
const INVOICE_INCLUDE = {
  patient: { select: { id: true, human_friendly_id: true, first_name: true, last_name: true } },
};

const clean = (value) => String(value ?? '').trim();
const toDate = (value) => {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};
const displayId = (record = {}) => resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id);
const patientName = (patient = {}) => `${clean(patient.first_name)} ${clean(patient.last_name)}`.trim() || null;

const pageMeta = (page, limit, total) => {
  const totalPages = limit > 0 ? Math.ceil(total / limit) : 0;
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
};

const normalizeStatus = (value, allowed) => {
  const key = clean(value).toUpperCase();
  return allowed.includes(key) ? key : null;
};

const normalizeKind = (value) => {
  const key = clean(value).toUpperCase();
  if (key === 'AUTHORIZATION' || key === 'PRE_AUTH' || key === 'PREAUTH') return 'AUTHORIZATION';
  if (key === 'CLAIM') return 'CLAIM';
  return null;
};

const resolveScope = async (filters = {}, user = {}) => {
  const tenantId = clean(filters.tenant_id) || clean(user.tenant_id);
  if (!tenantId) throw new HttpError('errors.auth.insufficient_permissions', 403);

  const facilityId = clean(filters.facility_id) || clean(user.facility_id) || null;

  let patientId;
  if (filters.patient_id !== undefined) {
    patientId = await resolveIdentifierForFilter({ value: filters.patient_id, model: 'patient' });
  }
  let admissionId;
  if (filters.admission_id !== undefined) {
    admissionId = await resolveIdentifierForFilter({ value: filters.admission_id, model: 'admission' });
  }
  let encounterId;
  if (filters.encounter_id !== undefined) {
    encounterId = await resolveIdentifierForFilter({ value: filters.encounter_id, model: 'encounter' });
  }

  return { tenant_id: tenantId, facility_id: facilityId, patient_id: patientId, admission_id: admissionId, encounter_id: encounterId };
};

const claimWhere = (scope) => ({
  invoice: {
    deleted_at: null,
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    ...(scope.patient_id ? { patient_id: scope.patient_id } : {}),
  },
});

const preAuthWhere = (scope) => ({
  coverage_plan: { deleted_at: null, tenant_id: scope.tenant_id },
  ...(scope.patient_id ? { patient_id: scope.patient_id } : {}),
  ...(scope.admission_id ? { admission_id: scope.admission_id } : {}),
  ...(scope.encounter_id ? { encounter_id: scope.encounter_id } : {}),
});

const mapPreAuthorization = (record = {}) => {
  const approved = record.approved_amount === null || record.approved_amount === undefined ? null : toDecimalNumber(record.approved_amount);
  const consumed = record.consumed_amount === null || record.consumed_amount === undefined ? null : toDecimalNumber(record.consumed_amount);
  const remaining = approved === null ? null : approved - (consumed ?? 0);
  return {
    type: 'PRE_AUTH',
    id: record.id,
    display_id: displayId(record),
    coverage_plan_id: record.coverage_plan_id,
    coverage_plan_display_id: displayId(record.coverage_plan || {}),
    coverage_plan_name: record.coverage_plan?.name || null,
    provider_name: record.coverage_plan?.provider_name || null,
    patient_id: record.patient_id,
    patient_display_id: displayId(record.patient || {}),
    patient_display_name: patientName(record.patient || {}),
    encounter_id: record.encounter_id,
    encounter_display_id: displayId(record.encounter || {}),
    admission_id: record.admission_id,
    admission_display_id: displayId(record.admission || {}),
    status: record.status,
    reason: record.reason || null,
    approved_amount: approved === null ? null : toMoneyString(approved),
    consumed_amount: consumed === null ? null : toMoneyString(consumed),
    remaining_amount: remaining === null ? null : toMoneyString(remaining),
    notes: record.notes || null,
    requested_at: record.requested_at || null,
    approved_at: record.approved_at || null,
    timeline_at: record.approved_at || record.requested_at || record.created_at || null,
  };
};

const mapClaim = (record = {}) => ({
  type: 'CLAIM',
  id: record.id,
  display_id: displayId(record),
  coverage_plan_id: record.coverage_plan_id,
  coverage_plan_display_id: displayId(record.coverage_plan || {}),
  coverage_plan_name: record.coverage_plan?.name || null,
  provider_name: record.coverage_plan?.provider_name || null,
  invoice_id: record.invoice_id,
  invoice_display_id: displayId(record.invoice || {}),
  patient_display_id: displayId(record.invoice?.patient || {}),
  patient_display_name: patientName(record.invoice?.patient || {}),
  status: record.status,
  settlement_amount: record.settlement_amount === null || record.settlement_amount === undefined ? null : toMoneyString(record.settlement_amount),
  invoice_total: record.invoice?.total_amount === undefined ? null : toMoneyString(record.invoice?.total_amount),
  currency: record.invoice?.currency || null,
  payer_reference: record.payer_reference || null,
  notes: record.notes || null,
  submitted_at: record.submitted_at || null,
  resubmitted_at: record.resubmitted_at || null,
  timeline_at: record.submitted_at || record.created_at || null,
});

const mapInvoiceOption = (invoice = {}) => ({
  id: invoice.id,
  display_id: displayId(invoice),
  patient_display_id: displayId(invoice.patient || {}),
  patient_display_name: patientName(invoice.patient || {}),
  status: invoice.status || null,
  billing_status: invoice.billing_status || null,
  total_amount: invoice.total_amount === undefined ? null : toMoneyString(invoice.total_amount),
  currency: invoice.currency || null,
  issued_at: invoice.issued_at || invoice.created_at || null,
});

const mapCoverageOption = (plan = {}) => ({
  id: plan.id,
  display_id: displayId(plan),
  name: plan.name || null,
  code: plan.code || null,
  provider_name: plan.provider_name || plan.insurance_company?.name || null,
  coverage_percentage: plan.coverage_percentage ?? null,
  default_copay_type: plan.default_copay_type || 'NONE',
  default_copay_value: plan.default_copay_value ?? null,
  status: plan.status || 'ACTIVE',
  insurance_company_id: plan.insurance_company_id || plan.insurance_company?.id || null,
  insurance_company_name: plan.insurance_company?.name || plan.provider_name || null,
  insurance_company_code: plan.insurance_company?.code || null,
  insurance_company_display_id: resolvePublicIdentifier(
    plan.insurance_company?.human_friendly_id,
    plan.insurance_company_id
  ),
  tenant_display_id: resolvePublicIdentifier(plan.tenant_id),
});

const mapInsuranceCompanyOption = (company = {}) => ({
  id: company.id,
  display_id: displayId(company),
  name: company.name || null,
  code: company.code || null,
  is_active: company.is_active !== false,
  scheme_count: company._count?.schemes ?? null,
});

const matchesSearch = (item, token) => {
  const needle = clean(token).toLowerCase();
  if (!needle) return true;
  return [
    item.display_id,
    item.status,
    item.coverage_plan_display_id,
    item.coverage_plan_name,
    item.provider_name,
    item.invoice_display_id,
    item.patient_display_id,
    item.patient_display_name,
  ]
    .map((value) => clean(value).toLowerCase())
    .some((value) => value.includes(needle));
};

const sortByTimelineDesc = (list) =>
  list.sort((left, right) => (toDate(right.timeline_at)?.getTime() || 0) - (toDate(left.timeline_at)?.getTime() || 0));

/**
 * Aggregated workspace summary, prioritised queues, and recent activity.
 */
const getWorkspace = async (filters = {}, user = {}) => {
  const scope = await resolveScope(filters, user);
  const claimBase = claimWhere(scope);
  const preAuthBase = preAuthWhere(scope);

  const claimStatusCount = (status) => claimsWorkspaceRepository.countClaims({ ...claimBase, status });
  const preAuthStatusCount = (status) => claimsWorkspaceRepository.countPreAuthorizations({ ...preAuthBase, status });

  const [
    authPending,
    authApproved,
    authDenied,
    authExpired,
    claimsSubmitted,
    claimsApproved,
    claimsPartial,
    claimsRejected,
    claimsPaid,
    claimsCancelled,
    eligibilityPending,
    claimsToSubmit,
    recentPreAuths,
    recentClaims,
  ] = await Promise.all([
    preAuthStatusCount('PENDING'),
    preAuthStatusCount('APPROVED'),
    preAuthStatusCount('DENIED'),
    preAuthStatusCount('EXPIRED'),
    claimStatusCount('SUBMITTED'),
    claimStatusCount('APPROVED'),
    claimStatusCount('PARTIAL'),
    claimStatusCount('REJECTED'),
    claimStatusCount('PAID'),
    claimStatusCount('CANCELLED'),
    claimsWorkspaceRepository.countEnrollments({
      tenant_id: scope.tenant_id,
      status: 'PENDING',
      ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      ...(scope.patient_id ? { patient_id: scope.patient_id } : {}),
    }),
    claimsWorkspaceRepository.countInvoicesReadyToClaim({
      tenant_id: scope.tenant_id,
      ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
      ...(scope.patient_id ? { patient_id: scope.patient_id } : {}),
    }),
    claimsWorkspaceRepository.findManyPreAuthorizations(preAuthBase, 0, 25, { requested_at: 'desc' }, PRE_AUTH_INCLUDE),
    claimsWorkspaceRepository.findManyClaims(claimBase, 0, 25, { submitted_at: 'desc' }, CLAIM_INCLUDE),
  ]);

  const deniedRejected = authDenied + claimsRejected;
  const paidClosed = claimsPaid + claimsCancelled;
  const readyToSettle = claimsApproved + claimsPartial;
  const workload =
    authPending +
    authDenied +
    claimsSubmitted +
    claimsApproved +
    claimsPartial +
    claimsRejected +
    eligibilityPending +
    claimsToSubmit;

  const summary = {
    authorization_pending: authPending,
    authorization_approved: authApproved,
    authorization_denied: authDenied,
    authorization_expired: authExpired,
    claims_submitted: claimsSubmitted,
    claims_approved: claimsApproved,
    claims_partial: claimsPartial,
    claims_rejected: claimsRejected,
    claims_paid: claimsPaid,
    claims_cancelled: claimsCancelled,
    eligibility_pending: eligibilityPending,
    claims_to_submit: claimsToSubmit,
    denied_resubmission: deniedRejected,
    paid_closed: paidClosed,
    awaiting_response: claimsSubmitted,
    unsettled: readyToSettle,
    ready_to_settle: readyToSettle,
    settled: claimsPaid,
    workload,
  };

  const timeline = sortByTimelineDesc([
    ...recentPreAuths.map(mapPreAuthorization),
    ...recentClaims.map(mapClaim),
  ]).slice(0, 25);

  return {
    summary,
    queues: [
      { queue: 'ELIGIBILITY_PENDING', label: 'Eligibility pending', count: eligibilityPending },
      { queue: 'AUTH_PENDING', label: 'Authorization pending', count: authPending },
      { queue: 'CLAIMS_TO_SUBMIT', label: 'Claims to submit', count: claimsToSubmit },
      { queue: 'AWAITING_RESPONSE', label: 'Awaiting insurer response', count: claimsSubmitted },
      { queue: 'PARTIAL', label: 'Partial', count: claimsPartial },
      { queue: 'DENIED_REJECTED', label: 'Denied / resubmit', count: deniedRejected },
      { queue: 'READY_TO_SETTLE', label: 'Ready to settle', count: readyToSettle },
      { queue: 'SETTLED', label: 'Settled', count: claimsPaid },
    ],
    timeline,
    generated_at: new Date().toISOString(),
  };
};

/**
 * Merged, paginated claim + pre-authorization work items for the worklist.
 */
const getWorkItems = async (filters = {}, page = 1, limit = 20, user = {}) => {
  const scope = await resolveScope(filters, user);
  const kind = normalizeKind(filters.kind);
  const status = clean(filters.status).toUpperCase() || null;
  const cap = Math.max(limit * 3, 60);

  const includeAuthorizations = kind === null || kind === 'AUTHORIZATION';
  const includeClaims = kind === null || kind === 'CLAIM';

  const authStatus = includeAuthorizations ? normalizeStatus(status, AUTHORIZATION_STATUSES) : null;
  const claimStatus = includeClaims ? normalizeStatus(status, CLAIM_STATUSES) : null;

  const [preAuths, claims] = await Promise.all([
    includeAuthorizations
      ? claimsWorkspaceRepository.findManyPreAuthorizations(
          { ...preAuthWhere(scope), ...(authStatus ? { status: authStatus } : {}) },
          0,
          cap,
          { requested_at: 'desc' },
          PRE_AUTH_INCLUDE
        )
      : Promise.resolve([]),
    includeClaims
      ? claimsWorkspaceRepository.findManyClaims(
          { ...claimWhere(scope), ...(claimStatus ? { status: claimStatus } : {}) },
          0,
          cap,
          { submitted_at: 'desc' },
          CLAIM_INCLUDE
        )
      : Promise.resolve([]),
  ]);

  const merged = sortByTimelineDesc(
    [...preAuths.map(mapPreAuthorization), ...claims.map(mapClaim)].filter((item) => matchesSearch(item, filters.search))
  );

  const total = merged.length;
  const skip = (page - 1) * limit;
  const items = merged.slice(skip, skip + limit);

  return { items, pagination: pageMeta(page, limit, total) };
};

/**
 * Reference data for claim preparation: coverage plans + billable invoices.
 */
const getLookups = async (filters = {}, user = {}) => {
  const scope = await resolveScope(filters, user);
  const companyInclude = {
    insurance_company: {
      select: { id: true, human_friendly_id: true, name: true, code: true },
    },
  };
  const [coveragePlans, companies, invoices] = await Promise.all([
    claimsWorkspaceRepository.findManyCoveragePlans(
      { tenant_id: scope.tenant_id, status: 'ACTIVE' },
      0,
      100,
      { name: 'asc' },
      companyInclude
    ),
    claimsWorkspaceRepository.findManyInsuranceCompanies(
      { tenant_id: scope.tenant_id, is_active: true },
      0,
      50,
      { name: 'asc' },
      { _count: { select: { schemes: true } } }
    ),
    claimsWorkspaceRepository.findManyInvoices(
      {
        tenant_id: scope.tenant_id,
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
        billing_status: { not: 'CANCELLED' },
      },
      0,
      50,
      { issued_at: 'desc' },
      INVOICE_INCLUDE
    ),
  ]);

  return {
    insurance_companies: companies.map(mapInsuranceCompanyOption),
    coverage_plans: coveragePlans.map(mapCoverageOption),
    schemes: coveragePlans.map(mapCoverageOption),
    invoices: invoices.map(mapInvoiceOption),
  };
};

/**
 * Authorization context for an admission, encounter, or patient. Powers the IPD
 * authorization gate panel and OPD insured-visit coverage checks.
 */
const getAuthorizationContext = async (filters = {}, page = 1, limit = 20, user = {}) => {
  const scope = await resolveScope(filters, user);
  if (!scope.patient_id && !scope.admission_id && !scope.encounter_id) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'context' }]);
  }
  if (scope.patient_id === null || scope.admission_id === null || scope.encounter_id === null) {
    return { items: [], pagination: pageMeta(page, limit, 0) };
  }

  const where = preAuthWhere(scope);
  const skip = (page - 1) * limit;
  const [records, total] = await Promise.all([
    claimsWorkspaceRepository.findManyPreAuthorizations(where, skip, limit, { requested_at: 'desc' }, PRE_AUTH_INCLUDE),
    claimsWorkspaceRepository.countPreAuthorizations(where),
  ]);

  return { items: records.map(mapPreAuthorization), pagination: pageMeta(page, limit, total) };
};

module.exports = {
  getWorkspace,
  getWorkItems,
  getLookups,
  getAuthorizationContext,
};
