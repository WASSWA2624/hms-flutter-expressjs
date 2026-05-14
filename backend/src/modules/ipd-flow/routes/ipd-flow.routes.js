/**
 * IPD flow routes
 */

const express = require('express');
const router = express.Router();
const ipdFlowController = require('@controllers/ipd-flow/ipd-flow.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  listIpdFlowsQuerySchema,
  getIpdFlowQuerySchema,
  resolveLegacyRouteParamsSchema,
  admissionIdParamsSchema,
  startIpdFlowSchema,
  assignBedSchema,
  releaseBedSchema,
  rejectAdmissionSchema,
  requestTransferSchema,
  updateTransferSchema,
  addWardRoundSchema,
  addNursingNoteSchema,
  addMedicationAdministrationSchema,
  planDischargeSchema,
  finalizeDischargeSchema,
  startIcuStaySchema,
  endIcuStaySchema,
  addIcuObservationSchema,
  addCriticalAlertSchema,
  resolveCriticalAlertSchema,
} = require('@validations/ipd-flow/ipd-flow.schema');

const IPD_READ_SCOPES = [PERMISSIONS.CLINICAL_READ];
const IPD_WRITE_SCOPES = [PERMISSIONS.CLINICAL_WRITE];

router.get(
  '/',
  validateRequest({ query: listIpdFlowsQuerySchema }),
  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  ipdFlowController.listIpdFlows
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyRouteParamsSchema }),
  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  ipdFlowController.resolveLegacyRoute
);

router.get(
  '/:id',
  validateRequest({ params: admissionIdParamsSchema, query: getIpdFlowQuerySchema }),
  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  ipdFlowController.getIpdFlowById
);

router.post(
  '/start',
  validateRequest({ body: startIpdFlowSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.startIpdFlow
);

router.post(
  '/:id/assign-bed',
  validateRequest({ params: admissionIdParamsSchema, body: assignBedSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.assignBed
);

router.post(
  '/:id/release-bed',
  validateRequest({ params: admissionIdParamsSchema, body: releaseBedSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.releaseBed
);


router.post(
  '/:id/reject-admission',
  validateRequest({ params: admissionIdParamsSchema, body: rejectAdmissionSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.rejectAdmissionRequest
);

router.post(
  '/:id/request-transfer',
  validateRequest({ params: admissionIdParamsSchema, body: requestTransferSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.requestTransfer
);

router.post(
  '/:id/update-transfer',
  validateRequest({ params: admissionIdParamsSchema, body: updateTransferSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.updateTransfer
);

router.post(
  '/:id/add-ward-round',
  validateRequest({ params: admissionIdParamsSchema, body: addWardRoundSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.addWardRound
);

router.post(
  '/:id/add-nursing-note',
  validateRequest({ params: admissionIdParamsSchema, body: addNursingNoteSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.addNursingNote
);

router.post(
  '/:id/add-medication-administration',
  validateRequest({ params: admissionIdParamsSchema, body: addMedicationAdministrationSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.addMedicationAdministration
);

router.post(
  '/:id/plan-discharge',
  validateRequest({ params: admissionIdParamsSchema, body: planDischargeSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.planDischarge
);

router.post(
  '/:id/finalize-discharge',
  validateRequest({ params: admissionIdParamsSchema, body: finalizeDischargeSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.finalizeDischarge
);

router.post(
  '/:id/start-icu-stay',
  validateRequest({ params: admissionIdParamsSchema, body: startIcuStaySchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.startIcuStay
);

router.post(
  '/:id/end-icu-stay',
  validateRequest({ params: admissionIdParamsSchema, body: endIcuStaySchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.endIcuStay
);

router.post(
  '/:id/add-icu-observation',
  validateRequest({ params: admissionIdParamsSchema, body: addIcuObservationSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.addIcuObservation
);

router.post(
  '/:id/add-critical-alert',
  validateRequest({ params: admissionIdParamsSchema, body: addCriticalAlertSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.addCriticalAlert
);

router.post(
  '/:id/resolve-critical-alert',
  validateRequest({ params: admissionIdParamsSchema, body: resolveCriticalAlertSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  ipdFlowController.resolveCriticalAlert
);

module.exports = router;
