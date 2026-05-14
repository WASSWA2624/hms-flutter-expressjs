/**
 * User Session routes
 *
 * @module modules/user-session/routes
 * @description User session endpoints mounted at /api/v1/user-sessions
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const sessionController = require('@controllers/user-session/user-session.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  sessionIdParamsSchema,
  listSessionsQuerySchema
} = require('@validations/user-session/user-session.schema');

/**
 * @description List user sessions with pagination and filters
 * @method GET
 * @route /api/v1/user-sessions/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [user_id] - Filter by user ID
 * @queryParams {string} [is_active] - Filter by active status (true/false)
 * @bodyParams None
 * @returns {Object} Paginated list of sessions
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listSessionsQuerySchema }),

  authenticate(),
  sessionController.listSessions
);

/**
 * @description Get user session by ID
 * @method GET
 * @route /api/v1/user-sessions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Session ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Session data
 * @throws 401 Unauthorized
 * @throws 404 Session not found
 */
router.get(
  '/:id',  validateRequest({ params: sessionIdParamsSchema }),

  authenticate(),
  sessionController.getSessionById
);

/**
 * @description Revoke user session
 * @method DELETE
 * @route /api/v1/user-sessions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Session ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Session not found
 * @throws 400 Session already revoked
 */
router.delete(
  '/:id',  validateRequest({ params: sessionIdParamsSchema }),

  authenticate(),
  sessionController.revokeSession
);

module.exports = router;
