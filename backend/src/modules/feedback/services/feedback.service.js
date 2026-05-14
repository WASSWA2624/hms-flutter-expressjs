/**
 * Feedback service
 */

const feedbackRepository = require('@repositories/feedback/feedback.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

const ensureTenant = (context) => {
  if (!context.tenant_id) {
    throw new HttpError('errors.auth.forbidden', 403);
  }
};

const submitNpsFeedback = async (data, context = {}) => {
  ensureTenant(context);

  const event = await feedbackRepository.createFeedbackEvent(
    context.tenant_id,
    context.user_id,
    'feedback.nps',
    {
      score: data.score,
      comment: data.comment || null,
      campaign_id: data.campaign_id || null
    }
  );

  await createAuditLog({
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    action: 'FEEDBACK_NPS',
    entity: 'feedback',
    entity_id: event.id,
    diff: {
      after: event
    },
    ip_address: context.ip_address
  }).catch(() => {});

  return {
    feedback_id: event.id,
    score: data.score,
    submitted_at: event.occurred_at
  };
};

const submitCsatFeedback = async (data, context = {}) => {
  ensureTenant(context);

  const event = await feedbackRepository.createFeedbackEvent(
    context.tenant_id,
    context.user_id,
    'feedback.csat',
    {
      rating: data.rating,
      comment: data.comment || null,
      campaign_id: data.campaign_id || null
    }
  );

  await createAuditLog({
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    action: 'FEEDBACK_CSAT',
    entity: 'feedback',
    entity_id: event.id,
    diff: {
      after: event
    },
    ip_address: context.ip_address
  }).catch(() => {});

  return {
    feedback_id: event.id,
    rating: data.rating,
    submitted_at: event.occurred_at
  };
};

module.exports = {
  submitNpsFeedback,
  submitCsatFeedback
};
