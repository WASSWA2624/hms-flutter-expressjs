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
const { PLAN_TIER_RANK } = require('@lib/subscriptions/plan-module-matrix');
const {
  syncSubscriptionModuleEntitlements,
} = require('@lib/subscriptions/sync-subscription-module-entitlements');
const {
  clearModuleEntitlementCaches,
} = require('@middlewares/module-entitlement.middleware');

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

const toNumber = (value) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const planRank = (plan) => {
  if (!plan) {
    return -1;
  }
  const tier = text(plan.tier_code).toUpperCase();
  if (Object.prototype.hasOwnProperty.call(PLAN_TIER_RANK, tier)) {
    return PLAN_TIER_RANK[tier];
  }
  return toNumber(plan.price);
};

/** @returns {number} positive = left higher, negative = left lower, 0 = equal */
const comparePlans = (left, right) => {
  const rankDelta = planRank(left) - planRank(right);
  if (rankDelta !== 0) {
    return rankDelta;
  }
  return toNumber(left?.price) - toNumber(right?.price);
};

const listPaymentRequests = (extension) => {
  const requests = Array.isArray(extension?.pending_payment_requests)
    ? extension.pending_payment_requests
    : [];
  return requests;
};

const listPendingPaymentEntries = (extension) =>
  listPaymentRequests(extension).filter(
    (entry) => text(entry?.status).toUpperCase() === 'PENDING'
  );

const isPeriodRunning = (subscription, now = new Date()) => {
  const status = text(subscription?.status).toUpperCase();
  if (!['ACTIVE', 'TRIAL'].includes(status)) {
    return false;
  }
  if (!subscription?.end_date) {
    return status === 'ACTIVE' || status === 'TRIAL';
  }
  const endDate = new Date(subscription.end_date);
  if (Number.isNaN(endDate.getTime())) {
    return true;
  }
  return endDate.getTime() > now.getTime();
};

const subscriptionHasPaidCommitment = (subscription) => {
  const extension = parseExtensionJson(subscription?.extension_json);
  const requests = listPaymentRequests(extension);
  const hasPaymentTrail = requests.some((entry) => {
    const status = text(entry?.status).toUpperCase();
    return status === 'PENDING' || status === 'ACTIVATED';
  });
  if (hasPaymentTrail) {
    return true;
  }
  const latest = extension.latest_payment_request;
  if (latest) {
    const status = text(latest.status).toUpperCase();
    if (status === 'PENDING' || status === 'ACTIVATED') {
      return true;
    }
  }
  const price = toNumber(subscription?.plan?.price);
  const status = text(subscription?.status).toUpperCase();
  return price > 0 && ['ACTIVE', 'TRIAL', 'PAST_DUE'].includes(status);
};

const serializePaymentRequest = (entry) => {
  if (!entry) {
    return null;
  }
  const status = text(entry.status).toUpperCase() || 'PENDING';
  const progress = (() => {
    switch (status) {
      case 'PENDING':
        return 'AWAITING_ADMIN_ACTIVATION';
      case 'ACTIVATED':
        return 'APPROVED';
      case 'REJECTED':
        return 'REJECTED';
      case 'CANCELLED_BY_USER':
        return 'CANCELLED';
      case 'SUPERSEDED':
        return 'SUPERSEDED';
      default:
        return status;
    }
  })();

  return {
    id: entry.id || null,
    status,
    payment_method: entry.payment_method || null,
    target_plan_id: entry.target_plan_id || null,
    plan_label: entry.plan_label || null,
    amount: entry.amount || null,
    currency: entry.currency || null,
    billing_cycle: entry.billing_cycle || null,
    reference: entry.reference || null,
    notes: entry.notes || null,
    submitted_at: entry.submitted_at || null,
    submitted_by_email: entry.submitted_by_email || null,
    rejection_reason: entry.rejection_reason || null,
    rejected_at: entry.rejected_at || null,
    rejected_by_email: entry.rejected_by_email || null,
    cancelled_at: entry.cancelled_at || null,
    activated_at: entry.activated_at || null,
    progress,
    can_cancel: status === 'PENDING',
  };
};

const serializePendingPaymentRequest = (entry) => serializePaymentRequest(entry);

const findSubscriptionForPaymentRequest = async (requestId) => {
  const requestIdentifier = text(requestId);
  if (!requestIdentifier) {
    return { subscription: null, request: null };
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

  for (const subscription of subscriptions) {
    const extension = parseExtensionJson(subscription.extension_json);
    const requests = listPaymentRequests(extension);
    const found = requests.find((entry) => text(entry?.id) === requestIdentifier);
    if (found) {
      return { subscription, request: found, extension, requests };
    }
  }

  return { subscription: null, request: null, extension: null, requests: [] };
};

const clearPendingPlanIfMatchingRequest = (subscription, request, updateData = {}) => {
  if (!subscription?.pending_plan_id || !request?.target_plan_id) {
    return updateData;
  }
  const pendingPublic = safePublicId(
    subscription.pending_plan?.human_friendly_id,
    subscription.pending_plan_id
  );
  const requestTarget = text(request.target_plan_id);
  if (
    pendingPublic === requestTarget ||
    text(subscription.pending_plan_id) === requestTarget
  ) {
    updateData.pending_plan_id = null;
    updateData.change_status = 'NONE';
    updateData.change_requested_at = null;
    updateData.change_effective_at = null;
  }
  return updateData;
};

const notifyTenantRejection = async ({
  email,
  tenantName,
  planLabel,
  reason,
}) => {
  if (!email) {
    return { sent: false, provider: 'skipped' };
  }

  const subject = `Subscription activation rejected — ${planLabel || 'Hosspi'}`;
  const lines = [
    `Hello${tenantName ? ` from ${tenantName}` : ''},`,
    '',
    'Your subscription activation request was rejected by a platform admin.',
    '',
    `Package: ${planLabel || 'Not specified'}`,
    `Reason: ${reason || 'Not specified'}`,
    '',
    'You may contact platform admins for more information, or submit a new request after cancelling is not needed (this request is already closed).',
    '',
    'Thank you for choosing Hosspi.',
  ];

  return sendEmail({
    to: email,
    subject,
    text: lines.join('\n'),
  });
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
  scheduled = false,
}) => {
  if (!email) {
    return { sent: false, provider: 'skipped' };
  }

  const period =
    text(billingCycle).toUpperCase().includes('YEAR') ||
    text(billingCycle).toUpperCase() === 'ANNUAL'
      ? 'Annual'
      : 'Monthly';
  const subject = scheduled
    ? `Subscription payment confirmed — starts ${formatDate(startDate)}`
    : `Subscription activated — ${planLabel || 'Hosspi'}`;
  const lines = [
    `Hello${tenantName ? ` from ${tenantName}` : ''},`,
    '',
    scheduled
      ? 'Your subscription payment was confirmed. The new package period starts after your current subscription ends.'
      : 'Your subscription payment was confirmed and your account is now active.',
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
 * Apply pending plan changes whose effective date has arrived.
 *
 * @param {string|null} [tenantId]
 * @returns {Promise<number>}
 */
const applyDueScheduledPlanChanges = async (tenantId = null) => {
  const now = new Date();
  const where = {
    deleted_at: null,
    pending_plan_id: { not: null },
    change_effective_at: { lte: now },
    change_status: { in: ['PENDING_UPGRADE', 'PENDING_DOWNGRADE'] },
    ...(tenantId ? { tenant_id: tenantId } : {}),
  };

  const due = await prisma.subscription.findMany({
    where,
    include: { plan: true, pending_plan: true },
    take: 100,
  });

  let applied = 0;
  for (const subscription of due) {
    try {
      const extension = parseExtensionJson(subscription.extension_json);
      extension.scheduled_plan_applied_at = now.toISOString();
      extension.scheduled_plan_previous_plan_id = subscription.plan_id;

      await prisma.subscription.update({
        where: { id: subscription.id },
        data: {
          plan_id: subscription.pending_plan_id,
          pending_plan_id: null,
          change_status: 'APPLIED',
          change_requested_at: null,
          change_effective_at: now,
          start_date: now,
          extension_json: extension,
        },
      });

      await syncSubscriptionModuleEntitlements(subscription.id).catch(() => {});
      applied += 1;
    } catch (_error) {
      // Continue applying remaining due changes.
    }
  }

  if (applied > 0) {
    clearModuleEntitlementCaches();
  }

  return applied;
};

/**
 * @param {Object} user
 * @returns {Promise<Object>}
 */
const getUpgradeContext = async (user = {}) => {
  const tenantId = resolveBillingTenantScope(user);
  await applyDueScheduledPlanChanges(tenantId).catch(() => 0);

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

  const extension = parseExtensionJson(overviewSubscription?.extension_json);
  const pendingEntry = listPendingPaymentEntries(extension)[0] || null;
  const latestEntry = extension.latest_payment_request || pendingEntry || null;
  const periodRunning = overviewSubscription
    ? isPeriodRunning(overviewSubscription)
    : false;
  const hasPaid = overviewSubscription
    ? subscriptionHasPaidCommitment(overviewSubscription)
    : false;
  const hasPendingActivation = Boolean(pendingEntry);

  const scheduledChange =
    overviewSubscription?.pending_plan_id &&
    overviewSubscription?.change_effective_at
      ? {
          pending_plan_id: safePublicId(
            overviewSubscription.pending_plan?.human_friendly_id,
            overviewSubscription.pending_plan_id
          ),
          pending_plan_label: overviewSubscription.pending_plan?.name || null,
          change_status: overviewSubscription.change_status || null,
          change_effective_at: overviewSubscription.change_effective_at || null,
          current_period_ends_at: overviewSubscription.end_date || null,
        }
      : null;

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
          period_running: periodRunning,
          has_paid_commitment: hasPaid,
          change_status: overviewSubscription.change_status || null,
        }
      : null,
    plans: serializedPlans,
    recommended_plan_id: recommendedPlan?.id || null,
    payment_methods: PAYMENT_METHODS,
    platform_admin_contact: resolvePlatformAdminContact(),
    bank_transfer_details: resolvePlatformBankTransferDetails(),
    mobile_money_details: resolvePlatformMobileMoneyDetails(),
    expiring_soon_days: Number(env.SUBSCRIPTION_EXPIRING_SOON_DAYS) || 14,
    pending_payment_request: serializePaymentRequest(pendingEntry),
    latest_payment_request: serializePaymentRequest(latestEntry),
    scheduled_plan_change: scheduledChange,
    policy: {
      can_submit_payment_request: !hasPendingActivation,
      can_change_plan: !hasPendingActivation,
      can_cancel_payment_request: hasPendingActivation,
      can_upgrade_over_pending: false,
      pending_target_plan_id: pendingEntry?.target_plan_id || null,
      pending_target_plan_rank: null,
      current_plan_rank: overviewSubscription?.plan
        ? planRank(overviewSubscription.plan)
        : null,
      can_cancel: !hasPaid,
      period_running: periodRunning,
      immediate_downgrade_allowed: !periodRunning,
      prepaid_starts_after_current: periodRunning,
    },
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
  await applyDueScheduledPlanChanges(tenantId).catch(() => 0);
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
  const now = new Date();
  const periodRunning = isPeriodRunning(subscription, now);
  const comparison = targetPlan
    ? comparePlans(targetPlan, subscription.plan)
    : 0;

  const extension = parseExtensionJson(subscription.extension_json);
  const pendingRequests = listPendingPaymentEntries(extension);
  if (pendingRequests.length > 0) {
    const existing = pendingRequests[0];
    throw new HttpError('errors.subscription.payment_request_already_pending', 409, [
      {
        field: 'payment_request',
        reason: 'duplicate_pending',
        request_id: existing.id || null,
        plan_label: existing.plan_label || null,
        submitted_at: existing.submitted_at || null,
      },
    ]);
  }

  const proofFile = Array.isArray(files) ? files[0] : null;
  const proof = await uploadProofFile(proofFile, tenantId);
  const requestId = crypto.randomUUID();
  const submittedAt = now.toISOString();
  const changeKind =
    comparison > 0 ? 'UPGRADE' : comparison < 0 ? 'DOWNGRADE' : 'RENEWAL';

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
    change_kind: changeKind,
    starts_after_current: periodRunning,
    current_period_ends_at: subscription.end_date || null,
    proof,
    submitted_at: submittedAt,
    submitted_by_user_id: user.id || null,
    submitted_by_email: user.email || null,
  };

  const retainedHistory = listPaymentRequests(extension).slice(0, 19);

  extension.pending_payment_requests = [paymentRequest, ...retainedHistory].slice(
    0,
    20
  );
  extension.latest_payment_request = paymentRequest;

  const updateData = {
    extension_json: extension,
  };

  if (targetPlan && targetPlan.id !== subscription.plan_id) {
    updateData.pending_plan_id = targetPlan.id;
    updateData.change_status =
      comparison >= 0 ? 'PENDING_UPGRADE' : 'PENDING_DOWNGRADE';
    updateData.change_requested_at = now;
    if (periodRunning && subscription.end_date) {
      updateData.change_effective_at = new Date(subscription.end_date);
    }
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
      billing_cycle: paymentRequest.billing_cycle,
      reference: paymentRequest.reference,
      change_kind: changeKind,
      starts_after_current: periodRunning,
      has_proof: Boolean(proof),
    },
  }).catch(() => {});

  return {
    request_id: requestId,
    status: 'PENDING',
    payment_method: paymentMethod,
    plan_label: paymentRequest.plan_label,
    change_kind: changeKind,
    starts_after_current: periodRunning,
    current_period_ends_at: subscription.end_date || null,
    progress: 'AWAITING_ADMIN_ACTIVATION',
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
  const currentEnd =
    matchedSubscription.end_date &&
    !Number.isNaN(new Date(matchedSubscription.end_date).getTime())
      ? new Date(matchedSubscription.end_date)
      : null;
  const periodStillRunning =
    isPeriodRunning(matchedSubscription, now) &&
    currentEnd &&
    currentEnd.getTime() > now.getTime();

  let targetPlanId = matchedSubscription.pending_plan_id || matchedSubscription.plan_id;
  let targetPlanRecord = matchedSubscription.pending_plan || matchedSubscription.plan;
  if (matchedRequest.target_plan_id) {
    const resolved = await resolvePlanRecord(
      matchedRequest.target_plan_id,
      matchedSubscription.tenant_id
    );
    if (resolved) {
      targetPlanId = resolved.id;
      targetPlanRecord = resolved;
    }
  }

  const comparison = comparePlans(targetPlanRecord, matchedSubscription.plan);
  const isSamePlan = targetPlanId === matchedSubscription.plan_id;

  const extension = parseExtensionJson(matchedSubscription.extension_json);
  const requests = listPaymentRequests(extension);
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
      starts_after_current: Boolean(periodStillRunning),
    };
  });
  extension.latest_payment_request = {
    ...matchedRequest,
    status: 'ACTIVATED',
    activated_at: activatedAt,
    activated_by_user_id: actor.id || null,
    activated_by_email: actor.email || null,
    starts_after_current: Boolean(periodStillRunning),
  };

  let startDate;
  let endDate;
  let updateData;
  let scheduled = false;

  if (periodStillRunning) {
    // Prepaid: keep current plan until current end; new period starts then.
    startDate = currentEnd;
    endDate = addBillingCycle(currentEnd, billingCycle);
    scheduled = !isSamePlan;
    updateData = {
      status: 'ACTIVE',
      end_date: endDate,
      extension_json: extension,
    };

    if (isSamePlan) {
      updateData.pending_plan_id = null;
      updateData.change_status = 'NONE';
      updateData.change_requested_at = null;
      updateData.change_effective_at = null;
    } else {
      updateData.pending_plan_id = targetPlanId;
      updateData.change_status =
        comparison >= 0 ? 'PENDING_UPGRADE' : 'PENDING_DOWNGRADE';
      updateData.change_requested_at = now;
      updateData.change_effective_at = currentEnd;
    }
  } else {
    startDate = now;
    const baseDate =
      currentEnd && currentEnd.getTime() > now.getTime() ? currentEnd : now;
    endDate = addBillingCycle(baseDate, billingCycle);
    updateData = {
      plan_id: targetPlanId,
      pending_plan_id: null,
      status: 'ACTIVE',
      start_date: matchedSubscription.start_date || startDate,
      end_date: endDate,
      change_status: 'NONE',
      change_requested_at: null,
      change_effective_at: now,
      extension_json: extension,
    };
  }

  await prisma.subscription.update({
    where: { id: matchedSubscription.id },
    data: updateData,
  });

  if (!scheduled && !isSamePlan && !periodStillRunning) {
    await syncSubscriptionModuleEntitlements(matchedSubscription.id).catch(() => {});
    clearModuleEntitlementCaches();
  }

  const planLabel =
    matchedRequest.plan_label ||
    targetPlanRecord?.name ||
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
    scheduled,
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
      scheduled,
      change_kind:
        comparison > 0 ? 'UPGRADE' : comparison < 0 ? 'DOWNGRADE' : 'RENEWAL',
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
    scheduled,
    change_effective_at: scheduled ? startDate.toISOString() : now.toISOString(),
    notified_email: notifyEmail || null,
  };
};

/**
 * Reject a pending subscription payment request (platform admin).
 *
 * @param {string} requestId
 * @param {{ reason?: string }} payload
 * @param {Object} actor
 * @param {string|null} ip
 * @returns {Promise<Object>}
 */
const rejectPaymentRequest = async (
  requestId,
  payload = {},
  actor = {},
  ip = null
) => {
  const reason = text(payload.reason);
  if (!reason) {
    throw new HttpError('errors.validation.field.required', 400, [
      { field: 'reason' },
    ]);
  }

  const matched = await findSubscriptionForPaymentRequest(requestId);
  const matchedSubscription = matched.subscription;
  const matchedRequest = matched.request;
  if (!matchedSubscription || !matchedRequest) {
    throw new HttpError('errors.subscription.payment_request_not_found', 404);
  }

  const status = text(matchedRequest.status).toUpperCase();
  if (status === 'ACTIVATED') {
    throw new HttpError('errors.subscription.payment_request_already_approved', 400);
  }
  if (status !== 'PENDING') {
    throw new HttpError('errors.subscription.payment_request_not_pending', 400);
  }

  const now = new Date();
  const rejectedAt = now.toISOString();
  const extension = parseExtensionJson(matchedSubscription.extension_json);
  const requests = listPaymentRequests(extension);
  const updatedRequest = {
    ...matchedRequest,
    status: 'REJECTED',
    rejection_reason: reason,
    rejected_at: rejectedAt,
    rejected_by_user_id: actor.id || null,
    rejected_by_email: actor.email || null,
  };

  extension.pending_payment_requests = requests.map((entry) =>
    text(entry?.id) === text(matchedRequest.id) ? updatedRequest : entry
  );
  extension.latest_payment_request = updatedRequest;

  const updateData = clearPendingPlanIfMatchingRequest(
    matchedSubscription,
    matchedRequest,
    { extension_json: extension }
  );

  await prisma.subscription.update({
    where: { id: matchedSubscription.id },
    data: updateData,
  });

  const notifyEmail =
    text(matchedRequest.invoice_email) ||
    text(matchedRequest.submitted_by_email) ||
    null;

  await notifyTenantRejection({
    email: notifyEmail,
    tenantName: matchedSubscription.tenant?.name,
    planLabel: matchedRequest.plan_label,
    reason,
  }).catch(() => {});

  await createAuditLog({
    tenant_id: matchedSubscription.tenant_id,
    user_id: actor.id || null,
    action: 'SUBSCRIPTION_PAYMENT_REJECTED',
    entity: 'subscription',
    entity_id: matchedSubscription.id,
    ip_address: ip,
    details: {
      request_id: matchedRequest.id,
      reason,
      plan_label: matchedRequest.plan_label || null,
    },
  }).catch(() => {});

  return {
    request_id: matchedRequest.id,
    status: 'REJECTED',
    rejection_reason: reason,
    plan_label: matchedRequest.plan_label || null,
    notified_email: notifyEmail,
  };
};

/**
 * Cancel a pending activation request (tenant user).
 * Approved activations cannot be cancelled.
 *
 * @param {string|null} requestId
 * @param {Object} user
 * @param {string|null} ip
 * @returns {Promise<Object>}
 */
const cancelPaymentRequest = async (requestId = null, user = {}, ip = null) => {
  const tenantId = resolveBillingTenantScope(user);
  const subscription = await loadCurrentSubscription(tenantId);
  const extension = parseExtensionJson(subscription.extension_json);
  const requests = listPaymentRequests(extension);
  const pending = listPendingPaymentEntries(extension);

  let matchedRequest = null;
  if (text(requestId)) {
    matchedRequest = requests.find((entry) => text(entry?.id) === text(requestId));
    if (!matchedRequest) {
      throw new HttpError('errors.subscription.payment_request_not_found', 404);
    }
    const status = text(matchedRequest.status).toUpperCase();
    if (status === 'ACTIVATED') {
      throw new HttpError(
        'errors.subscription.payment_request_already_approved',
        400
      );
    }
    if (status !== 'PENDING') {
      throw new HttpError('errors.subscription.payment_request_not_pending', 400);
    }
  } else {
    matchedRequest = pending[0] || null;
    if (!matchedRequest) {
      throw new HttpError('errors.subscription.payment_request_not_found', 404);
    }
  }

  const cancelledAt = new Date().toISOString();
  const updatedRequest = {
    ...matchedRequest,
    status: 'CANCELLED_BY_USER',
    cancelled_at: cancelledAt,
    cancelled_by_user_id: user.id || null,
    cancelled_by_email: user.email || null,
  };

  extension.pending_payment_requests = requests.map((entry) =>
    text(entry?.id) === text(matchedRequest.id) ? updatedRequest : entry
  );
  extension.latest_payment_request = updatedRequest;

  const updateData = clearPendingPlanIfMatchingRequest(subscription, matchedRequest, {
    extension_json: extension,
  });

  await prisma.subscription.update({
    where: { id: subscription.id },
    data: updateData,
  });

  await createAuditLog({
    tenant_id: tenantId,
    user_id: user.id || null,
    action: 'SUBSCRIPTION_PAYMENT_CANCELLED',
    entity: 'subscription',
    entity_id: subscription.id,
    ip_address: ip,
    details: {
      request_id: matchedRequest.id,
      plan_label: matchedRequest.plan_label || null,
    },
  }).catch(() => {});

  return {
    request_id: matchedRequest.id,
    status: 'CANCELLED_BY_USER',
    plan_label: matchedRequest.plan_label || null,
    progress: 'CANCELLED',
  };
};

module.exports = {
  PAYMENT_METHODS,
  activatePaymentRequest,
  applyDueScheduledPlanChanges,
  cancelPaymentRequest,
  comparePlans,
  countPendingPaymentRequests,
  getUpgradeContext,
  isPeriodRunning,
  listPendingPaymentRequests,
  planRank,
  rejectPaymentRequest,
  submitPaymentRequest,
  subscriptionHasPaidCommitment,
};
