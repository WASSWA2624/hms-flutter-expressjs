/**
 * Feedback routes
 */

const express = require('express');
const router = express.Router();
const feedbackController = require('@controllers/feedback/feedback.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { submitNpsSchema, submitCsatSchema } = require('@validations/feedback/feedback.schema');

router.post('/nps', validateRequest({ body: submitNpsSchema }), feedbackController.submitNpsFeedback);
router.post('/csat', validateRequest({ body: submitCsatSchema }), feedbackController.submitCsatFeedback);

module.exports = router;
