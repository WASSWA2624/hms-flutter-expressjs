/**
 * Post-op note routes
 *
 * @module modules/post-op-note/routes
 * @description Post-op note endpoints mounted at /api/v1/post-op-notes
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const postOpNoteController = require('@controllers/post-op-note/post-op-note.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createPostOpNoteSchema,
  updatePostOpNoteSchema,
  postOpNoteIdParamsSchema,
  listPostOpNotesQuerySchema
} = require('@validations/post-op-note/post-op-note.schema');

const THEATRE_ALLOWED_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
];

/**
 * @description List Post-op notes with pagination and filters
 * @method GET
 * @route /api/v1/post-op-notes/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [theatre_case_id] - Filter by theatre case ID (UUID)
 * @queryParams {string} [note] - Filter by anesthetist user ID (UUID)
 * @bodyParams None
 * @returns {Object} Paginated list of Post-op notes
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listPostOpNotesQuerySchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  postOpNoteController.listpostOpNotes
);

/**
 * @description Get Post-op note by ID
 * @method GET
 * @route /api/v1/post-op-notes/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Post-op note ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Post-op note data
 * @throws 401 Unauthorized
 * @throws 404 Post-op note not found
 */
router.get(
  '/:id',  validateRequest({ params: postOpNoteIdParamsSchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  postOpNoteController.getpostOpNoteById
);

/**
 * @description Create new Post-op note
 * @method POST
 * @route /api/v1/post-op-notes/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} theatre_case_id - Theatre case ID (required, UUID)
 * @bodyParams {string} [note] - Anesthetist user ID (UUID)
 * @bodyParams {string} [notes] - Anesthesia notes (text)
 * @returns {Object} Created Post-op note
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createPostOpNoteSchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  postOpNoteController.createpostOpNote
);

/**
 * @description Update Post-op note
 * @method PUT
 * @route /api/v1/post-op-notes/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Post-op note ID (UUID)
 * @queryParams None
 * @bodyParams {string} [theatre_case_id] - Theatre case ID (UUID)
 * @bodyParams {string} [note] - Anesthetist user ID (UUID)
 * @bodyParams {string} [notes] - Anesthesia notes (text)
 * @returns {Object} Updated Post-op note
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Post-op note not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: postOpNoteIdParamsSchema, body: updatePostOpNoteSchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  postOpNoteController.updatepostOpNote
);

/**
 * @description Delete Post-op note (soft delete)
 * @method DELETE
 * @route /api/v1/post-op-notes/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Post-op note ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Post-op note not found
 */
router.delete(
  '/:id',  validateRequest({ params: postOpNoteIdParamsSchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  postOpNoteController.deletepostOpNote
);

module.exports = router;

