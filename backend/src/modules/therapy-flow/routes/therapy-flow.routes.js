/**
 * Therapy flow routes
 */

const express = require('express');
const router = express.Router();
const therapyFlowController = require('@controllers/therapy-flow/therapy-flow.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  listTherapyFlowsQuerySchema,
  getTherapyFlowQuerySchema,
  therapyEpisodeIdParamsSchema,
  createTherapyReferralSchema,
  acceptReferralSchema,
  recordAssessmentSchema,
  scheduleSessionSchema,
  recordSessionSchema,
  markAttendanceSchema,
  updatePlanSchema,
  addProgressNoteSchema,
  scheduleFollowUpSchema,
  closeEpisodeSchema,
} = require('@validations/therapy-flow/therapy-flow.schema');

const THERAPY_READ_SCOPES = [PERMISSIONS.CLINICAL_READ, PERMISSIONS.PATIENT_READ];
const THERAPY_WRITE_SCOPES = [PERMISSIONS.CLINICAL_WRITE, PERMISSIONS.PATIENT_WRITE];

router.get(
  '/',
  validateRequest({ query: listTherapyFlowsQuerySchema }),
  authenticate(),
  authorize(THERAPY_READ_SCOPES, 'permission'),
  therapyFlowController.listTherapyFlows
);

router.post(
  '/referrals',
  validateRequest({ body: createTherapyReferralSchema }),
  authenticate(),
  authorize(THERAPY_WRITE_SCOPES, 'permission'),
  therapyFlowController.createTherapyReferral
);

router.get(
  '/:id',
  validateRequest({
    params: therapyEpisodeIdParamsSchema,
    query: getTherapyFlowQuerySchema,
  }),
  authenticate(),
  authorize(THERAPY_READ_SCOPES, 'permission'),
  therapyFlowController.getTherapyFlowById
);

router.post(
  '/:id/accept-referral',
  validateRequest({ params: therapyEpisodeIdParamsSchema, body: acceptReferralSchema }),
  authenticate(),
  authorize(THERAPY_WRITE_SCOPES, 'permission'),
  therapyFlowController.acceptReferral
);

router.post(
  '/:id/record-assessment',
  validateRequest({ params: therapyEpisodeIdParamsSchema, body: recordAssessmentSchema }),
  authenticate(),
  authorize(THERAPY_WRITE_SCOPES, 'permission'),
  therapyFlowController.recordAssessment
);

router.post(
  '/:id/schedule-session',
  validateRequest({ params: therapyEpisodeIdParamsSchema, body: scheduleSessionSchema }),
  authenticate(),
  authorize(THERAPY_WRITE_SCOPES, 'permission'),
  therapyFlowController.scheduleSession
);

router.post(
  '/:id/record-session',
  validateRequest({ params: therapyEpisodeIdParamsSchema, body: recordSessionSchema }),
  authenticate(),
  authorize(THERAPY_WRITE_SCOPES, 'permission'),
  therapyFlowController.recordSession
);

router.post(
  '/:id/mark-attendance',
  validateRequest({ params: therapyEpisodeIdParamsSchema, body: markAttendanceSchema }),
  authenticate(),
  authorize(THERAPY_WRITE_SCOPES, 'permission'),
  therapyFlowController.markAttendance
);

router.post(
  '/:id/update-plan',
  validateRequest({ params: therapyEpisodeIdParamsSchema, body: updatePlanSchema }),
  authenticate(),
  authorize(THERAPY_WRITE_SCOPES, 'permission'),
  therapyFlowController.updatePlan
);

router.post(
  '/:id/add-progress-note',
  validateRequest({ params: therapyEpisodeIdParamsSchema, body: addProgressNoteSchema }),
  authenticate(),
  authorize(THERAPY_WRITE_SCOPES, 'permission'),
  therapyFlowController.addProgressNote
);

router.post(
  '/:id/schedule-follow-up',
  validateRequest({ params: therapyEpisodeIdParamsSchema, body: scheduleFollowUpSchema }),
  authenticate(),
  authorize(THERAPY_WRITE_SCOPES, 'permission'),
  therapyFlowController.scheduleFollowUp
);

router.post(
  '/:id/close-episode',
  validateRequest({ params: therapyEpisodeIdParamsSchema, body: closeEpisodeSchema }),
  authenticate(),
  authorize(THERAPY_WRITE_SCOPES, 'permission'),
  therapyFlowController.closeEpisode
);

module.exports = router;
