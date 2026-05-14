/**
 * Anesthesia record routes
 *
 * @module modules/anesthesia-record/routes
 * @description Anesthesia record endpoints mounted at /api/v1/anesthesia-records
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const anesthesiaRecordController = require('@controllers/anesthesia-record/anesthesia-record.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createAnesthesiaRecordSchema,
  updateAnesthesiaRecordSchema,
  anesthesiaRecordIdParamsSchema,
  listAnesthesiaRecordsQuerySchema
} = require('@validations/anesthesia-record/anesthesia-record.schema');

const THEATRE_ALLOWED_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
];

/**
 * @description List anesthesia records with pagination and filters
 * @method GET
 * @route /api/v1/anesthesia-records/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [theatre_case_id] - Filter by theatre case ID (UUID)
 * @queryParams {string} [anesthetist_user_id] - Filter by anesthetist user ID (UUID)
 * @bodyParams None
 * @returns {Object} Paginated list of anesthesia records
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listAnesthesiaRecordsQuerySchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  anesthesiaRecordController.listAnesthesiaRecords
);

/**
 * @description Get anesthesia record by ID
 * @method GET
 * @route /api/v1/anesthesia-records/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Anesthesia record ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Anesthesia record data
 * @throws 401 Unauthorized
 * @throws 404 Anesthesia record not found
 */
router.get(
  '/:id',  validateRequest({ params: anesthesiaRecordIdParamsSchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  anesthesiaRecordController.getAnesthesiaRecordById
);

/**
 * @description Create new anesthesia record
 * @method POST
 * @route /api/v1/anesthesia-records/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} theatre_case_id - Theatre case ID (required, UUID)
 * @bodyParams {string} [anesthetist_user_id] - Anesthetist user ID (UUID)
 * @bodyParams {string} [notes] - Anesthesia notes (text)
 * @returns {Object} Created anesthesia record
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createAnesthesiaRecordSchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  anesthesiaRecordController.createAnesthesiaRecord
);

/**
 * @description Update anesthesia record
 * @method PUT
 * @route /api/v1/anesthesia-records/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Anesthesia record ID (UUID)
 * @queryParams None
 * @bodyParams {string} [theatre_case_id] - Theatre case ID (UUID)
 * @bodyParams {string} [anesthetist_user_id] - Anesthetist user ID (UUID)
 * @bodyParams {string} [notes] - Anesthesia notes (text)
 * @returns {Object} Updated anesthesia record
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Anesthesia record not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: anesthesiaRecordIdParamsSchema, body: updateAnesthesiaRecordSchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  anesthesiaRecordController.updateAnesthesiaRecord
);

/**
 * @description Delete anesthesia record (soft delete)
 * @method DELETE
 * @route /api/v1/anesthesia-records/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Anesthesia record ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Anesthesia record not found
 */
router.delete(
  '/:id',  validateRequest({ params: anesthesiaRecordIdParamsSchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  anesthesiaRecordController.deleteAnesthesiaRecord
);

module.exports = router;
