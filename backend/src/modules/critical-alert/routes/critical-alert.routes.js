/**
 * Critical Alert routes
 *
 * @module modules/critical-alert/routes
 * @description Critical alert endpoints mounted at /api/v1/critical-alerts
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const criticalAlertController = require('@controllers/critical-alert/critical-alert.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createCriticalAlertSchema,
  updateCriticalAlertSchema,
  criticalAlertIdParamsSchema,
  listCriticalAlertsQuerySchema
} = require('@validations/critical-alert/critical-alert.schema');

const ICU_ALLOWED_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
];

/**
 * @description List critical alerts with pagination and filters
 * @method GET
 * @route /api/v1/critical-alerts/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [icu_stay_id] - Filter by ICU stay ID (UUID)
 * @queryParams {string} [severity] - Filter by severity (LOW/MEDIUM/HIGH/CRITICAL)
 * @queryParams {string} [search] - Search in message text
 * @bodyParams None
 * @returns {Object} Paginated list of critical alerts
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listCriticalAlertsQuerySchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  criticalAlertController.listCriticalAlerts
);

/**
 * @description Get critical alert by ID
 * @method GET
 * @route /api/v1/critical-alerts/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Critical Alert ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Critical alert data
 * @throws 401 Unauthorized
 * @throws 404 Critical alert not found
 */
router.get(
  '/:id',  validateRequest({ params: criticalAlertIdParamsSchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  criticalAlertController.getCriticalAlertById
);

/**
 * @description Create new critical alert
 * @method POST
 * @route /api/v1/critical-alerts/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} icu_stay_id - ICU Stay ID (required, UUID)
 * @bodyParams {string} severity - Severity level (required, LOW/MEDIUM/HIGH/CRITICAL)
 * @bodyParams {string} message - Alert message (required, max 2000 chars)
 * @returns {Object} Created critical alert
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createCriticalAlertSchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  criticalAlertController.createCriticalAlert
);

/**
 * @description Update critical alert
 * @method PUT
 * @route /api/v1/critical-alerts/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Critical Alert ID (UUID)
 * @queryParams None
 * @bodyParams {string} [severity] - Severity level (LOW/MEDIUM/HIGH/CRITICAL)
 * @bodyParams {string} [message] - Alert message (max 2000 chars)
 * @returns {Object} Updated critical alert
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Critical alert not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: criticalAlertIdParamsSchema, body: updateCriticalAlertSchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  criticalAlertController.updateCriticalAlert
);

/**
 * @description Delete critical alert (soft delete)
 * @method DELETE
 * @route /api/v1/critical-alerts/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Critical Alert ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Critical alert not found
 */
router.delete(
  '/:id',  validateRequest({ params: criticalAlertIdParamsSchema }),

  authenticate(),
  authorize(ICU_ALLOWED_ROLES, 'role'),
  criticalAlertController.deleteCriticalAlert
);

module.exports = router;
