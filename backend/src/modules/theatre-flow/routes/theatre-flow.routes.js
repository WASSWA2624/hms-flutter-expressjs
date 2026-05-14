/**
 * Theatre flow routes
 */

const express = require('express');
const router = express.Router();
const theatreFlowController = require('@controllers/theatre-flow/theatre-flow.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  listTheatreFlowsQuerySchema,
  getTheatreFlowQuerySchema,
  theatreCaseIdParamsSchema,
  resolveLegacyRouteParamsSchema,
  startTheatreFlowSchema,
  updateStageSchema,
  upsertAnesthesiaRecordSchema,
  addAnesthesiaObservationSchema,
  upsertPostOpNoteSchema,
  toggleChecklistItemSchema,
  assignResourceSchema,
  releaseResourceSchema,
  finalizeRecordSchema,
  reopenRecordSchema,
} = require('@validations/theatre-flow/theatre-flow.schema');

const THEATRE_ALLOWED_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
];

router.get(
  '/',
  validateRequest({ query: listTheatreFlowsQuerySchema }),
  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreFlowController.listTheatreFlows
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyRouteParamsSchema }),
  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreFlowController.resolveLegacyRoute
);

router.get(
  '/:id',
  validateRequest({
    params: theatreCaseIdParamsSchema,
    query: getTheatreFlowQuerySchema,
  }),
  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreFlowController.getTheatreFlowById
);

router.post(
  '/start',
  validateRequest({ body: startTheatreFlowSchema }),
  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreFlowController.startTheatreFlow
);

router.post(
  '/:id/update-stage',
  validateRequest({
    params: theatreCaseIdParamsSchema,
    body: updateStageSchema,
  }),
  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreFlowController.updateStage
);

router.post(
  '/:id/upsert-anesthesia-record',
  validateRequest({
    params: theatreCaseIdParamsSchema,
    body: upsertAnesthesiaRecordSchema,
  }),
  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreFlowController.upsertAnesthesiaRecord
);

router.post(
  '/:id/add-anesthesia-observation',
  validateRequest({
    params: theatreCaseIdParamsSchema,
    body: addAnesthesiaObservationSchema,
  }),
  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreFlowController.addAnesthesiaObservation
);

router.post(
  '/:id/upsert-post-op-note',
  validateRequest({
    params: theatreCaseIdParamsSchema,
    body: upsertPostOpNoteSchema,
  }),
  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreFlowController.upsertPostOpNote
);

router.post(
  '/:id/toggle-checklist-item',
  validateRequest({
    params: theatreCaseIdParamsSchema,
    body: toggleChecklistItemSchema,
  }),
  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreFlowController.toggleChecklistItem
);

router.post(
  '/:id/assign-resource',
  validateRequest({
    params: theatreCaseIdParamsSchema,
    body: assignResourceSchema,
  }),
  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreFlowController.assignResource
);

router.post(
  '/:id/release-resource',
  validateRequest({
    params: theatreCaseIdParamsSchema,
    body: releaseResourceSchema,
  }),
  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreFlowController.releaseResource
);

router.post(
  '/:id/finalize-record',
  validateRequest({
    params: theatreCaseIdParamsSchema,
    body: finalizeRecordSchema,
  }),
  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreFlowController.finalizeRecord
);

router.post(
  '/:id/reopen-record',
  validateRequest({
    params: theatreCaseIdParamsSchema,
    body: reopenRecordSchema,
  }),
  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreFlowController.reopenRecord
);

module.exports = router;

