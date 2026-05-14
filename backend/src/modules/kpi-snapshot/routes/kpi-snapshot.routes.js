const express = require('express');
const kpiSnapshotController = require('@controllers/kpi-snapshot/kpi-snapshot.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  createKpiSnapshotSchema,
  kpiSnapshotIdParamsSchema,
  listKpiSnapshotsQuerySchema,
  updateKpiSnapshotSchema,
} = require('@validations/kpi-snapshot/kpi-snapshot.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listKpiSnapshotsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  kpiSnapshotController.listKpiSnapshots
);

router.get(
  '/:id',
  validateRequest({ params: kpiSnapshotIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  kpiSnapshotController.getKpiSnapshotById
);

router.post(
  '/',
  validateRequest({ body: createKpiSnapshotSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  kpiSnapshotController.createKpiSnapshot
);

router.put(
  '/:id',
  validateRequest({ params: kpiSnapshotIdParamsSchema, body: updateKpiSnapshotSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  kpiSnapshotController.updateKpiSnapshot
);

router.delete(
  '/:id',
  validateRequest({ params: kpiSnapshotIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_DELETE, 'permission'),
  kpiSnapshotController.deleteKpiSnapshot
);

module.exports = router;
