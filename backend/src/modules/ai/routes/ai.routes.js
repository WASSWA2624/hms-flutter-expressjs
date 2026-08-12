/**
 * AI utility routes
 */

const express = require('express');
const router = express.Router();
const aiController = require('@controllers/ai/ai.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  aiTaskKeyParamsSchema,
  aiTaskBodySchema,
} = require('@validations/ai/ai.schema');

router.get(
  '/status',
  authenticate(),
  authorize(PERMISSIONS.PROFILE_READ, 'permission'),
  aiController.getAiStatus
);

router.post(
  '/tasks/:task_key',
  validateRequest({
    params: aiTaskKeyParamsSchema,
    body: aiTaskBodySchema,
  }),
  authenticate(),
  authorize(PERMISSIONS.PROFILE_READ, 'permission'),
  aiController.runAiTask
);

module.exports = router;
