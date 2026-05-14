/**
 * Nursing note routes
 *
 * @module modules/nursing-note/routes
 * @description Nursing note endpoints mounted at /api/v1/nursing-notes
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const nursingNoteController = require('@controllers/nursing-note/nursing-note.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createNursingNoteSchema,
  updateNursingNoteSchema,
  nursingNoteIdParamsSchema,
  listNursingNotesQuerySchema
} = require('@validations/nursing-note/nursing-note.schema');

const IPD_READ_SCOPES = [PERMISSIONS.CLINICAL_READ];
const IPD_WRITE_SCOPES = [PERMISSIONS.CLINICAL_WRITE];
const IPD_ADMIN_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

/**
 * @description List nursing notes with pagination and filters
 * @method GET
 * @route /api/v1/nursing-notes/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [admission_id] - Filter by admission ID (UUID)
 * @queryParams {string} [nurse_user_id] - Filter by nurse user ID (UUID)
 * @bodyParams None
 * @returns {Object} Paginated list of nursing notes
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listNursingNotesQuerySchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  nursingNoteController.listNursingNotes
);

/**
 * @description Get nursing note by ID
 * @method GET
 * @route /api/v1/nursing-notes/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Nursing note ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Nursing note data
 * @throws 401 Unauthorized
 * @throws 404 Nursing note not found
 */
router.get(
  '/:id',  validateRequest({ params: nursingNoteIdParamsSchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  nursingNoteController.getNursingNoteById
);

/**
 * @description Create new nursing note
 * @method POST
 * @route /api/v1/nursing-notes/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} admission_id - Admission ID (required, UUID)
 * @bodyParams {string} nurse_user_id - Nurse user ID (required, UUID)
 * @bodyParams {string} note - Nursing note content (required, max 65535 chars)
 * @returns {Object} Created nursing note
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createNursingNoteSchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  nursingNoteController.createNursingNote
);

/**
 * @description Update nursing note
 * @method PUT
 * @route /api/v1/nursing-notes/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Nursing note ID (UUID)
 * @queryParams None
 * @bodyParams {string} [note] - Nursing note content (max 65535 chars)
 * @returns {Object} Updated nursing note
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Nursing note not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: nursingNoteIdParamsSchema, body: updateNursingNoteSchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  nursingNoteController.updateNursingNote
);

/**
 * @description Delete nursing note (soft delete)
 * @method DELETE
 * @route /api/v1/nursing-notes/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Nursing note ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Nursing note not found
 */
router.delete(
  '/:id',  validateRequest({ params: nursingNoteIdParamsSchema }),

  authenticate(),
  authorize(IPD_ADMIN_SCOPES, 'permission'),
  nursingNoteController.deleteNursingNote
);

module.exports = router;
