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

const resolveTenantScope = async (user = {}) => {
  const tenantId = text(user.tenant_id);
  if (!tenantId) {
    throw new HttpError('errors.tenant.required', 400);
  }
  return tenantId;
};

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
    'Review and activate the subscription in the platform admin workspace.',
  ];

  return sendEmail({
    to: adminEmail,
    subject,
    text: lines.join('\n'),
  });
};

/**
 * @param {Object} user
 * @returns {Promise<Object>}
 */
const getUpgradeContext = async (user = {}) => {
  const tenantId = await resolveTenantScope(user);
  const [overviewSubscription, plans, summary] = await Promise.all([
    loadCurrentSubscription(tenantId).catch(() => null),
    loadUpgradePlans(tenantId),
    resolveTenantSubscriptionSummary(tenantId),
  ]);

  const currentPlanId = overviewSubscription?.plan_id || null;
  const serializedPlans = plans.map(serializeSubscriptionPlan);
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
  const tenantId = await resolveTenantScope(user);
  const subscription = await loadCurrentSubscription(tenantId);
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
 * List pending payment requests for platform super admins.
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

module.exports = {
  PAYMENT_METHODS,
  getUpgradeContext,
  listPendingPaymentRequests,
  submitPaymentRequest,
};
