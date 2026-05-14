/**
 * User profile routes
 *
 * @module modules/user-profile/routes
 * @description User profile endpoints mounted at /api/v1/user-profiles
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const userProfileController = require('@controllers/user-profile/user-profile.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createUserProfileSchema,
  updateUserProfileSchema,
  userProfileIdParamsSchema,
  listUserProfilesQuerySchema
} = require('@validations/user-profile/user-profile.schema');

/**
 * @description List user profiles with pagination and filters
 * @method GET
 * @route /api/v1/user-profiles/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [user_id] - Filter by user ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [gender] - Filter by gender (MALE, FEMALE, OTHER, UNKNOWN)
 * @queryParams {string} [search] - Search in first_name and last_name fields
 * @bodyParams None
 * @returns {Object} Paginated list of user profiles
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listUserProfilesQuerySchema }),

  authenticate(),
  userProfileController.listUserProfiles
);

/**
 * @description Get user profile by ID
 * @method GET
 * @route /api/v1/user-profiles/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User profile ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} User profile data
 * @throws 401 Unauthorized
 * @throws 404 User profile not found
 */
router.get(
  '/:id',  validateRequest({ params: userProfileIdParamsSchema }),

  authenticate(),
  userProfileController.getUserProfileById
);

/**
 * @description Create new user profile
 * @method POST
 * @route /api/v1/user-profiles/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} user_id - User ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} first_name - First name (required, max 120 chars)
 * @bodyParams {string} [middle_name] - Middle name (optional, max 120 chars)
 * @bodyParams {string} [last_name] - Last name (optional, max 120 chars)
 * @bodyParams {string} [gender] - Gender (MALE/FEMALE/OTHER/UNKNOWN)
 * @bodyParams {string} [date_of_birth] - Date of birth (ISO datetime)
 * @returns {Object} Created user profile
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation (duplicate user_id)
 */
router.post(
  '/',  validateRequest({ body: createUserProfileSchema }),

  authenticate(),
  userProfileController.createUserProfile
);

/**
 * @description Update user profile
 * @method PUT
 * @route /api/v1/user-profiles/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User profile ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [first_name] - First name (max 120 chars)
 * @bodyParams {string} [middle_name] - Middle name (optional, max 120 chars)
 * @bodyParams {string} [last_name] - Last name (optional, max 120 chars)
 * @bodyParams {string} [gender] - Gender (MALE/FEMALE/OTHER/UNKNOWN)
 * @bodyParams {string} [date_of_birth] - Date of birth (ISO datetime)
 * @returns {Object} Updated user profile
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 User profile not found
 * @throws 400 Foreign key constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: userProfileIdParamsSchema, body: updateUserProfileSchema }),

  authenticate(),
  userProfileController.updateUserProfile
);

/**
 * @description Delete user profile (soft delete)
 * @method DELETE
 * @route /api/v1/user-profiles/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - User profile ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 User profile not found
 */
router.delete(
  '/:id',  validateRequest({ params: userProfileIdParamsSchema }),

  authenticate(),
  userProfileController.deleteUserProfile
);

module.exports = router;
