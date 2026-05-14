const express = require('express');
const custodySnapshotController = require('@controllers/custody-snapshot/custody-snapshot.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  createCustodySnapshotSchema,
  custodySnapshotIdParamsSchema,
  finalizeCustodySnapshotSchema,
  listCustodySnapshotsQuerySchema,
  updateCustodySnapshotSchema,
} = require('@validations/custody-snapshot/custody-snapshot.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listCustodySnapshotsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_READ, 'permission'),
  custodySnapshotController.listCustodySnapshots
);

router.get(
  '/:id',
  validateRequest({ params: custodySnapshotIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_READ, 'permission'),
  custodySnapshotController.getCustodySnapshotById
);

router.post(
  '/',
  validateRequest({ body: createCustodySnapshotSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_WRITE, 'permission'),
  custodySnapshotController.createCustodySnapshot
);

router.put(
  '/:id',
  validateRequest({ params: custodySnapshotIdParamsSchema, body: updateCustodySnapshotSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_WRITE, 'permission'),
  custodySnapshotController.updateCustodySnapshot
);

router.post(
  '/:id/finalize',
  validateRequest({ params: custodySnapshotIdParamsSchema, body: finalizeCustodySnapshotSchema }),
  authenticate(),
  authorize(PERMISSIONS.LAST_OFFICE_WRITE, 'permission'),
  custodySnapshotController.finalizeCustodySnapshot
);

module.exports = router;
