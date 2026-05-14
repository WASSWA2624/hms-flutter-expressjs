/**
 * Theatre case routes
 *
 * @module modules/theatre-case/routes
 * @description Theatre case endpoints mounted at /api/v1/theatre-cases
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const theatreCaseController = require('@controllers/theatre-case/theatre-case.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createTheatreCaseSchema,
  updateTheatreCaseSchema,
  theatreCaseIdParamsSchema,
  listTheatreCasesQuerySchema
} = require('@validations/theatre-case/theatre-case.schema');

const THEATRE_ALLOWED_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
];

/**
 * @description List theatre cases with pagination and filters
 * @method GET
 * @route /api/v1/theatre-cases/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [encounter_id] - Filter by encounter ID (UUID or friendly ID)
 * @queryParams {string} [status] - Filter by status (SCHEDULED/IN_PROGRESS/COMPLETED/CANCELLED)
 * @queryParams {string} [scheduled_from] - Filter by scheduled_at from date (ISO 8601 datetime)
 * @queryParams {string} [scheduled_to] - Filter by scheduled_at to date (ISO 8601 datetime)
 * @bodyParams None
 * @returns {Object} Paginated list of theatre cases
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listTheatreCasesQuerySchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreCaseController.listTheatreCases
);

/**
 * @description Get theatre case by ID
 * @method GET
 * @route /api/v1/theatre-cases/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Theatre case ID (UUID or friendly ID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Theatre case data
 * @throws 401 Unauthorized
 * @throws 404 Theatre case not found
 */
router.get(
  '/:id',  validateRequest({ params: theatreCaseIdParamsSchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreCaseController.getTheatreCaseById
);

/**
 * @description Create new theatre case
 * @method POST
 * @route /api/v1/theatre-cases/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} encounter_id - Encounter ID (required, UUID or friendly ID)
 * @bodyParams {string} scheduled_at - Scheduled date and time (required, ISO 8601 datetime)
 * @bodyParams {string} [status] - Status (defaults to SCHEDULED when omitted)
 * @returns {Object} Created theatre case
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createTheatreCaseSchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreCaseController.createTheatreCase
);

/**
 * @description Update theatre case
 * @method PUT
 * @route /api/v1/theatre-cases/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Theatre case ID (UUID or friendly ID)
 * @queryParams None
 * @bodyParams {string} [encounter_id] - Encounter ID (UUID or friendly ID)
 * @bodyParams {string} [scheduled_at] - Scheduled date and time (ISO 8601 datetime)
 * @bodyParams {string} [status] - Status (SCHEDULED/IN_PROGRESS/COMPLETED/CANCELLED)
 * @returns {Object} Updated theatre case
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Theatre case not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: theatreCaseIdParamsSchema, body: updateTheatreCaseSchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreCaseController.updateTheatreCase
);

/**
 * @description Delete theatre case (soft delete)
 * @method DELETE
 * @route /api/v1/theatre-cases/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Theatre case ID (UUID or friendly ID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Theatre case not found
 */
router.delete(
  '/:id',  validateRequest({ params: theatreCaseIdParamsSchema }),

  authenticate(),
  authorize(THEATRE_ALLOWED_ROLES, 'role'),
  theatreCaseController.deleteTheatreCase
);

module.exports = router;
