/**
 * Shared billing workspace realtime publishers.
 *
 * Used by Billing mutations and by clinical flows (e.g. Start OPD) that create
 * or cancel payable invoices outside billing.service so queues stay aligned.
 */

const { logger } = require('@lib/logging');
const { findRealtimeRecipientUserIds } = require('@lib/realtime/recipients');
const { resolvePublicIdentifier } = require('@lib/billing/identifiers');
const { publishDomainEvent, BILLING_EVENTS } = require('@lib/websocket');
const { ROLES } = require('@config/roles');

const BILLING_REALTIME_RECIPIENT_ROLES = Object.freeze([
  ROLES.BILLING,
  ROLES.FACILITY_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.RECEPTIONIST,
  ROLES.ACCOUNTANT,
]);

const clean = (value) => String(value || '').trim();
const compactId = (value) => clean(value) || null;
const displayId = (record = {}) =>
  resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id);

/**
 * Publish one billing domain event to Billing/Reception/Admin recipients.
 *
 * @param {Object} params
 * @param {string} params.event
 * @param {string} [params.action]
 * @param {Object|null} [params.invoice]
 * @param {Object|null} [params.payment]
 * @param {Object|null} [params.refund]
 * @param {Object|null} [params.approval]
 * @param {string|null} [params.actorUserId]
 * @returns {Promise<void>}
 */
const publishBillingRealtimeUpdate = async ({
  event,
  action,
  invoice = null,
  payment = null,
  refund = null,
  approval = null,
  actorUserId = null,
}) => {
  try {
    const invoiceRecord = invoice || payment?.invoice || refund?.payment?.invoice || null;
    const paymentRecord = payment || refund?.payment || null;
    const tenantId = compactId(
      invoiceRecord?.tenant_id || paymentRecord?.tenant_id || approval?.tenant_id
    );
    if (!tenantId) return;

    const facilityId = compactId(
      invoiceRecord?.facility_id || paymentRecord?.facility_id || approval?.facility_id
    );
    const invoiceId = compactId(
      invoiceRecord?.id || paymentRecord?.invoice_id || approval?.payload_json?.invoice_id
    );
    const paymentId = compactId(paymentRecord?.id || approval?.payload_json?.payment_id);
    const patientId = compactId(invoiceRecord?.patient_id || paymentRecord?.patient_id);
    const encounterId = compactId(invoiceRecord?.encounter_id || paymentRecord?.encounter_id);
    const recipientUserIds = await findRealtimeRecipientUserIds({
      tenantId,
      facilityId,
      roles: BILLING_REALTIME_RECIPIENT_ROLES,
    });

    const invoiceDisplayId = invoiceRecord
      ? displayId(invoiceRecord)
      : compactId(approval?.payload_json?.invoice_display_id);
    const paymentDisplayId = paymentRecord
      ? displayId(paymentRecord)
      : compactId(approval?.payload_json?.payment_display_id);
    const patientRecord = invoiceRecord?.patient || paymentRecord?.patient || null;
    const targetIdentifier = invoiceDisplayId || invoiceRecord?.id;
    const occurredAt = new Date().toISOString();
    const resourceType = paymentRecord || String(event || '').startsWith('payment.')
      ? 'payment'
      : 'invoice';
    const resourceId = resourceType === 'payment' ? paymentId : invoiceId;

    publishDomainEvent({
      event,
      tenant_id: tenantId,
      facility_id: facilityId,
      actor_user_id: actorUserId,
      resource_type: resourceType,
      resource_id: resourceId,
      recipient_user_ids: recipientUserIds,
      affected: {
        invoice_id: invoiceId,
        payment_id: paymentId,
        refund_id: compactId(refund?.id),
        approval_id: compactId(approval?.id),
        patient_id: patientId,
        encounter_id: encounterId,
      },
      payload: {
        action: clean(action).toUpperCase() || 'UPDATED',
        invoice_id: invoiceId,
        invoice_public_id: invoiceDisplayId,
        payment_id: paymentId,
        payment_public_id: paymentDisplayId,
        refund_id: compactId(refund?.id),
        approval_id: compactId(approval?.id),
        patient_id: patientId,
        patient_public_id: patientRecord ? displayId(patientRecord) : null,
        encounter_id: encounterId,
        amount: paymentRecord?.amount ?? invoiceRecord?.total_amount ?? null,
        status: compactId(
          invoiceRecord?.billing_status ||
            invoiceRecord?.status ||
            paymentRecord?.status ||
            approval?.status
        ),
        method: paymentRecord?.method || null,
        actor_user_id: actorUserId || null,
        target_path: targetIdentifier
          ? `/billing?id=${encodeURIComponent(targetIdentifier)}`
          : '/billing',
        occurred_at: occurredAt,
      },
    });
  } catch (error) {
    logger.error('Failed to publish billing realtime event', {
      event,
      invoiceId: invoice?.id || payment?.invoice_id || approval?.payload_json?.invoice_id,
      paymentId: payment?.id || approval?.payload_json?.payment_id,
      error: error.message,
    });
  }
};

/**
 * Notify Billing that a consultation (or other clinical) invoice was issued.
 *
 * @param {Object} params
 * @param {Object} params.invoice
 * @param {string|null} [params.actorUserId]
 * @param {string} [params.action]
 * @returns {Promise<void>}
 */
const publishIssuedInvoiceBillingEvents = async ({
  invoice,
  actorUserId = null,
  action = 'ISSUED',
} = {}) => {
  if (!invoice?.id) return;
  await publishBillingRealtimeUpdate({
    event: BILLING_EVENTS.BILLING_INVOICE_ISSUED,
    action,
    invoice,
    actorUserId,
  });
  await publishBillingRealtimeUpdate({
    event: BILLING_EVENTS.INVOICE_UPDATED,
    action,
    invoice,
    actorUserId,
  });
  await publishBillingRealtimeUpdate({
    event: BILLING_EVENTS.BILLING_BALANCE_UPDATED,
    action: 'BALANCE_UPDATED',
    invoice,
    actorUserId,
  });
};

/**
 * Notify Billing that an invoice was cancelled, voided, or otherwise updated.
 *
 * @param {Object} params
 * @param {Object} params.invoice
 * @param {string|null} [params.actorUserId]
 * @param {string} [params.action]
 * @returns {Promise<void>}
 */
const publishUpdatedInvoiceBillingEvents = async ({
  invoice,
  actorUserId = null,
  action = 'UPDATED',
} = {}) => {
  if (!invoice?.id) return;
  await publishBillingRealtimeUpdate({
    event: BILLING_EVENTS.INVOICE_UPDATED,
    action,
    invoice,
    actorUserId,
  });
  await publishBillingRealtimeUpdate({
    event: BILLING_EVENTS.BILLING_BALANCE_UPDATED,
    action: 'BALANCE_UPDATED',
    invoice,
    actorUserId,
  });
};

module.exports = {
  BILLING_REALTIME_RECIPIENT_ROLES,
  publishBillingRealtimeUpdate,
  publishIssuedInvoiceBillingEvents,
  publishUpdatedInvoiceBillingEvents,
};
