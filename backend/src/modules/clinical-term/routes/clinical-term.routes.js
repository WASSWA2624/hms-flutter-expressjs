/**
 * Clinical term suggestion routes
 */

const express = require('express');
const router = express.Router();
const clinicalTermController = require('@controllers/clinical-term/clinical-term.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  listClinicalTermSuggestionsQuerySchema,
} = require('@validations/clinical-term/clinical-term.schema');

router.get(
  '/suggestions',
  validateRequest({ query: listClinicalTermSuggestionsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  clinicalTermController.listClinicalTermSuggestions
);

module.exports = router;

