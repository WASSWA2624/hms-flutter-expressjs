/**
 * Adverse Event routes
 *
 * @module modules/adverse-event/routes
 * @description Adverse event endpoints mounted at /api/v1/adverse-events
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const { asyncHandler } = require('@lib/async');
const adverseEventController = require('@controllers/adverse-event/adverse-event.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createAdverseEventSchema,
  updateAdverseEventSchema,
  adverseEventIdParamsSchema,
  listAdverseEventsQuerySchema
} = require('@validations/adverse-event/adverse-event.schema');

/**
 * @description List adverse events with pagination and filters
 * @method GET
 * @route /api/v1/adverse-events/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [drug_id] - Filter by drug ID (UUID)
 * @queryParams {string} [severity] - Filter by severity (MILD, MODERATE, SEVERE)
 * @queryParams {string} [reported_at_from] - Filter by reported_at start date (ISO 8601)
 * @queryParams {string} [reported_at_to] - Filter by reported_at end date (ISO 8601)
 * @queryParams {string} [search] - Search in description field
 * @bodyParams None
 * @returns {Object} Paginated list of adverse events
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listAdverseEventsQuerySchema }),

  authenticate(),
  asyncHandler(adverseEventController.listAdverseEvents)
);

/**
 * @description Get adverse event by ID
 * @method GET
 * @route /api/v1/adverse-events/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Adverse event ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Adverse event data
 * @throws 401 Unauthorized
 * @throws 404 Adverse event not found
 */
router.get(
  '/:id',  validateRequest({ params: adverseEventIdParamsSchema }),

  authenticate(),
  asyncHandler(adverseEventController.getAdverseEventById)
);

/**
 * @description Create new adverse event
 * @method POST
 * @route /api/v1/adverse-events/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} patient_id - Patient ID (required, UUID)
 * @bodyParams {string} [drug_id] - Drug ID (UUID)
 * @bodyParams {string} severity - Severity (required, MILD/MODERATE/SEVERE)
 * @bodyParams {string} [description] - Description (text, max 65535 chars)
 * @bodyParams {string} [reported_at] - Reported timestamp (ISO 8601)
 * @returns {Object} Created adverse event
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createAdverseEventSchema }),

  authenticate(),
  asyncHandler(adverseEventController.createAdverseEvent)
);

/**
 * @description Update adverse event
 * @method PUT
 * @route /api/v1/adverse-events/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Adverse event ID (UUID)
 * @queryParams None
 * @bodyParams {string} [drug_id] - Drug ID (UUID)
 * @bodyParams {string} [severity] - Severity (MILD/MODERATE/SEVERE)
 * @bodyParams {string} [description] - Description (text, max 65535 chars)
 * @bodyParams {string} [reported_at] - Reported timestamp (ISO 8601)
 * @returns {Object} Updated adverse event
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Adverse event not found
 */
router.put(
  '/:id',  validateRequest({ params: adverseEventIdParamsSchema, body: updateAdverseEventSchema }),

  authenticate(),
  asyncHandler(adverseEventController.updateAdverseEvent)
);

/**
 * @description Delete adverse event (soft delete)
 * @method DELETE
 * @route /api/v1/adverse-events/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Adverse event ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Adverse event not found
 */
router.delete(
  '/:id',  validateRequest({ params: adverseEventIdParamsSchema }),

  authenticate(),
  asyncHandler(adverseEventController.deleteAdverseEvent)
);

module.exports = router;
