/**
 * Imaging study routes
 *
 * @module modules/imaging-study/routes
 * @description Imaging study endpoints mounted at /api/v1/imaging-studies
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const imagingStudyController = require('@controllers/imaging-study/imaging-study.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createImagingStudySchema,
  updateImagingStudySchema,
  imagingStudyIdParamsSchema,
  listImagingStudiesQuerySchema
} = require('@validations/imaging-study/imaging-study.schema');

/**
 * @description List imaging studies with pagination and filters
 * @method GET
 * @route /api/v1/imaging-studies/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [radiology_order_id] - Filter by radiology order ID (UUID)
 * @queryParams {string} [modality] - Filter by modality (XRAY, CT, MRI, ULTRASOUND, PET, OTHER)
 * @queryParams {string} [performed_at] - Filter by performed date (ISO 8601 datetime)
 * @bodyParams None
 * @returns {Object} Paginated list of imaging studies
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listImagingStudiesQuerySchema }),

  authenticate(),
  imagingStudyController.listImagingStudies
);

/**
 * @description Get imaging study by ID
 * @method GET
 * @route /api/v1/imaging-studies/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Imaging study ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Imaging study data
 * @throws 401 Unauthorized
 * @throws 404 Imaging study not found
 */
router.get(
  '/:id',  validateRequest({ params: imagingStudyIdParamsSchema }),

  authenticate(),
  imagingStudyController.getImagingStudyById
);

/**
 * @description Create new imaging study
 * @method POST
 * @route /api/v1/imaging-studies/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} radiology_order_id - Radiology order ID (required, UUID)
 * @bodyParams {string} modality - Modality (required, XRAY/CT/MRI/ULTRASOUND/PET/OTHER)
 * @bodyParams {string} [performed_at] - Performed date (ISO 8601 datetime)
 * @returns {Object} Created imaging study
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createImagingStudySchema }),

  authenticate(),
  imagingStudyController.createImagingStudy
);

/**
 * @description Update imaging study
 * @method PUT
 * @route /api/v1/imaging-studies/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Imaging study ID (UUID)
 * @queryParams None
 * @bodyParams {string} [modality] - Modality (XRAY/CT/MRI/ULTRASOUND/PET/OTHER)
 * @bodyParams {string} [performed_at] - Performed date (ISO 8601 datetime)
 * @returns {Object} Updated imaging study
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Imaging study not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: imagingStudyIdParamsSchema, body: updateImagingStudySchema }),

  authenticate(),
  imagingStudyController.updateImagingStudy
);

/**
 * @description Delete imaging study (soft delete)
 * @method DELETE
 * @route /api/v1/imaging-studies/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Imaging study ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Imaging study not found
 */
router.delete(
  '/:id',  validateRequest({ params: imagingStudyIdParamsSchema }),

  authenticate(),
  imagingStudyController.deleteImagingStudy
);

module.exports = router;
