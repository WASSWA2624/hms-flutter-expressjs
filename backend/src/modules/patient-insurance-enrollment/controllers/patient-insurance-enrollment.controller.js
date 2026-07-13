/**
 * Patient Insurance Enrollment controller
 *
 * @module modules/patient-insurance-enrollment/controllers
 * @description Request handlers for patient insurance enrollment endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const patientInsuranceEnrollmentService = require('@services/patient-insurance-enrollment/patient-insurance-enrollment.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

/**
 * List patient insurance enrollments with pagination
 * GET /api/v1/patient-insurance-enrollments
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listPatientInsuranceEnrollments = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    patient_id,
    member_id,
    status,
    coverage_plan_id,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    patient_id,
    member_id,
    status,
    coverage_plan_id,
    search
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await patientInsuranceEnrollmentService.listPatientInsuranceEnrollments(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(
    res,
    'messages.patient_insurance_enrollment.list.success',
    result.enrollments,
    result.pagination
  );
});

/**
 * Get patient insurance enrollment by ID
 * GET /api/v1/patient-insurance-enrollments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getPatientInsuranceEnrollmentById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const enrollment = await patientInsuranceEnrollmentService.getPatientInsuranceEnrollmentById(
    id,
    userId,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.patient_insurance_enrollment.get.success', enrollment);
});

/**
 * Create new patient insurance enrollment
 * POST /api/v1/patient-insurance-enrollments
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createPatientInsuranceEnrollment = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const enrollment = await patientInsuranceEnrollmentService.createPatientInsuranceEnrollment(
    req.body,
    userId,
    ipAddress
  );

  sendSuccess(res, 201, 'messages.patient_insurance_enrollment.create.success', enrollment);
});

/**
 * Update patient insurance enrollment
 * PUT /api/v1/patient-insurance-enrollments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updatePatientInsuranceEnrollment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const enrollment = await patientInsuranceEnrollmentService.updatePatientInsuranceEnrollment(
    id,
    req.body,
    userId,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.patient_insurance_enrollment.update.success', enrollment);
});

/**
 * Delete patient insurance enrollment (soft delete)
 * DELETE /api/v1/patient-insurance-enrollments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deletePatientInsuranceEnrollment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await patientInsuranceEnrollmentService.deletePatientInsuranceEnrollment(id, userId, ipAddress);

  sendNoContent(res);
});

/**
 * Verify enrollment eligibility via insurer adapter
 * POST /api/v1/patient-insurance-enrollments/:id/verify
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const verifyPatientInsuranceEnrollment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await patientInsuranceEnrollmentService.verifyPatientInsuranceEnrollment(
    id,
    req.body || {},
    userId,
    ipAddress
  );

  sendSuccess(res, 200, 'messages.patient_insurance_enrollment.verify.success', result);
});

module.exports = {
  listPatientInsuranceEnrollments,
  getPatientInsuranceEnrollmentById,
  createPatientInsuranceEnrollment,
  updatePatientInsuranceEnrollment,
  deletePatientInsuranceEnrollment,
  verifyPatientInsuranceEnrollment
};
