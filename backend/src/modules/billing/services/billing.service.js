const billingRepository = require('@repositories/billing/billing.repository');
const { createAuditLog } = require('@lib/audit');
const { sendEmail } = require('@lib/notifications/sendEmail');
const { HttpError } = require('@lib/errors');
const { isFeatureEnabled } = require('@config/feature-flags');
const { PERMISSIONS, ROLE_PERMISSIONS } = require('@config/permissions');
const { normalizeRoleName } = require('@config/roles');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const {
  toDecimalNumber,
  toMoneyString,
  recalculateInvoiceStateTx,
  computeInvoiceFinancials,
} = require('@lib/billing/financials');
const { generateInvoicePdfBuffer } = require('@lib/billing/pdf');

const QUEUE_TYPES = {
  NEEDS_ISSUE: 'NEEDS_ISSUE',
  PENDING_PAYMENT: 'PENDING_PAYMENT',
  CLAIMS_PENDING: 'CLAIMS_PENDING',
  APPROVAL_REQUIRED: 'APPROVAL_REQUIRED',
  OVERDUE: 'OVERDUE',
};

const ADJUSTMENT_ABS_THRESHOLD = 50;
const ADJUSTMENT_PERCENT_THRESHOLD = 0.2;
const APPLIED_ADJUSTMENT_STATUSES = new Set(['ISSUED', 'PAID', 'PARTIAL']);

const INVOICE_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true, name: true } },
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  patient: {
    select: {
      id: true,
      human_friendly_id: true,
      first_name: true,
      last_name: true,
      contacts: {
        where: { deleted_at: null },
        select: { contact_type: true, value: true },
      },
    },
  },
  items: { where: { deleted_at: null }, orderBy: { created_at: 'asc' } },
  payments: { where: { deleted_at: null }, include: { refunds: { where: { deleted_at: null } } } },
  billing_adjustments: { where: { deleted_at: null } },
};

const PAYMENT_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true, name: true } },
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  patient: { select: { id: true, human_friendly_id: true, first_name: true, last_name: true } },
  invoice: { select: { id: true, human_friendly_id: true, total_amount: true, currency: true } },
  refunds: { where: { deleted_at: null } },
};

const REFUND_INCLUDE = {
  payment: {
    include: {
      patient: { select: { id: true, human_friendly_id: true, first_name: true, last_name: true } },
      invoice: { select: { id: true, human_friendly_id: true, currency: true } },
    },
  },
};

const CLAIM_INCLUDE = {
  coverage_plan: { select: { id: true, human_friendly_id: true, name: true, provider_name: true } },
  invoice: {
    select: {
      id: true,
      human_friendly_id: true,
      patient: { select: { id: true, human_friendly_id: true, first_name: true, last_name: true } },
    },
  },
};

const PRE_AUTH_INCLUDE = {
  coverage_plan: { select: { id: true, human_friendly_id: true, name: true, provider_name: true } },
};

const ADJUSTMENT_INCLUDE = {
  invoice: {
    select: {
      id: true,
      human_friendly_id: true,
      tenant_id: true,
      patient_id: true,
      currency: true,
      patient: { select: { id: true, human_friendly_id: true, first_name: true, last_name: true } },
    },
  },
};

const APPROVAL_INCLUDE = {
  requested_by_user: { select: { id: true, human_friendly_id: true, email: true } },
  approved_by_user: { select: { id: true, human_friendly_id: true, email: true } },
};

const clean = (value) => String(value || '').trim();
const toDate = (value) => {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};
const displayId = (record = {}) => resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id);
const patientName = (patient = {}) => `${clean(patient.first_name)} ${clean(patient.last_name)}`.trim() || null;
const isEnabled = () => isFeatureEnabled('billing_workspace_v1');
const assertEnabled = () => {
  if (isEnabled()) return;
  throw new HttpError('errors.billing.workspace_not_enabled', 404);
};
const normalizeQueue = (value) => {
  const key = clean(value).toUpperCase();
  return Object.values(QUEUE_TYPES).includes(key) ? key : null;
};

const pageMeta = (page, limit, total) => {
  const totalPages = Math.ceil(total / limit);
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
};

const getPermissionSet = (user = {}) => {
  const direct = Array.isArray(user.permissions) ? user.permissions : [];
  const roleBased = (Array.isArray(user.roles) ? user.roles : [user.role])
    .map((role) => normalizeRoleName(role) || clean(role).toUpperCase())
    .filter(Boolean)
    .flatMap((role) => ROLE_PERMISSIONS[role] || []);
  return new Set([...direct, ...roleBased]);
};

const hasPermission = (user, permission) => getPermissionSet(user).has(permission);

const auditCreate = (user, ip, entity, entityId, after) =>
  createAuditLog({
    tenant_id: user?.tenant_id || null,
    user_id: user?.id || null,
    action: 'CREATE',
    entity,
    entity_id: entityId,
    diff: { after },
    ip_address: ip,
  }).catch(() => {});

const auditUpdate = (user, ip, entity, entityId, metadata = {}) =>
  createAuditLog({
    tenant_id: user?.tenant_id || null,
    user_id: user?.id || null,
    action: 'UPDATE',
    entity,
    entity_id: entityId,
    diff: { metadata },
    ip_address: ip,
  }).catch(() => {});

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
      where: { deleted_at: null, tenant_id: tenantId, ...(facilityId ? { facility_id: facilityId } : {}) },
      select: { id: true },
    });
    if (!patient) throw new HttpError('errors.patient.not_found', 404);
    patientId = patient.id;
  }

  return { tenant_id: tenantId, facility_id: facilityId, patient_id: patientId };
};

const resolveScopedByIdentifier = async ({
  model,
  identifier,
  where = {},
  include,
  select = { id: true, human_friendly_id: true },
  errorKey = 'errors.resource.not_found',
}) => {
  const record = await resolveModelRecordByIdentifier({
    model,
    identifier,
    where: { deleted_at: null, ...where },
    include,
    select,
  });
  if (!record) throw new HttpError(errorKey, 404);
  return record;
};

const mapInvoice = (invoice = {}, includeFinancials = false) => {
  const mapped = {
    ...invoice,
    display_id: displayId(invoice),
    tenant_display_id: displayId(invoice.tenant || {}),
    facility_display_id: displayId(invoice.facility || {}),
    patient_display_id: displayId(invoice.patient || {}),
    patient_display_name: patientName(invoice.patient || {}),
    timeline_at: invoice.issued_at || invoice.created_at || null,
  };
  if (includeFinancials) mapped.financials = computeInvoiceFinancials(invoice);
  return mapped;
};

const mapPayment = (payment = {}) => ({
  ...payment,
  display_id: displayId(payment),
  tenant_display_id: displayId(payment.tenant || {}),
  facility_display_id: displayId(payment.facility || {}),
  patient_display_id: displayId(payment.patient || {}),
  invoice_display_id: displayId(payment.invoice || {}),
  patient_display_name: patientName(payment.patient || {}),
  timeline_at: payment.paid_at || payment.created_at || null,
});

const mapRefund = (refund = {}) => ({
  ...refund,
  display_id: displayId(refund),
  payment_display_id: displayId(refund.payment || {}),
  invoice_display_id: displayId(refund.payment?.invoice || {}),
  patient_display_id: displayId(refund.payment?.patient || {}),
  patient_display_name: patientName(refund.payment?.patient || {}),
  timeline_at: refund.refunded_at || refund.created_at || null,
});

const mapClaim = (claim = {}) => ({
  ...claim,
  display_id: displayId(claim),
  invoice_display_id: displayId(claim.invoice || {}),
  coverage_plan_display_id: displayId(claim.coverage_plan || {}),
  patient_display_id: displayId(claim.invoice?.patient || {}),
  patient_display_name: patientName(claim.invoice?.patient || {}),
  timeline_at: claim.submitted_at || claim.created_at || null,
});

const mapAdjustment = (adjustment = {}) => ({
  ...adjustment,
  display_id: displayId(adjustment),
  invoice_display_id: displayId(adjustment.invoice || {}),
  patient_display_id: displayId(adjustment.invoice?.patient || {}),
  patient_display_name: patientName(adjustment.invoice?.patient || {}),
  timeline_at: adjustment.adjusted_at || adjustment.created_at || null,
});

const mapPreAuthorization = (preAuth = {}) => ({
  ...preAuth,
  display_id: displayId(preAuth),
  coverage_plan_display_id: displayId(preAuth.coverage_plan || {}),
  timeline_at: preAuth.approved_at || preAuth.requested_at || preAuth.created_at || null,
});

const mapApproval = (approval = {}) => ({
  ...approval,
  display_id: displayId(approval),
  requested_by_user_display_id: displayId(approval.requested_by_user || {}),
  approved_by_user_display_id: displayId(approval.approved_by_user || {}),
  target_display_id:
    clean(approval.payload_json?.target_display_id) ||
    clean(approval.payload_json?.invoice_display_id) ||
    clean(approval.payload_json?.payment_display_id) ||
    null,
  timeline_at: approval.decided_at || approval.requested_at || approval.created_at || null,
});

const timelineItem = (type, record) => {
  if (type === 'INVOICE') {
    const item = mapInvoice(record);
    return {
      type,
      action: item.billing_status === 'DRAFT' ? 'DRAFTED' : item.status,
      status: item.status,
      display_id: item.display_id,
      patient_display_id: item.patient_display_id,
      patient_display_name: item.patient_display_name,
      amount: toMoneyString(item.total_amount),
      currency: item.currency,
      timeline_at: item.timeline_at,
    };
  }
  if (type === 'PAYMENT') {
    const item = mapPayment(record);
    return {
      type,
      action: item.status,
      status: item.status,
      display_id: item.display_id,
      invoice_display_id: item.invoice_display_id,
      patient_display_id: item.patient_display_id,
      patient_display_name: item.patient_display_name,
      amount: toMoneyString(item.amount),
      currency: item.invoice?.currency || null,
      timeline_at: item.timeline_at,
    };
  }
  if (type === 'REFUND') {
    const item = mapRefund(record);
    return {
      type,
      action: 'REQUESTED',
      status: 'PENDING',
      display_id: item.display_id,
      invoice_display_id: item.invoice_display_id,
      patient_display_id: item.patient_display_id,
      patient_display_name: item.patient_display_name,
      amount: toMoneyString(item.amount),
      currency: item.payment?.invoice?.currency || null,
      timeline_at: item.timeline_at,
    };
  }
  if (type === 'CLAIM') {
    const item = mapClaim(record);
    return { type, action: item.status, status: item.status, display_id: item.display_id, timeline_at: item.timeline_at };
  }
  if (type === 'ADJUSTMENT') {
    const item = mapAdjustment(record);
    return { type, action: item.status, status: item.status, display_id: item.display_id, timeline_at: item.timeline_at };
  }
  if (type === 'APPROVAL') {
    const item = mapApproval(record);
    return { type, action: item.status, status: item.status, display_id: item.display_id, timeline_at: item.timeline_at };
  }
  if (type === 'PRE_AUTH') {
    const item = mapPreAuthorization(record);
    return { type, action: item.status, status: item.status, display_id: item.display_id, timeline_at: item.timeline_at };
  }
  return null;
};

const timelineGroups = (items = []) => {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  const buckets = { TODAY: [], YESTERDAY: [], EARLIER: [] };
  items.forEach((item) => {
    const at = toDate(item.timeline_at);
    if (!at) return;
    if (at >= today) buckets.TODAY.push(item);
    else if (at >= yesterday) buckets.YESTERDAY.push(item);
    else buckets.EARLIER.push(item);
  });
  return [
    { bucket: 'TODAY', label: 'Today', items: buckets.TODAY },
    { bucket: 'YESTERDAY', label: 'Yesterday', items: buckets.YESTERDAY },
    { bucket: 'EARLIER', label: 'Earlier', items: buckets.EARLIER },
  ].filter((bucket) => bucket.items.length > 0);
};

const commonInvoiceWhere = (scope, search) => {
  const where = { tenant_id: scope.tenant_id };
  if (scope.facility_id) where.facility_id = scope.facility_id;
  if (scope.patient_id) where.patient_id = scope.patient_id;
  const token = clean(search);
  if (token) {
    where.OR = [
      { human_friendly_id: { contains: token.toUpperCase() } },
      { patient: { human_friendly_id: { contains: token.toUpperCase() } } },
      { patient: { first_name: { contains: token } } },
      { patient: { last_name: { contains: token } } },
    ];
  }
  return where;
};

const runQueue = async (queue, scope, page, limit, search) => {
  const skip = (page - 1) * limit;
  const invoiceWhere = commonInvoiceWhere(scope, search);
  if (queue === QUEUE_TYPES.NEEDS_ISSUE) {
    const where = { ...invoiceWhere, billing_status: 'DRAFT' };
    const [items, total] = await Promise.all([
      billingRepository.findManyInvoices(where, skip, limit, { issued_at: 'desc' }, INVOICE_INCLUDE),
      billingRepository.countInvoices(where),
    ]);
    return { queue, items: items.map((item) => mapInvoice(item)), total };
  }
  if (queue === QUEUE_TYPES.PENDING_PAYMENT) {
    const where = { ...invoiceWhere, billing_status: { in: ['ISSUED', 'PARTIAL'] }, status: { in: ['SENT', 'OVERDUE'] } };
    const [items, total] = await Promise.all([
      billingRepository.findManyInvoices(where, skip, limit, { issued_at: 'desc' }, INVOICE_INCLUDE),
      billingRepository.countInvoices(where),
    ]);
    return { queue, items: items.map((item) => mapInvoice(item)), total };
  }
  if (queue === QUEUE_TYPES.CLAIMS_PENDING) {
    const where = {
      status: 'SUBMITTED',
      invoice: { deleted_at: null, tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}), ...(scope.patient_id ? { patient_id: scope.patient_id } : {}) },
    };
    const [items, total] = await Promise.all([
      billingRepository.findManyClaims(where, skip, limit, { submitted_at: 'desc' }, CLAIM_INCLUDE),
      billingRepository.countClaims(where),
    ]);
    return { queue, items: items.map((item) => mapClaim(item)), total };
  }
  if (queue === QUEUE_TYPES.APPROVAL_REQUIRED) {
    const where = { tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}), status: 'PENDING' };
    const [items, total] = await Promise.all([
      billingRepository.findManyApprovals(where, skip, limit, { requested_at: 'desc' }, APPROVAL_INCLUDE),
      billingRepository.countApprovals(where),
    ]);
    return { queue, items: items.map((item) => mapApproval(item)), total };
  }
  if (queue === QUEUE_TYPES.OVERDUE) {
    const where = { ...invoiceWhere, status: 'OVERDUE', billing_status: { not: 'CANCELLED' } };
    const [items, total] = await Promise.all([
      billingRepository.findManyInvoices(where, skip, limit, { issued_at: 'asc' }, INVOICE_INCLUDE),
      billingRepository.countInvoices(where),
    ]);
    return { queue, items: items.map((item) => mapInvoice(item)), total };
  }
  throw new HttpError('errors.validation.invalid', 400, [{ field: 'queue' }]);
};

const getWorkspace = async (filters = {}, page = 1, limit = 20, user = {}) => {
  assertEnabled();
  const scope = await resolveScope(filters, user);
  const invoiceWhere = commonInvoiceWhere(scope, filters.search);
  const paymentWhere = { tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}), ...(scope.patient_id ? { patient_id: scope.patient_id } : {}) };
  const approvalWhere = { tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) };
  const claimWhere = { invoice: { deleted_at: null, tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}), ...(scope.patient_id ? { patient_id: scope.patient_id } : {}) } };
  const today = new Date();
  const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate());

  const [needsIssue, pendingPayment, claimsPending, approvalPending, overdue, paymentsToday, refundsToday, invoices, payments, refunds, claims, preAuthorizations, adjustments, approvals] = await Promise.all([
    billingRepository.countInvoices({ ...invoiceWhere, billing_status: 'DRAFT' }),
    billingRepository.countInvoices({ ...invoiceWhere, billing_status: { in: ['ISSUED', 'PARTIAL'] }, status: { in: ['SENT', 'OVERDUE'] } }),
    billingRepository.countClaims({ ...claimWhere, status: 'SUBMITTED' }),
    billingRepository.countApprovals({ ...approvalWhere, status: 'PENDING' }),
    billingRepository.countInvoices({ ...invoiceWhere, status: 'OVERDUE', billing_status: { not: 'CANCELLED' } }),
    billingRepository.aggregatePayments({ ...paymentWhere, status: 'COMPLETED', paid_at: { gte: todayStart } }),
    billingRepository.aggregateRefunds({ payment: { deleted_at: null, tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) }, refunded_at: { gte: todayStart } }),
    billingRepository.findManyInvoices(invoiceWhere, 0, Math.max(limit * 2, 50), { issued_at: 'desc' }, INVOICE_INCLUDE),
    billingRepository.findManyPayments(paymentWhere, 0, Math.max(limit * 2, 50), { paid_at: 'desc' }, PAYMENT_INCLUDE),
    billingRepository.findManyRefunds({ payment: { deleted_at: null, tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}), ...(scope.patient_id ? { patient_id: scope.patient_id } : {}) } }, 0, Math.max(limit * 2, 50), { refunded_at: 'desc' }, REFUND_INCLUDE),
    billingRepository.findManyClaims(claimWhere, 0, Math.max(limit * 2, 50), { submitted_at: 'desc' }, CLAIM_INCLUDE),
    billingRepository.findManyPreAuthorizations({ coverage_plan: { deleted_at: null, tenant_id: scope.tenant_id } }, 0, Math.max(limit, 20), { requested_at: 'desc' }, PRE_AUTH_INCLUDE),
    billingRepository.findManyAdjustments({ invoice: { deleted_at: null, tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}), ...(scope.patient_id ? { patient_id: scope.patient_id } : {}) } }, 0, Math.max(limit * 2, 50), { adjusted_at: 'desc' }, ADJUSTMENT_INCLUDE),
    billingRepository.findManyApprovals(approvalWhere, 0, Math.max(limit * 2, 50), { requested_at: 'desc' }, APPROVAL_INCLUDE),
  ]);

  const timeline = [
    ...invoices.map((x) => timelineItem('INVOICE', x)),
    ...payments.map((x) => timelineItem('PAYMENT', x)),
    ...refunds.map((x) => timelineItem('REFUND', x)),
    ...claims.map((x) => timelineItem('CLAIM', x)),
    ...preAuthorizations.map((x) => timelineItem('PRE_AUTH', x)),
    ...adjustments.map((x) => timelineItem('ADJUSTMENT', x)),
    ...approvals.map((x) => timelineItem('APPROVAL', x)),
  ].filter(Boolean).sort((a, b) => (toDate(b.timeline_at)?.getTime() || 0) - (toDate(a.timeline_at)?.getTime() || 0));

  const offset = (page - 1) * limit;
  const timelinePage = timeline.slice(offset, offset + limit);

  return {
    summary: {
      needs_issue: needsIssue,
      pending_payment: pendingPayment,
      claims_pending: claimsPending,
      approval_required: approvalPending,
      overdue,
      payments_today_total: toMoneyString(paymentsToday?._sum?.amount || 0),
      refunds_today_total: toMoneyString(refundsToday?._sum?.amount || 0),
    },
    queues: [
      { queue: QUEUE_TYPES.NEEDS_ISSUE, label: 'Needs issue', count: needsIssue },
      { queue: QUEUE_TYPES.PENDING_PAYMENT, label: 'Pending payment', count: pendingPayment },
      { queue: QUEUE_TYPES.CLAIMS_PENDING, label: 'Claims pending', count: claimsPending },
      { queue: QUEUE_TYPES.APPROVAL_REQUIRED, label: 'Approval required', count: approvalPending },
      { queue: QUEUE_TYPES.OVERDUE, label: 'Overdue', count: overdue },
    ],
    timeline: { groups: timelineGroups(timelinePage), items: timelinePage, pagination: pageMeta(page, limit, timeline.length) },
    generated_at: new Date().toISOString(),
  };
};

const getWorkItems = async (filters = {}, page = 1, limit = 20, user = {}) => {
  assertEnabled();
  const scope = await resolveScope(filters, user);
  const queue = normalizeQueue(filters.queue);
  if (queue) {
    const result = await runQueue(queue, scope, page, limit, filters.search);
    return { queue, items: result.items, pagination: pageMeta(page, limit, result.total) };
  }
  const results = await Promise.all(Object.values(QUEUE_TYPES).map((key) => runQueue(key, scope, 1, Math.min(10, limit), filters.search)));
  return { queues: results.map((entry) => ({ queue: entry.queue, items: entry.items, total: entry.total })) };
};

const assertOwnership = async (patient, user) => {
  if (hasPermission(user, PERMISSIONS.BILLING_READ)) return;
  if (!hasPermission(user, PERMISSIONS.PATIENT_READ)) throw new HttpError('errors.auth.insufficient_permissions', 403);
  const requester = await billingRepository.findUserById(clean(user.id));
  if (!requester) throw new HttpError('errors.auth.insufficient_permissions', 403);
  const reqEmail = clean(requester.email).toLowerCase();
  const reqPhone = clean(requester.phone);
  const contacts = Array.isArray(patient?.contacts) ? patient.contacts : [];
  const matches = contacts.some((contact) => {
    const type = clean(contact.contact_type).toUpperCase();
    const value = clean(contact.value);
    if (!value) return false;
    if (type === 'EMAIL') return value.toLowerCase() === reqEmail;
    if (type === 'PHONE') return value === reqPhone;
    return false;
  });
  if (!matches) throw new HttpError('errors.auth.insufficient_permissions', 403);
};

const getPatientLedger = async (patientIdentifier, filters = {}, page = 1, limit = 20, user = {}) => {
  assertEnabled();
  const scope = await resolveScope({}, user);
  const patient = await resolveScopedByIdentifier({
    model: 'patient',
    identifier: patientIdentifier,
    where: { tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) },
    include: { contacts: { where: { deleted_at: null }, select: { contact_type: true, value: true } } },
    errorKey: 'errors.patient.not_found',
  });
  await assertOwnership(patient, user);

  const from = toDate(filters.from);
  const to = toDate(filters.to);
  const dateFilter = from || to ? { created_at: { ...(from ? { gte: from } : {}), ...(to ? { lte: to } : {}) } } : {};

  const invoiceWhere = {
    tenant_id: scope.tenant_id,
    patient_id: patient.id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    ...dateFilter,
  };
  const paymentWhere = {
    tenant_id: scope.tenant_id,
    patient_id: patient.id,
    ...(scope.facility_id ? { facility_id: scope.facility_id } : {}),
    ...dateFilter,
  };
  const [invoices, payments, refunds, adjustments, claims] = await Promise.all([
    billingRepository.findManyInvoices(invoiceWhere, 0, 500, { created_at: 'desc' }, INVOICE_INCLUDE),
    billingRepository.findManyPayments(paymentWhere, 0, 500, { created_at: 'desc' }, PAYMENT_INCLUDE),
    billingRepository.findManyRefunds({ payment: { deleted_at: null, tenant_id: scope.tenant_id, patient_id: patient.id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) }, ...dateFilter }, 0, 500, { created_at: 'desc' }, REFUND_INCLUDE),
    billingRepository.findManyAdjustments({ invoice: { deleted_at: null, tenant_id: scope.tenant_id, patient_id: patient.id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) }, ...dateFilter }, 0, 500, { created_at: 'desc' }, ADJUSTMENT_INCLUDE),
    billingRepository.findManyClaims({ invoice: { deleted_at: null, tenant_id: scope.tenant_id, patient_id: patient.id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) }, ...dateFilter }, 0, 500, { created_at: 'desc' }, CLAIM_INCLUDE),
  ]);

  const entries = [
    ...invoices.map((x) => timelineItem('INVOICE', x)),
    ...payments.map((x) => timelineItem('PAYMENT', x)),
    ...refunds.map((x) => timelineItem('REFUND', x)),
    ...adjustments.map((x) => timelineItem('ADJUSTMENT', x)),
    ...claims.map((x) => timelineItem('CLAIM', x)),
  ].filter(Boolean).sort((a, b) => (toDate(b.timeline_at)?.getTime() || 0) - (toDate(a.timeline_at)?.getTime() || 0));
  const offset = (page - 1) * limit;
  const ledgerPage = entries.slice(offset, offset + limit);

  const totalInvoiced = invoices.reduce((sum, invoice) => sum + toDecimalNumber(invoice.total_amount), 0);
  const totalAdjustments = adjustments.reduce((sum, adjustment) => {
    if (!APPLIED_ADJUSTMENT_STATUSES.has(clean(adjustment.status).toUpperCase())) return sum;
    return sum + toDecimalNumber(adjustment.amount);
  }, 0);
  const totalPaid = payments.reduce((sum, payment) => sum + (clean(payment.status).toUpperCase() === 'COMPLETED' ? toDecimalNumber(payment.amount) : 0), 0);
  const totalRefunded = refunds.reduce((sum, refund) => sum + toDecimalNumber(refund.amount), 0);
  const netPaid = totalPaid - totalRefunded;

  return {
    patient: { id: patient.id, display_id: displayId(patient), display_name: patientName(patient) },
    summary: {
      total_invoiced: toMoneyString(totalInvoiced),
      total_adjustments: toMoneyString(totalAdjustments),
      total_paid: toMoneyString(totalPaid),
      total_refunded: toMoneyString(totalRefunded),
      net_paid: toMoneyString(netPaid),
      balance_due: toMoneyString(totalInvoiced + totalAdjustments - netPaid),
    },
    ledger: { groups: timelineGroups(ledgerPage), items: ledgerPage, pagination: pageMeta(page, limit, entries.length) },
  };
};

const issueInvoice = async (invoiceIdentifier, payload = {}, user = {}, ip = null) => {
  assertEnabled();
  const scope = await resolveScope({}, user);
  const invoice = await resolveScopedByIdentifier({
    model: 'invoice',
    identifier: invoiceIdentifier,
    where: { tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) },
    include: INVOICE_INCLUDE,
    errorKey: 'errors.invoice.not_found',
  });
  if (['CANCELLED'].includes(clean(invoice.status).toUpperCase()) || ['CANCELLED'].includes(clean(invoice.billing_status).toUpperCase())) {
    throw new HttpError('errors.invoice.cannot_issue_cancelled', 400);
  }
  await billingRepository.updateInvoice(invoice.id, {
    status: clean(invoice.status).toUpperCase() === 'DRAFT' ? 'SENT' : invoice.status,
    billing_status: clean(invoice.billing_status).toUpperCase() === 'DRAFT' ? 'ISSUED' : invoice.billing_status,
    issued_at: payload.issued_at ? new Date(payload.issued_at) : invoice.issued_at || new Date(),
  });
  const updated = await billingRepository.findInvoiceById(invoice.id, INVOICE_INCLUDE);
  auditUpdate(user, ip, 'invoice', invoice.id, { transition: 'ISSUE', notes: payload.notes || null });
  return { invoice: mapInvoice(updated || invoice, true) };
};

const sendInvoice = async (invoiceIdentifier, payload = {}, user = {}, ip = null) => {
  assertEnabled();
  await issueInvoice(invoiceIdentifier, {}, user, ip);
  const scope = await resolveScope({}, user);
  const invoice = await resolveScopedByIdentifier({
    model: 'invoice',
    identifier: invoiceIdentifier,
    where: { tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) },
    include: INVOICE_INCLUDE,
    errorKey: 'errors.invoice.not_found',
  });
  const recipient = clean(payload.recipient_email).toLowerCase() || (Array.isArray(invoice.patient?.contacts)
    ? (invoice.patient.contacts.find((c) => clean(c.contact_type).toUpperCase() === 'EMAIL')?.value || '').toLowerCase()
    : '') || null;
  const financials = computeInvoiceFinancials(invoice);
  const pdf = await generateInvoicePdfBuffer({ invoice, financials });
  const fileName = `invoice-${displayId(invoice) || invoice.id}.pdf`;

  let delivery = { attempted: Boolean(recipient), sent: false, recipient_email: recipient, provider: 'skipped' };
  if (recipient) {
    const emailResult = await sendEmail({
      to: recipient,
      subject: `Invoice ${displayId(invoice) || ''}`.trim(),
      text: `Invoice: ${displayId(invoice) || 'N/A'}\nBalance due: ${toMoneyString(financials.balance_due)} ${invoice.currency}`,
      attachments: [{ filename: fileName, content: pdf, contentType: 'application/pdf' }],
    });
    delivery = { attempted: true, sent: Boolean(emailResult?.sent), recipient_email: recipient, provider: emailResult?.provider || 'unknown' };
  }

  auditUpdate(user, ip, 'invoice', invoice.id, { transition: 'SEND', recipient_email: recipient, sent: delivery.sent });
  return { invoice: mapInvoice(invoice, true), delivery };
};

const requestInvoiceVoid = async (invoiceIdentifier, payload = {}, user = {}, ip = null) => {
  assertEnabled();
  const scope = await resolveScope({}, user);
  const invoice = await resolveScopedByIdentifier({
    model: 'invoice',
    identifier: invoiceIdentifier,
    where: { tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) },
    select: { id: true, human_friendly_id: true, tenant_id: true, facility_id: true, status: true },
    errorKey: 'errors.invoice.not_found',
  });
  if (clean(invoice.status).toUpperCase() === 'CANCELLED') throw new HttpError('errors.invoice.already_cancelled', 400);

  const approval = await billingRepository.createApproval({
    tenant_id: invoice.tenant_id,
    facility_id: invoice.facility_id || null,
    approval_type: 'VOID',
    target_entity: 'invoice',
    target_entity_id: invoice.id,
    requested_by_user_id: user.id,
    status: 'PENDING',
    reason: payload.reason,
    payload_json: {
      invoice_id: invoice.id,
      invoice_display_id: displayId(invoice),
      target_display_id: displayId(invoice),
      notes: payload.notes || null,
    },
  });
  auditCreate(user, ip, 'billing_approval', approval.id, approval);
  const fullApproval = await billingRepository.findApprovalById(approval.id, APPROVAL_INCLUDE);
  return { approval: mapApproval(fullApproval || approval) };
};

const reconcilePayment = async (paymentIdentifier, payload = {}, user = {}, ip = null) => {
  assertEnabled();
  const scope = await resolveScope({}, user);
  const payment = await resolveScopedByIdentifier({
    model: 'payment',
    identifier: paymentIdentifier,
    where: { tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) },
    include: PAYMENT_INCLUDE,
    errorKey: 'errors.payment.not_found',
  });

  const mutation = await billingRepository.withTransaction(async (tx) => {
    const updatedPayment = await tx.payment.update({
      where: { id: payment.id },
      data: { status: payload.status || 'COMPLETED', paid_at: payment.paid_at || new Date() },
    });
    const invoiceState = await recalculateInvoiceStateTx(tx, payment.invoice_id);
    return { payment: updatedPayment, invoiceState };
  });

  auditUpdate(user, ip, 'payment', payment.id, { transition: 'RECONCILE', status: payload.status || 'COMPLETED', notes: payload.notes || null });
  const [updatedPayment, updatedInvoice] = await Promise.all([
    billingRepository.findPaymentById(payment.id, PAYMENT_INCLUDE),
    mutation.invoiceState?.invoice ? billingRepository.findInvoiceById(mutation.invoiceState.invoice.id, INVOICE_INCLUDE) : Promise.resolve(null),
  ]);
  return {
    payment: mapPayment(updatedPayment || mutation.payment),
    invoice: updatedInvoice ? mapInvoice(updatedInvoice, true) : null,
    financials: mutation.invoiceState?.financials || null,
  };
};

const requestPaymentRefund = async (paymentIdentifier, payload = {}, user = {}, ip = null) => {
  assertEnabled();
  const scope = await resolveScope({}, user);
  const payment = await resolveScopedByIdentifier({
    model: 'payment',
    identifier: paymentIdentifier,
    where: { tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) },
    include: PAYMENT_INCLUDE,
    errorKey: 'errors.payment.not_found',
  });
  if (!['COMPLETED', 'REFUNDED'].includes(clean(payment.status).toUpperCase())) throw new HttpError('errors.payment.invalid_status', 400);

  const refunded = (payment.refunds || []).reduce((sum, item) => sum + toDecimalNumber(item.amount), 0);
  const remaining = toDecimalNumber(payment.amount) - refunded;
  const requestedAmount = payload.amount ? toDecimalNumber(payload.amount) : remaining;
  if (requestedAmount <= 0 || requestedAmount > remaining + 0.009) throw new HttpError('errors.refund.invalid_amount', 400);

  const approval = await billingRepository.createApproval({
    tenant_id: payment.tenant_id,
    facility_id: payment.facility_id || null,
    approval_type: 'REFUND',
    target_entity: 'payment',
    target_entity_id: payment.id,
    requested_by_user_id: user.id,
    status: 'PENDING',
    reason: payload.reason,
    payload_json: {
      payment_id: payment.id,
      payment_display_id: displayId(payment),
      invoice_id: payment.invoice_id,
      invoice_display_id: displayId(payment.invoice || {}),
      target_display_id: displayId(payment),
      amount: toMoneyString(requestedAmount),
      notes: payload.notes || null,
    },
  });

  auditCreate(user, ip, 'billing_approval', approval.id, approval);
  const fullApproval = await billingRepository.findApprovalById(approval.id, APPROVAL_INCLUDE);
  return { approval: mapApproval(fullApproval || approval), payment: mapPayment(payment) };
};

const requestAdjustment = async (payload = {}, user = {}, ip = null) => {
  assertEnabled();
  const scope = await resolveScope({}, user);
  const invoice = await resolveScopedByIdentifier({
    model: 'invoice',
    identifier: payload.invoice_id,
    where: { tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) },
    include: INVOICE_INCLUDE,
    errorKey: 'errors.invoice.not_found',
  });
  if (['CANCELLED'].includes(clean(invoice.status).toUpperCase()) || ['CANCELLED'].includes(clean(invoice.billing_status).toUpperCase())) {
    throw new HttpError('errors.invoice.invalid_status', 400);
  }
  const amount = toDecimalNumber(payload.amount);
  if (!amount) throw new HttpError('errors.billing_adjustment.invalid_amount', 400);

  const approvalRequired =
    Math.abs(amount) >= ADJUSTMENT_ABS_THRESHOLD ||
    (Math.abs(toDecimalNumber(invoice.total_amount)) > 0 &&
      Math.abs(amount) >= Math.abs(toDecimalNumber(invoice.total_amount)) * ADJUSTMENT_PERCENT_THRESHOLD);

  if (approvalRequired) {
    const approval = await billingRepository.createApproval({
      tenant_id: invoice.tenant_id,
      facility_id: invoice.facility_id || null,
      approval_type: 'ADJUSTMENT',
      target_entity: 'invoice',
      target_entity_id: invoice.id,
      requested_by_user_id: user.id,
      status: 'PENDING',
      reason: payload.reason,
      payload_json: {
        invoice_id: invoice.id,
        invoice_display_id: displayId(invoice),
        target_display_id: displayId(invoice),
        amount: toMoneyString(amount),
        status: payload.status || 'ISSUED',
        adjusted_at: payload.adjusted_at || new Date().toISOString(),
        notes: payload.notes || null,
      },
    });
    auditCreate(user, ip, 'billing_approval', approval.id, approval);
    const fullApproval = await billingRepository.findApprovalById(approval.id, APPROVAL_INCLUDE);
    return { approval_required: true, approval: mapApproval(fullApproval || approval) };
  }

  const mutation = await billingRepository.withTransaction(async (tx) => {
    const adjustment = await tx.billing_adjustment.create({
      data: {
        invoice_id: invoice.id,
        amount: toMoneyString(amount),
        status: payload.status || 'ISSUED',
        reason: payload.reason,
        adjusted_at: payload.adjusted_at ? new Date(payload.adjusted_at) : new Date(),
      },
    });
    const invoiceState = await recalculateInvoiceStateTx(tx, invoice.id);
    return { adjustment, invoiceState };
  });

  auditCreate(user, ip, 'billing_adjustment', mutation.adjustment.id, mutation.adjustment);
  const [adjustment, updatedInvoice] = await Promise.all([
    resolveScopedByIdentifier({
      model: 'billing_adjustment',
      identifier: mutation.adjustment.id,
      where: { invoice: { tenant_id: scope.tenant_id } },
      include: ADJUSTMENT_INCLUDE,
      errorKey: 'errors.billing_adjustment.not_found',
    }),
    mutation.invoiceState?.invoice ? billingRepository.findInvoiceById(mutation.invoiceState.invoice.id, INVOICE_INCLUDE) : Promise.resolve(null),
  ]);
  return {
    approval_required: false,
    adjustment: mapAdjustment(adjustment),
    invoice: updatedInvoice ? mapInvoice(updatedInvoice, true) : null,
    financials: mutation.invoiceState?.financials || null,
  };
};

const executeApproval = async (tx, approval) => {
  const type = clean(approval.approval_type).toUpperCase();

  if (type === 'VOID') {
    const invoice = await tx.invoice.findFirst({ where: { id: approval.target_entity_id, deleted_at: null } });
    if (!invoice) throw new HttpError('errors.invoice.not_found', 404);
    const updatedInvoice = await tx.invoice.update({ where: { id: invoice.id }, data: { status: 'CANCELLED', billing_status: 'CANCELLED' } });
    return { type, invoice: updatedInvoice };
  }

  if (type === 'REFUND') {
    const paymentId = clean(approval.payload_json?.payment_id) || clean(approval.target_entity_id);
    const payment = await tx.payment.findFirst({ where: { id: paymentId, deleted_at: null }, include: { refunds: { where: { deleted_at: null } } } });
    if (!payment) throw new HttpError('errors.payment.not_found', 404);

    const amount = toDecimalNumber(approval.payload_json?.amount);
    const refunded = (payment.refunds || []).reduce((sum, item) => sum + toDecimalNumber(item.amount), 0);
    const remaining = toDecimalNumber(payment.amount) - refunded;
    if (amount <= 0 || amount > remaining + 0.009) throw new HttpError('errors.refund.invalid_amount', 400);

    const refund = await tx.refund.create({
      data: {
        payment_id: payment.id,
        amount: toMoneyString(amount),
        reason: approval.reason || null,
        refunded_at: new Date(),
      },
    });
    if (refunded + amount >= toDecimalNumber(payment.amount) - 0.009) {
      await tx.payment.update({ where: { id: payment.id }, data: { status: 'REFUNDED' } });
    }
    const invoiceState = await recalculateInvoiceStateTx(tx, payment.invoice_id);
    return { type, refund, invoiceState };
  }

  if (type === 'ADJUSTMENT') {
    const invoiceId = clean(approval.payload_json?.invoice_id) || clean(approval.target_entity_id);
    const invoice = await tx.invoice.findFirst({ where: { id: invoiceId, deleted_at: null } });
    if (!invoice) throw new HttpError('errors.invoice.not_found', 404);

    const adjustment = await tx.billing_adjustment.create({
      data: {
        invoice_id: invoice.id,
        amount: toMoneyString(approval.payload_json?.amount),
        status: clean(approval.payload_json?.status).toUpperCase() || 'ISSUED',
        reason: approval.reason || null,
        adjusted_at: toDate(approval.payload_json?.adjusted_at) || new Date(),
      },
    });
    const invoiceState = await recalculateInvoiceStateTx(tx, invoice.id);
    return { type, adjustment, invoiceState };
  }

  throw new HttpError('errors.validation.invalid', 400, [{ field: 'approval_type' }]);
};

const approveApproval = async (approvalIdentifier, payload = {}, user = {}, ip = null) => {
  assertEnabled();
  const scope = await resolveScope({}, user);
  const approval = await resolveScopedByIdentifier({
    model: 'billing_approval',
    identifier: approvalIdentifier,
    where: { tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) },
    include: APPROVAL_INCLUDE,
    errorKey: 'errors.billing_approval.not_found',
  });
  if (clean(approval.status).toUpperCase() !== 'PENDING') throw new HttpError('errors.billing_approval.invalid_status', 400);
  if (clean(approval.requested_by_user_id) === clean(user.id)) throw new HttpError('errors.billing_approval.separation_of_duties', 400);

  const mutation = await billingRepository.withTransaction(async (tx) => {
    const execution = await executeApproval(tx, approval);
    const updatedApproval = await tx.billing_approval.update({
      where: { id: approval.id },
      data: { status: 'APPROVED', approved_by_user_id: user.id, decided_at: new Date(), decision_notes: payload.decision_notes || null },
    });
    return { execution, approval: updatedApproval };
  });

  auditUpdate(user, ip, 'billing_approval', approval.id, { transition: 'APPROVE', approval_type: approval.approval_type });
  if (mutation.execution?.type === 'REFUND' && mutation.execution?.refund?.id) auditCreate(user, ip, 'refund', mutation.execution.refund.id, mutation.execution.refund);
  if (mutation.execution?.type === 'ADJUSTMENT' && mutation.execution?.adjustment?.id) auditCreate(user, ip, 'billing_adjustment', mutation.execution.adjustment.id, mutation.execution.adjustment);
  if (mutation.execution?.type === 'VOID' && mutation.execution?.invoice?.id) auditUpdate(user, ip, 'invoice', mutation.execution.invoice.id, { transition: 'VOID_EXECUTED' });

  const fullApproval = await billingRepository.findApprovalById(mutation.approval.id, APPROVAL_INCLUDE);
  return {
    approval: mapApproval(fullApproval || mutation.approval),
    execution: mutation.execution,
    financials: mutation.execution?.invoiceState?.financials || null,
  };
};

const rejectApproval = async (approvalIdentifier, payload = {}, user = {}, ip = null) => {
  assertEnabled();
  const scope = await resolveScope({}, user);
  const approval = await resolveScopedByIdentifier({
    model: 'billing_approval',
    identifier: approvalIdentifier,
    where: { tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) },
    include: APPROVAL_INCLUDE,
    errorKey: 'errors.billing_approval.not_found',
  });
  if (clean(approval.status).toUpperCase() !== 'PENDING') throw new HttpError('errors.billing_approval.invalid_status', 400);
  if (clean(approval.requested_by_user_id) === clean(user.id)) throw new HttpError('errors.billing_approval.separation_of_duties', 400);

  const updated = await billingRepository.updateApproval(approval.id, {
    status: 'REJECTED',
    approved_by_user_id: user.id,
    reason: payload.reason || approval.reason,
    decision_notes: payload.decision_notes || null,
    decided_at: new Date(),
  });
  auditUpdate(user, ip, 'billing_approval', updated.id, { transition: 'REJECT', reason: payload.reason || null });
  const fullApproval = await billingRepository.findApprovalById(updated.id, APPROVAL_INCLUDE);
  return { approval: mapApproval(fullApproval || updated) };
};

const getInvoiceDocument = async (invoiceIdentifier, user = {}) => {
  assertEnabled();
  const scope = await resolveScope({}, user);
  const invoice = await resolveScopedByIdentifier({
    model: 'invoice',
    identifier: invoiceIdentifier,
    where: { tenant_id: scope.tenant_id, ...(scope.facility_id ? { facility_id: scope.facility_id } : {}) },
    include: INVOICE_INCLUDE,
    errorKey: 'errors.invoice.not_found',
  });
  await assertOwnership(invoice.patient || {}, user);
  const buffer = await generateInvoicePdfBuffer({ invoice, financials: computeInvoiceFinancials(invoice) });
  createAuditLog({
    tenant_id: invoice.tenant_id,
    user_id: user?.id || null,
    action: 'EXPORT',
    entity: 'invoice',
    entity_id: invoice.id,
    diff: { metadata: { format: 'PDF' } },
  }).catch(() => {});
  return { buffer, file_name: `invoice-${displayId(invoice) || invoice.id}.pdf` };
};

module.exports = {
  getWorkspace,
  getWorkItems,
  getPatientLedger,
  issueInvoice,
  sendInvoice,
  requestInvoiceVoid,
  reconcilePayment,
  requestPaymentRefund,
  requestAdjustment,
  approveApproval,
  rejectApproval,
  getInvoiceDocument,
};
