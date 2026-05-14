/**
 * Feedback controller
 */

const feedbackService = require('@services/feedback/feedback.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');

const submitNpsFeedback = asyncHandler(async (req, res) => {
  const result = await feedbackService.submitNpsFeedback(req.body, {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  });

  sendSuccess(res, 201, 'messages.feedback.nps.success', result);
});

const submitCsatFeedback = asyncHandler(async (req, res) => {
  const result = await feedbackService.submitCsatFeedback(req.body, {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  });

  sendSuccess(res, 201, 'messages.feedback.csat.success', result);
});

module.exports = {
  submitNpsFeedback,
  submitCsatFeedback
};
