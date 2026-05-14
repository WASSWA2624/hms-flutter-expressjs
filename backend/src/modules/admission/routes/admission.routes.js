/**
 * Admission routes
 *
 * @module modules/admission/routes
 * @description Admission endpoints mounted at /api/v1/admissions
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const admissionController = require('@controllers/admission/admission.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createAdmissionSchema,
  updateAdmissionSchema,
  dischargeAdmissionSchema,
  transferAdmissionSchema,
  admissionIdParamsSchema,
  listAdmissionsQuerySchema
} = require('@validations/admission/admission.schema');

const IPD_READ_SCOPES = [PERMISSIONS.CLINICAL_READ];
const IPD_WRITE_SCOPES = [PERMISSIONS.CLINICAL_WRITE];
const IPD_ADMIN_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];

/**
 * @description List admissions with pagination and filters
 * @method GET
 * @route /api/v1/admissions/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [tenant_id] - Filter by tenant ID (UUID)
 * @queryParams {string} [facility_id] - Filter by facility ID (UUID)
 * @queryParams {string} [patient_id] - Filter by patient ID (UUID)
 * @queryParams {string} [encounter_id] - Filter by encounter ID (UUID)
 * @queryParams {string} [status] - Filter by status (ADMITTED/DISCHARGED/TRANSFERRED/CANCELLED)
 * @bodyParams None
 * @returns {Object} Paginated list of admissions
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listAdmissionsQuerySchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  admissionController.listAdmissions
);

/**
 * @description Get admission by ID
 * @method GET
 * @route /api/v1/admissions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Admission ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Admission data
 * @throws 401 Unauthorized
 * @throws 404 Admission not found
 */
router.get(
  '/:id',  validateRequest({ params: admissionIdParamsSchema }),

  authenticate(),
  authorize(IPD_READ_SCOPES, 'permission'),
  admissionController.getAdmissionById
);

/**
 * @description Create new admission
 * @method POST
 * @route /api/v1/admissions/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} patient_id - Patient ID (required, UUID)
 * @bodyParams {string} [encounter_id] - Encounter ID (UUID)
 * @bodyParams {string} status - Admission status (required, ADMITTED/DISCHARGED/TRANSFERRED/CANCELLED)
 * @bodyParams {string} [admitted_at] - Admission timestamp (ISO 8601 datetime)
 * @returns {Object} Created admission
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createAdmissionSchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  admissionController.createAdmission
);

/**
 * @description Update admission
 * @method PUT
 * @route /api/v1/admissions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Admission ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [encounter_id] - Encounter ID (UUID)
 * @bodyParams {string} [status] - Admission status (ADMITTED/DISCHARGED/TRANSFERRED/CANCELLED)
 * @bodyParams {string} [admitted_at] - Admission timestamp (ISO 8601 datetime)
 * @bodyParams {string} [discharged_at] - Discharge timestamp (ISO 8601 datetime)
 * @returns {Object} Updated admission
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Admission not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: admissionIdParamsSchema, body: updateAdmissionSchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  admissionController.updateAdmission
);

/**
 * @description Delete admission (soft delete)
 * @method DELETE
 * @route /api/v1/admissions/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Admission ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Admission not found
 */
router.delete(
  '/:id',  validateRequest({ params: admissionIdParamsSchema }),

  authenticate(),
  authorize(IPD_ADMIN_SCOPES, 'permission'),
  admissionController.deleteAdmission
);

/**
 * @description Discharge patient from admission
 * @method POST
 * @route /api/v1/admissions/:id/discharge
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Admission ID (UUID)
 * @queryParams None
 * @bodyParams {string} [discharged_at] - Discharge timestamp (ISO 8601 datetime). Defaults to current time if not provided.
 * @returns {Object} Updated admission with discharge information
 * @throws 401 Unauthorized
 * @throws 404 Admission not found
 * @throws 400 Admission already discharged
 */
router.post(
  '/:id/discharge',  validateRequest({ params: admissionIdParamsSchema, body: dischargeAdmissionSchema }),

  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  admissionController.dischargeAdmission
);

/**
 * @description Transfer admission
 * @method POST
 * @route /api/v1/admissions/:id/transfer
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Admission ID (UUID)
 * @bodyParams {string} [facility_id] - Destination facility ID (UUID)
 * @bodyParams {string} [notes] - Transfer notes
 * @returns {Object} Updated admission
 * @throws 401 Unauthorized
 * @throws 404 Admission not found
 */
router.post(
  '/:id/transfer',
  validateRequest({ params: admissionIdParamsSchema, body: transferAdmissionSchema }),
  authenticate(),
  authorize(IPD_WRITE_SCOPES, 'permission'),
  admissionController.transferAdmission
);

module.exports = router;
