const express = require('express');
const closeoutPackController = require('@controllers/closeout-pack/closeout-pack.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  closeoutPackIdParamsSchema,
  createCloseoutPackSchema,
  listCloseoutPacksQuerySchema,
} = require('@validations/closeout-pack/closeout-pack.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listCloseoutPacksQuerySchema }),
  authenticate(),
  authorize([PERMISSIONS.LAST_OFFICE_READ, PERMISSIONS.COMPLIANCE_READ, PERMISSIONS.EVIDENCE_EXPORT], 'permission'),
  closeoutPackController.listCloseoutPacks
);

router.get(
  '/:id',
  validateRequest({ params: closeoutPackIdParamsSchema }),
  authenticate(),
  authorize([PERMISSIONS.LAST_OFFICE_READ, PERMISSIONS.COMPLIANCE_READ, PERMISSIONS.EVIDENCE_EXPORT], 'permission'),
  closeoutPackController.getCloseoutPackById
);

router.post(
  '/',
  validateRequest({ body: createCloseoutPackSchema }),
  authenticate(),
  authorize(PERMISSIONS.EVIDENCE_EXPORT, 'permission'),
  closeoutPackController.createCloseoutPack
);

router.get(
  '/:id/download',
  validateRequest({ params: closeoutPackIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.EVIDENCE_EXPORT, 'permission'),
  closeoutPackController.downloadCloseoutPack
);

module.exports = router;
