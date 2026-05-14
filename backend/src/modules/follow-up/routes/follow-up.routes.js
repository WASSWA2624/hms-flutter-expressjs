/**
 * Follow-up routes
 */

const express = require('express');
const router = express.Router();
const followUpController = require('@controllers/follow-up/follow-up.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { requireClinicalDeletePrivilege } = require('@middlewares/clinical-guard.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createFollowUpSchema,
  updateFollowUpSchema,
  transitionFollowUpSchema,
  followUpIdParamsSchema,
  listFollowUpsQuerySchema,
} = require('@validations/follow-up/follow-up.schema');

router.get(
  '/',
  validateRequest({ query: listFollowUpsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  followUpController.listFollowUps
);

router.get(
  '/:id',
  validateRequest({ params: followUpIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  followUpController.getFollowUpById
);

router.post(
  '/',
  validateRequest({ body: createFollowUpSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  followUpController.createFollowUp
);

router.put(
  '/:id',
  validateRequest({ params: followUpIdParamsSchema, body: updateFollowUpSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  followUpController.updateFollowUp
);

router.delete(
  '/:id',
  validateRequest({ params: followUpIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  requireClinicalDeletePrivilege(),
  followUpController.deleteFollowUp
);

router.post(
  '/:id/complete',
  validateRequest({ params: followUpIdParamsSchema, body: transitionFollowUpSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  followUpController.completeFollowUp
);

router.post(
  '/:id/cancel',
  validateRequest({ params: followUpIdParamsSchema, body: transitionFollowUpSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  followUpController.cancelFollowUp
);

router.post(
  '/reminders/dispatch',
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  followUpController.dispatchFollowUpReminders
);

router.get(
  '/reminders/due-summary',
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  followUpController.getFollowUpReminderDueSummary
);

module.exports = router;

