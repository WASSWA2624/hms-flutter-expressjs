/**
 * Clinical term favorite routes
 */

const express = require('express');
const router = express.Router();
const clinicalTermController = require('@controllers/clinical-term/clinical-term.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  listClinicalTermFavoritesQuerySchema,
  createClinicalTermFavoriteSchema,
  clinicalTermFavoriteIdParamsSchema,
} = require('@validations/clinical-term/clinical-term.schema');

router.get(
  '/',
  validateRequest({ query: listClinicalTermFavoritesQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  clinicalTermController.listClinicalTermFavorites
);

router.post(
  '/',
  validateRequest({ body: createClinicalTermFavoriteSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  clinicalTermController.createClinicalTermFavorite
);

router.delete(
  '/:id',
  validateRequest({ params: clinicalTermFavoriteIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  clinicalTermController.deleteClinicalTermFavorite
);

module.exports = router;

