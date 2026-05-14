/**
 * User MFA routes
 *
 * @module modules/user-mfa/routes
 * @description User MFA endpoints mounted at /api/v1/user-mfas
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const userMfaController = require('@controllers/user-mfa/user-mfa.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createUserMfaSchema,
  updateUserMfaSchema,
  verifyMfaSchema,
  enableMfaSchema,
  disableMfaSchema,
  userMfaIdParamsSchema,
  listUserMfasQuerySchema
} = require('@validations/user-mfa/user-mfa.schema');

/**
 * @description List user MFA configurations with pagination and filters
 * @method GET
 * @route /api/v1/user-mfas/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [user_id] - Filter by user ID (UUID)
 * @queryParams {string} [channel] - Filter by channel (SMS, EMAIL, AUTHENTICATOR_APP, VOICE)
 * @queryParams {string} [is_enabled] - Filter by enabled status (true/false)
 * @bodyParams None
 * @returns {Object} Paginated list of user MFA configurations
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listUserMfasQuerySchema }),

  authenticate(),
  userMfaController.listUserMfas
);

/**
 * @description Get user MFA configuration by ID
 * @method GET
 * @route /api/v1/user-mfas/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User MFA ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} User MFA configuration data
 * @throws 401 Unauthorized
 * @throws 404 User MFA not found
 */
router.get(
  '/:id',  validateRequest({ params: userMfaIdParamsSchema }),

  authenticate(),
  userMfaController.getUserMfaById
);

/**
 * @description Create new user MFA configuration
 * @method POST
 * @route /api/v1/user-mfas/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} user_id - User ID (required, UUID)
 * @bodyParams {string} channel - MFA channel (required, SMS/EMAIL/AUTHENTICATOR_APP/VOICE)
 * @bodyParams {string} secret_encrypted - Encrypted secret (required, max 255 chars)
 * @bodyParams {boolean} [is_enabled=true] - Enable status (default: true)
 * @returns {Object} Created user MFA configuration
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 */
router.post(
  '/',  validateRequest({ body: createUserMfaSchema }),

  authenticate(),
  userMfaController.createUserMfa
);

/**
 * @description Update user MFA configuration
 * @method PUT
 * @route /api/v1/user-mfas/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User MFA ID (UUID)
 * @queryParams None
 * @bodyParams {string} [channel] - MFA channel (SMS/EMAIL/AUTHENTICATOR_APP/VOICE)
 * @bodyParams {string} [secret_encrypted] - Encrypted secret (max 255 chars)
 * @bodyParams {boolean} [is_enabled] - Enable status
 * @returns {Object} Updated user MFA configuration
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 User MFA not found
 */
router.put(
  '/:id',  validateRequest({ params: userMfaIdParamsSchema, body: updateUserMfaSchema }),

  authenticate(),
  userMfaController.updateUserMfa
);

/**
 * @description Delete user MFA configuration (soft delete)
 * @method DELETE
 * @route /api/v1/user-mfas/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User MFA ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 User MFA not found
 */
router.delete(
  '/:id',  validateRequest({ params: userMfaIdParamsSchema }),

  authenticate(),
  userMfaController.deleteUserMfa
);

/**
 * @description Verify MFA code
 * @method POST
 * @route /api/v1/user-mfas/:id/verify
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User MFA ID (UUID)
 * @queryParams None
 * @bodyParams {string} code - MFA verification code (required, 4-10 chars)
 * @returns {Object} Verification result
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 User MFA not found
 * @throws 400 MFA is disabled
 */
router.post(
  '/:id/verify',  validateRequest({ params: userMfaIdParamsSchema, body: verifyMfaSchema }),

  authenticate(),
  userMfaController.verifyMfaCode
);

/**
 * @description Enable MFA configuration
 * @method POST
 * @route /api/v1/user-mfas/:id/enable
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User MFA ID (UUID)
 * @queryParams None
 * @bodyParams {string} [verification_code] - Optional verification code (4-10 chars)
 * @returns {Object} Updated user MFA configuration
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 User MFA not found
 * @throws 400 MFA already enabled
 */
router.post(
  '/:id/enable',  validateRequest({ params: userMfaIdParamsSchema, body: enableMfaSchema }),

  authenticate(),
  userMfaController.enableMfa
);

/**
 * @description Disable MFA configuration
 * @method POST
 * @route /api/v1/user-mfas/:id/disable
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User MFA ID (UUID)
 * @queryParams None
 * @bodyParams {string} [verification_code] - Optional verification code (4-10 chars)
 * @returns {Object} Updated user MFA configuration
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 User MFA not found
 * @throws 400 MFA already disabled
 */
router.post(
  '/:id/disable',  validateRequest({ params: userMfaIdParamsSchema, body: disableMfaSchema }),

  authenticate(),
  userMfaController.disableMfa
);

module.exports = router;
