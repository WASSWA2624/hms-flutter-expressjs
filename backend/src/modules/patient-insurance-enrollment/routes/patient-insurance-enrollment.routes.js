/**
 * Patient Insurance Enrollment routes
 *
 * @module modules/patient-insurance-enrollment/routes
 * @description Patient Insurance Enrollment endpoints mounted at /api/v1/patient-insurance-enrollments
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const patientInsuranceEnrollmentController = require('@controllers/patient-insurance-enrollment/patient-insurance-enrollment.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createPatientInsuranceEnrollmentSchema,
  updatePatientInsuranceEnrollmentSchema,
  patientInsuranceEnrollmentIdParamsSchema,
  listPatientInsuranceEnrollmentsQuerySchema
} = require('@validations/patient-insurance-enrollment/patient-insurance-enrollment.schema');

/**
 * @description List patient insurance enrollments with pagination and filters
 * @method GET
 * @route /api/v1/patient-insurance-enrollments/
 * @authentication Required (JWT)
 * @permissions BILLING_READ
 */
router.get(
  '/',
  validateRequest({ query: listPatientInsuranceEnrollmentsQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  patientInsuranceEnrollmentController.listPatientInsuranceEnrollments
);

/**
 * @description Get patient insurance enrollment by ID
 * @method GET
 * @route /api/v1/patient-insurance-enrollments/:id
 * @authentication Required (JWT)
 * @permissions BILLING_READ
 */
router.get(
  '/:id',
  validateRequest({ params: patientInsuranceEnrollmentIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_READ, 'permission'),
  patientInsuranceEnrollmentController.getPatientInsuranceEnrollmentById
);

/**
 * @description Create new patient insurance enrollment
 * @method POST
 * @route /api/v1/patient-insurance-enrollments/
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.post(
  '/',
  validateRequest({ body: createPatientInsuranceEnrollmentSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  patientInsuranceEnrollmentController.createPatientInsuranceEnrollment
);

/**
 * @description Verify enrollment eligibility via insurer adapter
 * @method POST
 * @route /api/v1/patient-insurance-enrollments/:id/verify
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.post(
  '/:id/verify',
  validateRequest({ params: patientInsuranceEnrollmentIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  patientInsuranceEnrollmentController.verifyPatientInsuranceEnrollment
);

/**
 * @description Update patient insurance enrollment
 * @method PUT
 * @route /api/v1/patient-insurance-enrollments/:id
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.put(
  '/:id',
  validateRequest({
    params: patientInsuranceEnrollmentIdParamsSchema,
    body: updatePatientInsuranceEnrollmentSchema
  }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  patientInsuranceEnrollmentController.updatePatientInsuranceEnrollment
);

/**
 * @description Delete patient insurance enrollment (soft delete)
 * @method DELETE
 * @route /api/v1/patient-insurance-enrollments/:id
 * @authentication Required (JWT)
 * @permissions BILLING_WRITE
 */
router.delete(
  '/:id',
  validateRequest({ params: patientInsuranceEnrollmentIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.BILLING_WRITE, 'permission'),
  patientInsuranceEnrollmentController.deletePatientInsuranceEnrollment
);

module.exports = router;
