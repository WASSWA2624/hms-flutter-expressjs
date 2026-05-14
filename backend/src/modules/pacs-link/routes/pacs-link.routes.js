/**
 * PACS link routes
 *
 * @module modules/pacs-link/routes
 * @description PACS link endpoints mounted at /api/v1/pacs-links
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const pacsLinkController = require('@controllers/pacs-link/pacs-link.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createPacsLinkSchema,
  updatePacsLinkSchema,
  pacsLinkIdParamsSchema,
  listPacsLinksQuerySchema
} = require('@validations/pacs-link/pacs-link.schema');

/**
 * @description List PACS links with pagination and filters
 * @method GET
 * @route /api/v1/pacs-links/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [imaging_study_id] - Filter by imaging study ID (UUID)
 * @queryParams {string} [expires_at] - Filter by expiration date (ISO 8601 datetime)
 * @bodyParams None
 * @returns {Object} Paginated list of PACS links
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listPacsLinksQuerySchema }),

  authenticate(),
  pacsLinkController.listPacsLinks
);

/**
 * @description Get PACS link by ID
 * @method GET
 * @route /api/v1/pacs-links/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - PACS link ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} PACS link data
 * @throws 401 Unauthorized
 * @throws 404 PACS link not found
 */
router.get(
  '/:id',  validateRequest({ params: pacsLinkIdParamsSchema }),

  authenticate(),
  pacsLinkController.getPacsLinkById
);

/**
 * @description Create new PACS link
 * @method POST
 * @route /api/v1/pacs-links/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} imaging_study_id - Imaging study ID (required, UUID)
 * @bodyParams {string} url - PACS URL (required, valid URL format)
 * @bodyParams {string} [expires_at] - Expiration date (ISO 8601 datetime)
 * @returns {Object} Created PACS link
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createPacsLinkSchema }),

  authenticate(),
  pacsLinkController.createPacsLink
);

/**
 * @description Update PACS link
 * @method PUT
 * @route /api/v1/pacs-links/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - PACS link ID (UUID)
 * @queryParams None
 * @bodyParams {string} [url] - PACS URL (valid URL format)
 * @bodyParams {string} [expires_at] - Expiration date (ISO 8601 datetime)
 * @returns {Object} Updated PACS link
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 PACS link not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: pacsLinkIdParamsSchema, body: updatePacsLinkSchema }),

  authenticate(),
  pacsLinkController.updatePacsLink
);

/**
 * @description Delete PACS link (soft delete)
 * @method DELETE
 * @route /api/v1/pacs-links/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - PACS link ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 PACS link not found
 */
router.delete(
  '/:id',  validateRequest({ params: pacsLinkIdParamsSchema }),

  authenticate(),
  pacsLinkController.deletePacsLink
);

module.exports = router;
