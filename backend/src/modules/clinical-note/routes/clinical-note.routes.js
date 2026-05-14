/**
 * Clinical note routes
 */

const express = require('express');
const router = express.Router();
const clinicalNoteController = require('@controllers/clinical-note/clinical-note.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { requireClinicalDeletePrivilege } = require('@middlewares/clinical-guard.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createClinicalNoteSchema,
  updateClinicalNoteSchema,
  clinicalNoteIdParamsSchema,
  listClinicalNotesQuerySchema,
} = require('@validations/clinical-note/clinical-note.schema');

router.get(
  '/',
  validateRequest({ query: listClinicalNotesQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  clinicalNoteController.listClinicalNotes
);

router.get(
  '/:id',
  validateRequest({ params: clinicalNoteIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_READ, 'permission'),
  clinicalNoteController.getClinicalNoteById
);

router.post(
  '/',
  validateRequest({ body: createClinicalNoteSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  clinicalNoteController.createClinicalNote
);

router.put(
  '/:id',
  validateRequest({ params: clinicalNoteIdParamsSchema, body: updateClinicalNoteSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  clinicalNoteController.updateClinicalNote
);

router.delete(
  '/:id',
  validateRequest({ params: clinicalNoteIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.CLINICAL_WRITE, 'permission'),
  requireClinicalDeletePrivilege(),
  clinicalNoteController.deleteClinicalNote
);

module.exports = router;

