const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { toDecimalNumber, toMoneyString } = require('@lib/billing/financials');
const billingService = require('@services/billing/billing.service');
const fiscalPeriodService = require('@services/accounts-workspace/fiscal-period.service');
const repo = require('@repositories/accounts-workspace/accounts-workspace.repository');

const clean = (value) => String(value ?? '').trim();

const pageMeta = (page, limit, total) => ({
  page,
  limit,
  total,
  total_pages: Math.max(1, Math.ceil(total / Math.max(limit, 1))),
});

const assertEnabled = () => {
  if (!isFeatureEnabled('accounts_workspace_v1')) {
    throw new HttpError('errors.accounts.workspace_not_enabled', 404);
  }
};

const resolveScope = async (filters = {}, user = {}) => {
  const tenantId = clean(filters.tenant_id) || clean(user.tenant_id);
  if (!tenantId) throw new HttpError('errors.auth.insufficient_permissions', 403);

  let facilityId = clean(user.facility_id) || null;
  if (filters.facility_id) {
    const facility = await resolveModelRecordByIdentifier({
      model: 'facility',
      identifier: filters.facility_id,
      where: { deleted_at: null, tenant_id: tenantId },
      select: { id: true },
    });
    if (!facility) throw new HttpError('errors.facility.not_found', 404);
    facilityId = facility.id;
  }

  let patientId = null;
  if (filters.patient_id) {
    const patient = await resolveModelRecordByIdentifier({
      model: 'patient',
      identifier: filters.patient_id,
      where: {
        deleted_at: null,
        tenant_id: tenantId,
        ...(facilityId ? { facility_id: facilityId } : {}),
      },
      select: { id: true },
    });
    if (!patient) throw new HttpError('errors.patient.not_found', 404);
    patientId = patient.id;
  }

  return { tenant_id: tenantId, facility_id: facilityId, patient_id: patientId };
};

const displayId = (record = {}) =>
  resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id);

const patientName = (patient = {}) =>
  `${clean(patient.first_name)} ${clean(patient.last_name)}`.trim() || null;

const clearanceFor = (invoiced, paid, balance) => {
  if (balance <= 0) return 'CLEARED';
  if (paid > 0 && balance > 0) return 'PARTIAL';
  return 'OUTSTANDING';
};

const buildPatientLedgers = async (filters = {}, page = 1, limit = 20, user = {}) => {
  assertEnabled();
  const scope = await resolveScope(filters, user);
  const baseWhere = {
    tenant_id: scope.tenant_id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    ...(scope.patient_id ? { patient_id: scope.patient_id } : {}),
  };

  const [invoices, payments, refunds] = await Promise.all([
    repo.findInvoiceRowsForLedgers(baseWhere),
    repo.findPaymentRowsForLedgers(baseWhere),
    repo.findRefundRowsForLedgers({
      payment: {
        deleted_at: null,
        tenant_id: scope.tenant_id,
        ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
        ...(scope.patient_id ? { patient_id: scope.patient_id } : {}),
      },
    }),
  ]);

  const byPatient = new Map();

  const ensureRow = (patientId, patient) => {
    if (!byPatient.has(patientId)) {
      byPatient.set(patientId, {
        patient_id: patientId,
        patient,
        invoiced: 0,
        paid: 0,
        refunded: 0,
        updated_at: null,
        currency: null,
      });
    }
    return byPatient.get(patientId);
  };

  for (const invoice of invoices) {
    const patientId = clean(invoice.patient_id);
    if (!patientId) continue;
    const row = ensureRow(patientId, invoice.patient);
    row.invoiced += toDecimalNumber(invoice.total_amount);
    row.currency = row.currency || invoice.currency || null;
    const stamp = invoice.updated_at || invoice.created_at;
    if (stamp && (!row.updated_at || stamp > row.updated_at)) {
      row.updated_at = stamp;
    }
  }

  for (const payment of payments) {
    const patientId = clean(payment.patient_id);
    if (!patientId) continue;
    const row = ensureRow(patientId, null);
    if (clean(payment.status).toUpperCase() === 'COMPLETED') {
      row.paid += toDecimalNumber(payment.amount);
    }
    const stamp = payment.updated_at || payment.created_at;
    if (stamp && (!row.updated_at || stamp > row.updated_at)) {
      row.updated_at = stamp;
    }
  }

  for (const refund of refunds) {
    const patientId = clean(refund.payment?.patient_id);
    if (!patientId) continue;
    const row = ensureRow(patientId, null);
    row.refunded += toDecimalNumber(refund.amount);
    const stamp = refund.updated_at || refund.created_at;
    if (stamp && (!row.updated_at || stamp > row.updated_at)) {
      row.updated_at = stamp;
    }
  }

  const search = clean(filters.search).toLowerCase();
  const clearanceFilter = clean(filters.clearance).toUpperCase();

  let items = Array.from(byPatient.values())
    .map((row) => {
      const netPaid = row.paid - row.refunded;
      const balance = row.invoiced - netPaid;
      const clearance = clearanceFor(row.invoiced, netPaid, balance);
      const patient = row.patient || {};
      return {
        patient: {
          id: row.patient_id,
          display_id: displayId(patient),
          display_name: patientName(patient),
        },
        invoiced: toMoneyString(row.invoiced),
        paid: toMoneyString(netPaid),
        balance: toMoneyString(balance),
        clearance,
        currency: row.currency,
        updated_at: row.updated_at,
      };
    })
    .filter((row) => {
      if (clearanceFilter && row.clearance !== clearanceFilter) return false;
      if (!search) return true;
      const hay = `${row.patient.display_name || ''} ${row.patient.display_id || ''} ${row.patient.id}`
        .toLowerCase();
      return hay.includes(search);
    })
    .sort((a, b) => {
      const balanceDiff =
        toDecimalNumber(b.balance) - toDecimalNumber(a.balance);
      if (balanceDiff !== 0) return balanceDiff;
      return String(a.patient.display_name || '').localeCompare(
        String(b.patient.display_name || '')
      );
    });

  const withBalanceCount = items.filter(
    (row) => toDecimalNumber(row.balance) > 0
  ).length;

  const total = items.length;
  const offset = (page - 1) * limit;
  items = items.slice(offset, offset + limit);

  return {
    items,
    pagination: pageMeta(page, limit, total),
    with_balance_count: withBalanceCount,
  };
};

const getWorkspace = async (filters = {}, user = {}) => {
  assertEnabled();
  const ledgers = await buildPatientLedgers(filters, 1, 1, user);
  let invoicesCount = 0;
  try {
    const accountsInvoiceService = require('@services/accounts-invoice/accounts-invoice.service');
    invoicesCount = await accountsInvoiceService.countActiveInvoices({
      tenant_id: filters.tenant_id || user.tenant_id,
      facility_id: filters.facility_id || user.facility_id,
    });
  } catch (_) {
    invoicesCount = 0;
  }
  const fiscalPeriodsCount = await fiscalPeriodService.countActiveFiscalPeriods(
    filters,
    user
  );

  return {
    summary: {
      open_work: 0,
      open_work_count: 0,
      to_post: 0,
      drafts_count: 0,
      need_approval: 0,
      pending_approvals_count: 0,
      gl_activity: 0,
      gl_with_activity_count: 0,
      ledgers_with_balance: ledgers.with_balance_count || 0,
      patient_ledgers_count: ledgers.with_balance_count || 0,
      chart_active: 0,
      chart_active_count: 0,
      invoices: invoicesCount,
      invoices_count: invoicesCount,
      fiscal_years_and_periods: fiscalPeriodsCount,
      fiscal_periods_active_count: fiscalPeriodsCount,
    },
    generated_at: new Date().toISOString(),
  };
};

/**
 * Section-scoped work items.
 *
 * Sections that own a dedicated resource delegate to that service so the
 * worklist and the resource tab always agree on rows, filters, and totals.
 */
const WORK_ITEM_SECTION_HANDLERS = {
  [fiscalPeriodService.SECTION_SLUG]: (filters, page, limit, user) =>
    fiscalPeriodService.listFiscalPeriods(filters, page, limit, user),
};

const listWorkItems = async (filters = {}, page = 1, limit = 20, user = {}) => {
  assertEnabled();
  const section = clean(filters.section).toLowerCase();
  const handler = WORK_ITEM_SECTION_HANDLERS[section];
  if (handler) {
    const { section: _section, ...sectionFilters } = filters;
    const result = await handler(sectionFilters, page, limit, user);
    return { items: result.items, pagination: result.pagination };
  }

  const items = [];
  return {
    items,
    pagination: pageMeta(page, limit, items.length),
  };
};

const listGlAccounts = async (filters = {}, page = 1, limit = 20, _user = {}) => {
  assertEnabled();
  void filters;
  const items = [];
  return {
    items,
    pagination: pageMeta(page, limit, items.length),
  };
};

const getAccountLedger = async (
  accountIdentifier,
  _filters = {},
  page = 1,
  limit = 20,
  _user = {}
) => {
  assertEnabled();
  const id = clean(accountIdentifier);
  return {
    account: {
      id,
      display_id: id,
      code: id,
      name: id,
      type: '',
      period: '',
      debit: 0,
      credit: 0,
      balance: 0,
      currency: 'UGX',
      has_activity: false,
      updated_at: null,
    },
    summary: {
      debit: 0,
      credit: 0,
      balance: 0,
    },
    entries: [],
    pagination: pageMeta(page, limit, 0),
  };
};

const listPatientLedgers = async (filters = {}, page = 1, limit = 20, user = {}) => {
  assertEnabled();
  return buildPatientLedgers(filters, page, limit, user);
};

const getPatientLedger = async (
  patientIdentifier,
  filters = {},
  page = 1,
  limit = 20,
  user = {}
) => {
  assertEnabled();
  // Reuse billing ledger assembly; Accounts auth is enforced at the route.
  return billingService.getPatientLedger(
    patientIdentifier,
    filters,
    page,
    limit,
    user
  );
};

module.exports = {
  getWorkspace,
  listWorkItems,
  listGlAccounts,
  getAccountLedger,
  listPatientLedgers,
  getPatientLedger,
};
