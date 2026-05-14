/**
 * Radiology test routes
 *
 * @module modules/radiology-test/routes
 * @description Radiology test endpoints mounted at /api/v1/radiology-tests
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const radiologyTestController = require('@controllers/radiology-test/radiology-test.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createRadiologyTestSchema,
  updateRadiologyTestSchema,
  radiologyTestIdParamsSchema,
  listRadiologyTestsQuerySchema
} = require('@validations/radiology-test/radiology-test.schema');

/**
 * @description List radiology tests with pagination and filters
 * @method GET
 * @route /api/v1/radiology-tests/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [name] - Filter by name (partial match)
 * @queryParams {string} [code] - Filter by code (partial match)
 * @queryParams {string} [modality] - Filter by modality (XRAY, CT, MRI, ULTRASOUND, PET, OTHER)
 * @queryParams {string} [search] - Search in name and code fields
 * @bodyParams None
 * @returns {Object} Paginated list of radiology tests
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listRadiologyTestsQuerySchema }),

  authenticate(),
  radiologyTestController.listRadiologyTests
);

/**
 * @description Get radiology test by ID
 * @method GET
 * @route /api/v1/radiology-tests/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Radiology test ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Radiology test data
 * @throws 401 Unauthorized
 * @throws 404 Radiology test not found
 */
router.get(
  '/:id',  validateRequest({ params: radiologyTestIdParamsSchema }),

  authenticate(),
  radiologyTestController.getRadiologyTestById
);

/**
 * @description Create new radiology test
 * @method POST
 * @route /api/v1/radiology-tests/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} name - Test name (required, max 255 chars)
 * @bodyParams {string} [code] - Test code (max 80 chars)
 * @bodyParams {string} modality - Imaging modality (required, XRAY/CT/MRI/ULTRASOUND/PET/OTHER)
 * @returns {Object} Created radiology test
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createRadiologyTestSchema }),

  authenticate(),
  radiologyTestController.createRadiologyTest
);

/**
 * @description Update radiology test
 * @method PUT
 * @route /api/v1/radiology-tests/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Radiology test ID (UUID)
 * @queryParams None
 * @bodyParams {string} [name] - Test name (max 255 chars)
 * @bodyParams {string} [code] - Test code (max 80 chars)
 * @bodyParams {string} [modality] - Imaging modality (XRAY/CT/MRI/ULTRASOUND/PET/OTHER)
 * @returns {Object} Updated radiology test
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Radiology test not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: radiologyTestIdParamsSchema, body: updateRadiologyTestSchema }),

  authenticate(),
  radiologyTestController.updateRadiologyTest
);

/**
 * @description Delete radiology test (soft delete)
 * @method DELETE
 * @route /api/v1/radiology-tests/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Radiology test ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Radiology test not found
 */
router.delete(
  '/:id',  validateRequest({ params: radiologyTestIdParamsSchema }),

  authenticate(),
  radiologyTestController.deleteRadiologyTest
);

module.exports = router;
