/**
 * Subscription payment request helpers (manual / mobile money / card initiation).
 *
 * @module lib/subscriptions/subscription-payment-request
 */

const crypto = require('crypto');
const prisma = require('@prisma/client');
const env = require('@config/env');
const { HttpError } = require('@lib/errors');
const { createAuditLog } = require('@lib/audit');
const { sendEmail } = require('@lib/notifications');
const { createStorageService, sanitizeFilename } = require('@lib/storage');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { resolveModelRecordByIdentifier } = require('@lib/identifiers/resolve-entity-id');
const { runWithoutTenantGuard } = require('../../prisma/tenant-guard');
const {
  resolvePlatformAdminContact,
  resolvePlatformBankTransferDetails,
  resolvePlatformMobileMoneyDetails,
  resolveTenantSubscriptionSummary,
} = require('@lib/subscriptions/tenant-subscription-summary');
const { serializeSubscriptionPlan } = require('@lib/subscriptions/serializers');

const PAYMENT_METHODS = [
  'BANK_TRANSFER',
  'MOBILE_MONEY',
  'CREDIT_CARD',
  'DEBIT_CARD',
  'CASH',
  'OTHER',
];

const text = (value) => String(value || '').trim();

const safePublicId = (...values) => resolvePublicIdentifier(...values) || null;

const parseExtensionJson = (value) => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return { ...value };
};

const getCycleDays = (billingCycle) => {
  const cycle = text(billingCycle).toUpperCase();
  if (cycle.includes('YEAR') || cycle === 'ANNUAL') return 365;
  if (cycle.includes('QUARTER')) return 90;
  return 30;
};

const addBillingCycle = (baseDate, billingCycle) => {
  const date = new Date(baseDate);
  const cycle = text(billingCycle).toUpperCase();
  if (cycle.includes('YEAR') || cycle === 'ANNUAL') {
    date.setFullYear(date.getFullYear() + 1);
    return date;
  }
  if (cycle.includes('QUARTER')) {
    date.setMonth(date.getMonth() + 3);
    return date;
  }
  date.setMonth(date.getMonth() + 1);
  return date;
};

const formatMoney = (amount, currency) => {
  const value = text(amount) || '0';
  const code = text(currency).toUpperCase() || 'UGX';
  return `${code} ${value}`;
};

const formatDate = (value) => {
  if (!value) return 'Not set';
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return 'Not set';
  return date.toISOString().slice(0, 10);
};

const {
  resolveBillingTenantScope,
} = require('@lib/subscriptions/access');

const loadCurrentSubscription = async (tenantId) => {
  const subscription = await prisma.subscription.findFirst({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      status: { in: ['ACTIVE', 'TRIAL', 'PAST_DUE'] },
    },
    orderBy: [{ updated_at: 'desc' }],
    include: {
      tenant: { select: { id: true, name: true, human_friendly_id: true } },
      plan: true,
      pending_plan: true,
    },
  });

  if (!subscription) {
    throw new HttpError('errors.subscription.not_found', 404);
  }

  return subscription;
};

const resolvePlanRecord = async (planIdentifier, tenantId) => {
  if (!planIdentifier) {
    return null;
  }

  // Platform catalog plans use tenant_id null; tenant guard would hide them.
  const record = await runWithoutTenantGuard(() =>
    resolveModelRecordByIdentifier({
      model: 'subscription_plan',
      identifier: planIdentifier,
      where: {
        deleted_at: null,
        OR: [{ tenant_id: null }, { tenant_id: tenantId }],
      },
    })
  );

  return record || null;
};

const loadUpgradePlans = async (tenantId) =>
  runWithoutTenantGuard(() =>
    prisma.subscription_plan.findMany({
      where: {
        deleted_at: null,
        OR: [{ tenant_id: null }, { tenant_id: tenantId }],
      },
      orderBy: [{ price: 'asc' }],
    })
  );

const uploadProofFile = async (file, tenantId) => {
  if (!file?.buffer?.length) {
    return null;
  }

  const storage = createStorageService();
  const safeName = sanitizeFilename(file.originalname || 'payment-proof');
  const storagePath = `subscriptions/${tenantId}/payment-proofs/${Date.now()}-${safeName}`;
  const uploaded = await storage.upload(file.buffer, storagePath, {
    mimeType: file.mimetype || 'application/octet-stream',
    encrypt: true,
  });

  return {
    storage_path: uploaded?.path || storagePath,
    file_name: safeName,
    mime_type: file.mimetype || null,
    size_bytes: file.size || file.buffer.length,
  };
};

const notifyPlatformAdmin = async ({
  tenantName,
  planLabel,
  paymentMethod,
  amount,
  reference,
  submitterEmail,
}) => {
  const contact = resolvePlatformAdminContact();
  const adminEmail = contact.email;
  if (!adminEmail) {
    return { sent: false, provider: 'skipped' };
  }

  const subject = `Subscription payment submitted — ${tenantName || 'Tenant'}`;
  const lines = [
    'A tenant submitted a subscription payment request.',
    '',
    `Tenant: ${tenantName || 'Unknown'}`,
    `Plan: ${planLabel || 'Not specified'}`,
    `Payment method: ${paymentMethod || 'Not specified'}`,
    `Amount: ${amount || 'Not specified'}`,
    `Reference: ${reference || 'Not specified'}`,
    `Submitted by: ${submitterEmail || 'Unknown'}`,
    '',
    'Review pending subscription activations in Tenant setup → Subscription activations.',
  ];

  return sendEmail({
    to: adminEmail,
    subject,
    text: lines.join('\n'),
  });
};

const notifyTenantActivation = async ({
  email,
  tenantName,
  planLabel,
  amount,
  currency,
  billingCycle,
  startDate,
  endDate,
}) => {
  if (!email) {
    return { sent: false, provider: 'skipped' };
  }

  const period =
    text(billingCycle).toUpperCase().includes('YEAR') ||
    text(billingCycle).toUpperCase() === 'ANNUAL'
      ? 'Annual'
      : 'Monthly';
  const subject = `Subscription activated — ${planLabel || 'Hosspi'}`;
  const lines = [
    `Hello${tenantName ? ` from ${tenantName}` : ''},`,
    '',
    'Your subscription payment was confirmed and your account is now active.',
    '',
    `Package: ${planLabel || 'Not specified'}`,
    `Period: ${period}`,
    `Amount paid: ${formatMoney(amount, currency)}`,
    `Start date: ${formatDate(startDate)}`,
    `End date: ${formatDate(endDate)}`,
    '',
    'Thank you for choosing Hosspi.',
  ];

  return sendEmail({
    to: email,
    subject,
    text: lines.join('\n'),
  });
};

/**
 * @param {Object} user
 * @returns {Promise<Object>}
 */
const getUpgradeContext = async (user = {}) => {
  const tenantId = resolveBillingTenantScope(user);
  const [overviewSubscription, plans, summary, catalogModules] = await Promise.all([
    loadCurrentSubscription(tenantId).catch(() => null),
    loadUpgradePlans(tenantId),
    resolveTenantSubscriptionSummary(tenantId),
    runWithoutTenantGuard(() =>
      prisma.module.findMany({
        where: { deleted_at: null },
        select: {
          id: true,
          human_friendly_id: true,
          slug: true,
          name: true,
          is_add_on: true,
          minimum_plan_tier_code: true,
          extension_json: true,
        },
      })
    ).catch(() => []),
  ]);

  const currentPlanId = overviewSubscription?.plan_id || null;
  const serializedPlans = plans.map((plan) =>
    serializeSubscriptionPlan(plan, { catalogModules })
  );
  const recommendedPlan =
    serializedPlans.find((plan) => plan.id !== safePublicId(
      overviewSubscription?.plan?.human_friendly_id,
      currentPlanId
    )) || serializedPlans[0] || null;

  return {
    subscription_summary: summary,
    current_subscription: overviewSubscription
      ? {
          id: safePublicId(
            overviewSubscription.human_friendly_id,
            overviewSubscription.id
          ),
          status: overviewSubscription.status,
          plan_id: safePublicId(
            overviewSubscription.plan?.human_friendly_id,
            overviewSubscription.plan_id
          ),
          plan_label: overviewSubscription.plan?.name || null,
          tier_code: overviewSubscription.plan?.tier_code || null,
          end_date: overviewSubscription.end_date || null,
        }
      : null,
    plans: serializedPlans,
    recommended_plan_id: recommendedPlan?.id || null,
    payment_methods: PAYMENT_METHODS,
    platform_admin_contact: resolvePlatformAdminContact(),
    bank_transfer_details: resolvePlatformBankTransferDetails(),
    mobile_money_details: resolvePlatformMobileMoneyDetails(),
    expiring_soon_days: Number(env.SUBSCRIPTION_EXPIRING_SOON_DAYS) || 14,
  };
};

/**
 * @param {Object} payload
 * @param {Array<Object>} files
 * @param {Object} user
 * @param {string} ip
 * @returns {Promise<Object>}
 */
const submitPaymentRequest = async (payload = {}, files = [], user = {}, ip = null) => {
  const tenantId = resolveBillingTenantScope(user, payload);
  const subscription = await loadCurrentSubscription(tenantId);
  if (subscription.tenant_id !== tenantId) {
    throw new HttpError('errors.auth.scope_mismatch', 403, [
      { field: 'tenant_id', reason: 'outside_actor_tenant' },
    ]);
  }
  const paymentMethod = text(payload.payment_method).toUpperCase() || 'BANK_TRANSFER';

  if (!PAYMENT_METHODS.includes(paymentMethod)) {
    throw new HttpError('errors.validation.payment_method.invalid', 400);
  }

  const targetPlan = await resolvePlanRecord(
    payload.target_plan_id || payload.plan_id,
    tenantId
  );
  const proofFile = Array.isArray(files) ? files[0] : null;
  const proof = await uploadProofFile(proofFile, tenantId);
  const requestId = crypto.randomUUID();
  const submittedAt = new Date().toISOString();

  const paymentRequest = {
    id: requestId,
    status: 'PENDING',
    payment_method: paymentMethod,
    target_plan_id: targetPlan
      ? safePublicId(targetPlan.human_friendly_id, targetPlan.id)
      : null,
    plan_label: targetPlan?.name || subscription.plan?.name || null,
    amount: text(payload.amount) || null,
    currency: text(payload.currency) || null,
    billing_cycle: text(payload.billing_cycle).toUpperCase() || null,
    invoice_email: text(payload.invoice_email) || null,
    reference: text(payload.reference) || null,
    notes: text(payload.notes) || null,
    payment_provider: text(payload.payment_provider) || null,
    payer_phone: text(payload.payer_phone) || null,
    bank_name: text(payload.bank_name) || null,
    card_holder_name: text(payload.card_holder_name) || null,
    card_last_four: text(payload.card_last_four) || null,
    proof,
    submitted_at: submittedAt,
    submitted_by_user_id: user.id || null,
    submitted_by_email: user.email || null,
  };

  const extension = parseExtensionJson(subscription.extension_json);
  const pendingRequests = Array.isArray(extension.pending_payment_requests)
    ? extension.pending_payment_requests
    : [];
  extension.pending_payment_requests = [
    paymentRequest,
    ...pendingRequests.filter((entry) => entry?.status === 'PENDING').slice(0, 9),
  ];
  extension.latest_payment_request = paymentRequest;

  const updateData = {
    extension_json: extension,
  };

  if (targetPlan && targetPlan.id !== subscription.plan_id) {
    updateData.pending_plan_id = targetPlan.id;
    updateData.change_status = 'PENDING_UPGRADE';
    updateData.change_requested_at = new Date();
  }

  await prisma.subscription.update({
    where: { id: subscription.id },
    data: updateData,
  });

  await notifyPlatformAdmin({
    tenantName: subscription.tenant?.name,
    planLabel: paymentRequest.plan_label,
    paymentMethod,
    amount: paymentRequest.amount,
    reference: paymentRequest.reference,
    submitterEmail: user.email,
  });

  await createAuditLog({
    tenant_id: tenantId,
    user_id: user.id || null,
    action: 'SUBSCRIPTION_PAYMENT_REQUESTED',
    entity: 'subscription',
    entity_id: subscription.id,
    ip_address: ip,
    details: {
      request_id: requestId,
      payment_method: paymentMethod,
      payment_provider: paymentRequest.payment_provider,
      target_plan_id: paymentRequest.target_plan_id,
      amount: paymentRequest.amount,
      currency: paymentRequest.currency,
      reference: paymentRequest.reference,
      has_proof: Boolean(proof),
    },
  }).catch(() => {});

  return {
    request_id: requestId,
    status: 'PENDING',
    payment_method: paymentMethod,
    plan_label: paymentRequest.plan_label,
    platform_admin_notified: Boolean(resolvePlatformAdminContact().email),
  };
};

/**
 * List pending payment requests for platform platform admins.
 *
 * @returns {Promise<Array<Object>>}
 */
const listPendingPaymentRequests = async () => {
  const subscriptions = await prisma.subscription.findMany({
    where: { deleted_at: null },
    include: {
      tenant: { select: { id: true, human_friendly_id: true, name: true } },
      plan: { select: { id: true, human_friendly_id: true, name: true } },
    },
    orderBy: [{ updated_at: 'desc' }],
    take: 200,
  });

  const items = [];

  subscriptions.forEach((subscription) => {
    const extension = parseExtensionJson(subscription.extension_json);
    const requests = Array.isArray(extension.pending_payment_requests)
      ? extension.pending_payment_requests
      : [];

    requests
      .filter((entry) => text(entry?.status).toUpperCase() === 'PENDING')
      .forEach((entry) => {
        items.push({
          id: entry.id,
          display_id: entry.id,
          subscription_id: safePublicId(
            subscription.human_friendly_id,
            subscription.id
          ),
          tenant_id: safePublicId(
            subscription.tenant?.human_friendly_id,
            subscription.tenant_id
          ),
          tenant_label: subscription.tenant?.name || null,
          current_plan_label: subscription.plan?.name || null,
          plan_label: entry.plan_label || null,
          payment_method: entry.payment_method || null,
          amount: entry.amount || null,
          currency: entry.currency || null,
          billing_cycle: entry.billing_cycle || null,
          reference: entry.reference || null,
          notes: entry.notes || null,
          proof: entry.proof || null,
          status: 'PENDING_REVIEW',
          submitted_at: entry.submitted_at || null,
          submitted_by_email: entry.submitted_by_email || null,
        });
      });
  });

  return items.sort((left, right) => {
    const leftTime = new Date(left.submitted_at || 0).getTime();
    const rightTime = new Date(right.submitted_at || 0).getTime();
    return rightTime - leftTime;
  });
};

/**
 * @returns {Promise<number>}
 */
const countPendingPaymentRequests = async () => {
  const items = await listPendingPaymentRequests();
  return items.length;
};

/**
 * Activate a pending subscription payment request (platform admin).
 *
 * @param {string} requestId
 * @param {Object} actor
 * @param {string|null} ip
 * @returns {Promise<Object>}
 */
const activatePaymentRequest = async (requestId, actor = {}, ip = null) => {
  const requestIdentifier = text(requestId);
  if (!requestIdentifier) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'request_id' }]);
  }

  const subscriptions = await prisma.subscription.findMany({
    where: { deleted_at: null },
    include: {
      tenant: { select: { id: true, human_friendly_id: true, name: true } },
      plan: true,
      pending_plan: true,
    },
    orderBy: [{ updated_at: 'desc' }],
    take: 200,
  });

  let matchedSubscription = null;
  let matchedRequest = null;

  for (const subscription of subscriptions) {
    const extension = parseExtensionJson(subscription.extension_json);
    const requests = Array.isArray(extension.pending_payment_requests)
      ? extension.pending_payment_requests
      : [];
    const found = requests.find(
      (entry) =>
        text(entry?.id) === requestIdentifier &&
        text(entry?.status).toUpperCase() === 'PENDING'
    );
    if (found) {
      matchedSubscription = subscription;
      matchedRequest = found;
      break;
    }
  }

  if (!matchedSubscription || !matchedRequest) {
    throw new HttpError('errors.subscription.payment_request_not_found', 404);
  }

  const billingCycle =
    text(matchedRequest.billing_cycle).toUpperCase() ||
    text(matchedSubscription.pending_plan?.billing_cycle).toUpperCase() ||
    text(matchedSubscription.plan?.billing_cycle).toUpperCase() ||
    'MONTHLY';

  const now = new Date();
  const baseDate =
    matchedSubscription.end_date && new Date(matchedSubscription.end_date) > now
      ? new Date(matchedSubscription.end_date)
      : now;
  const startDate = now;
  const endDate = addBillingCycle(baseDate, billingCycle);

  let targetPlanId = matchedSubscription.pending_plan_id || matchedSubscription.plan_id;
  if (matchedRequest.target_plan_id) {
    const resolved = await resolvePlanRecord(
      matchedRequest.target_plan_id,
      matchedSubscription.tenant_id
    );
    if (resolved) {
      targetPlanId = resolved.id;
    }
  }

  const extension = parseExtensionJson(matchedSubscription.extension_json);
  const requests = Array.isArray(extension.pending_payment_requests)
    ? extension.pending_payment_requests
    : [];
  const activatedAt = now.toISOString();
  extension.pending_payment_requests = requests.map((entry) => {
    if (text(entry?.id) !== requestIdentifier) {
      return entry;
    }
    return {
      ...entry,
      status: 'ACTIVATED',
      activated_at: activatedAt,
      activated_by_user_id: actor.id || null,
      activated_by_email: actor.email || null,
    };
  });
  extension.latest_payment_request = {
    ...matchedRequest,
    status: 'ACTIVATED',
    activated_at: activatedAt,
    activated_by_user_id: actor.id || null,
    activated_by_email: actor.email || null,
  };

  await prisma.subscription.update({
    where: { id: matchedSubscription.id },
    data: {
      plan_id: targetPlanId,
      pending_plan_id: null,
      status: 'ACTIVE',
      start_date: matchedSubscription.start_date || startDate,
      end_date: endDate,
      change_status: 'NONE',
      change_requested_at: null,
      change_effective_at: now,
      extension_json: extension,
    },
  });

  const planLabel =
    matchedRequest.plan_label ||
    matchedSubscription.pending_plan?.name ||
    matchedSubscription.plan?.name ||
    null;

  const notifyEmail =
    text(matchedRequest.invoice_email) ||
    text(matchedRequest.submitted_by_email) ||
    text(actor.email);

  await notifyTenantActivation({
    email: notifyEmail,
    tenantName: matchedSubscription.tenant?.name,
    planLabel,
    amount: matchedRequest.amount,
    currency: matchedRequest.currency,
    billingCycle,
    startDate,
    endDate,
  }).catch(() => {});

  await createAuditLog({
    tenant_id: matchedSubscription.tenant_id,
    user_id: actor.id || null,
    action: 'SUBSCRIPTION_PAYMENT_ACTIVATED',
    entity: 'subscription',
    entity_id: matchedSubscription.id,
    ip_address: ip,
    details: {
      request_id: requestIdentifier,
      plan_label: planLabel,
      amount: matchedRequest.amount,
      currency: matchedRequest.currency,
      billing_cycle: billingCycle,
      start_date: startDate.toISOString(),
      end_date: endDate.toISOString(),
    },
  }).catch(() => {});

  return {
    request_id: requestIdentifier,
    status: 'ACTIVATED',
    subscription_id: safePublicId(
      matchedSubscription.human_friendly_id,
      matchedSubscription.id
    ),
    tenant_id: safePublicId(
      matchedSubscription.tenant?.human_friendly_id,
      matchedSubscription.tenant_id
    ),
    plan_label: planLabel,
    start_date: startDate.toISOString(),
    end_date: endDate.toISOString(),
    amount: matchedRequest.amount,
    currency: matchedRequest.currency,
    billing_cycle: billingCycle,
    notified_email: notifyEmail || null,
  };
};

module.exports = {
  PAYMENT_METHODS,
  activatePaymentRequest,
  countPendingPaymentRequests,
  getUpgradeContext,
  listPendingPaymentRequests,
  submitPaymentRequest,
};
