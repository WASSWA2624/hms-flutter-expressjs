/**
 * OPD flow routes
 *
 * @module modules/opd-flow/routes
 * @description OPD flow orchestration endpoints mounted at /api/v1/opd-flows
 * Per module-creation.mdc: Apply all required middlewares.
 * Per api.mdc: All endpoints must follow REST conventions.
 */

const express = require('express');
const router = express.Router();
const opdFlowController = require('@controllers/opd-flow/opd-flow.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize, denyRoles } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const { ROLES, STAFF_PATIENT_FLOW_DENIED_ROLES } = require('@config/roles');
const {
  createOpdFlowSchema,
  bootstrapOpdFlowSchema,
  encounterIdParamsSchema,
  resolveLegacyRouteParamsSchema,
  payConsultationSchema,
  recordVitalsSchema,
  assignDoctorSchema,
  doctorReviewSchema,
  dispositionSchema,
  correctStageSchema,
  listOpdFlowsQuerySchema
} = require('@validations/opd-flow/opd-flow.schema');

router.use(authenticate(), denyRoles(STAFF_PATIENT_FLOW_DENIED_ROLES));

/**
 * @description List OPD flows with pagination and filters
 * @method GET
 * @route /api/v1/opd-flows/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=started_at] - Sort field
 * @queryParams {string} [order=desc] - Sort order
 * @queryParams {string} [tenant_id] - Tenant filter
 * @queryParams {string} [facility_id] - Facility filter
 * @queryParams {string} [patient_id] - Patient filter
 * @queryParams {string} [provider_user_id] - Provider filter
 * @queryParams {string} [encounter_type] - OPD or EMERGENCY
 * @queryParams {string} [stage] - OPD flow stage
 * @queryParams {string} [search] - Search text
 * @bodyParams None
 * @returns {Object} Paginated OPD flows
 * @throws 401 Unauthorized
 */
router.get(
  '/',
  validateRequest({ query: listOpdFlowsQuerySchema }),
  authenticate(),
  authorize(
    [
      PERMISSIONS.PATIENT_READ,
      PERMISSIONS.CLINICAL_READ,
      PERMISSIONS.BILLING_READ,
      PERMISSIONS.OPERATIONS_READ,
      PERMISSIONS.EMERGENCY_READ
    ],
    'permission'
  ),
  opdFlowController.listOpdFlows
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyRouteParamsSchema }),
  authenticate(),
  authorize(
    [
      PERMISSIONS.PATIENT_READ,
      PERMISSIONS.CLINICAL_READ,
      PERMISSIONS.BILLING_READ,
      PERMISSIONS.OPERATIONS_READ,
      PERMISSIONS.EMERGENCY_READ
    ],
    'permission'
  ),
  opdFlowController.resolveLegacyRoute
);

/**
 * @description Get OPD flow snapshot by encounter ID
 * @method GET
 * @route /api/v1/opd-flows/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Encounter human-friendly ID
 * @queryParams None
 * @bodyParams None
 * @returns {Object} OPD flow snapshot with related records
 * @throws 401 Unauthorized
 * @throws 404 OPD flow not found
 */
router.get(
  '/:id',
  validateRequest({ params: encounterIdParamsSchema }),
  authenticate(),
  authorize(
    [
      PERMISSIONS.PATIENT_READ,
      PERMISSIONS.CLINICAL_READ,
      PERMISSIONS.BILLING_READ,
      PERMISSIONS.OPERATIONS_READ,
      PERMISSIONS.EMERGENCY_READ
    ],
    'permission'
  ),
  opdFlowController.getOpdFlowById
);

/**
 * @description Start OPD flow for walk-in, appointment, or emergency arrival
 * @method POST
 * @route /api/v1/opd-flows/start
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} [tenant_id] - Tenant ID
 * @bodyParams {string} [facility_id] - Facility ID
 * @bodyParams {string} [patient_id] - Existing patient ID
 * @bodyParams {Object} [patient_registration] - New patient registration payload
 * @bodyParams {string} [arrival_mode] - WALK_IN, ONLINE_APPOINTMENT, or EMERGENCY
 * @bodyParams {string} [appointment_id] - Appointment ID for online flow
 * @bodyParams {string} [provider_user_id] - Provider assignment hint
 * @bodyParams {string} [consultation_fee] - Consultation fee amount
 * @bodyParams {string} [currency] - Currency code
 * @bodyParams {boolean} [create_consultation_invoice] - Whether to create consultation invoice
 * @bodyParams {boolean} [require_consultation_payment] - Whether consultation payment is required
 * @bodyParams {boolean} [reuse_open_encounter] - Return an existing open OPD encounter instead of duplicating it
 * @bodyParams {Object} [pay_now] - Optional immediate payment payload
 * @bodyParams {Object} [emergency] - Emergency context payload
 * @bodyParams {string} [notes] - Notes
 * @bodyParams {string} [queued_at] - Queue time (ISO datetime)
 * @returns {Object} Created OPD flow snapshot
 * @throws 401 Unauthorized
 * @throws 400 Validation or transition error
 */
router.post(
  '/start',
  validateRequest({ body: createOpdFlowSchema }),
  authenticate(),
  authorize(
    [
      PERMISSIONS.PATIENT_WRITE,
      PERMISSIONS.CLINICAL_WRITE,
      PERMISSIONS.OPERATIONS_WRITE,
      PERMISSIONS.EMERGENCY_WRITE
    ],
    'permission'
  ),
  opdFlowController.startOpdFlow
);

/**
 * @description Bootstrap OPD/Clinical flow context for a patient and optionally reuse existing open encounter
 * @method POST
 * @route /api/v1/opd-flows/bootstrap
 * @authentication Required (JWT)
 * @permissions Clinical users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} patient_id - Patient ID (required)
 * @bodyParams {string} [facility_id] - Facility ID
 * @bodyParams {string} [provider_user_id] - Provider user ID
 * @bodyParams {string} [encounter_type=OPD] - OPD or EMERGENCY
 * @bodyParams {boolean} [reuse_open_encounter=true] - Reuse existing open encounter for patient/type
 * @returns {Object} OPD flow snapshot
 */
router.post(
  '/bootstrap',
  validateRequest({ body: bootstrapOpdFlowSchema }),
  authenticate(),
  authorize(
    [
      ROLES.SUPER_ADMIN,
      ROLES.TENANT_ADMIN,
      ROLES.FACILITY_ADMIN,
      ROLES.RECEPTIONIST,
      ROLES.NURSE,
      ROLES.DOCTOR,
      ROLES.OPERATIONS
    ],
    'role'
  ),
  opdFlowController.bootstrapOpdFlow
);

/**
 * @description Record consultation payment for an OPD flow
 * @method POST
 * @route /api/v1/opd-flows/:id/pay-consultation
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Encounter human-friendly ID
 * @queryParams None
 * @bodyParams {string} [invoice_id] - Existing invoice ID
 * @bodyParams {string} [amount] - Payment amount
 * @bodyParams {string} [currency] - Currency code
 * @bodyParams {string} method - Payment method
 * @bodyParams {string} [status] - Payment status
 * @bodyParams {string} [transaction_ref] - Transaction reference
 * @bodyParams {string} [paid_at] - Payment timestamp (ISO datetime)
 * @bodyParams {string} [notes] - Notes
 * @returns {Object} Updated OPD flow snapshot
 * @throws 401 Unauthorized
 * @throws 404 OPD flow or invoice not found
 */
router.post(
  '/:id/pay-consultation',
  validateRequest({ params: encounterIdParamsSchema, body: payConsultationSchema }),
  authenticate(),
  authorize(
    [
      ROLES.SUPER_ADMIN,
      ROLES.TENANT_ADMIN,
      ROLES.FACILITY_ADMIN,
      ROLES.RECEPTIONIST,
      ROLES.BILLING
    ],
    'role'
  ),
  opdFlowController.payConsultation
);

/**
 * @description Record patient vitals and optional triage update
 * @method POST
 * @route /api/v1/opd-flows/:id/record-vitals
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Encounter human-friendly ID
 * @queryParams None
 * @bodyParams {Array} vitals - Vital sign entries
 * @bodyParams {string} [triage_level] - Triage level or accepted alias
 * @bodyParams {string} [triage_notes] - Triage notes
 * @returns {Object} Updated OPD flow snapshot
 * @throws 401 Unauthorized
 * @throws 400 Stage or payment guard violation
 */
router.post(
  '/:id/record-vitals',
  validateRequest({ params: encounterIdParamsSchema, body: recordVitalsSchema }),
  authenticate(),
  authorize(
    [ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN, ROLES.DOCTOR, ROLES.NURSE],
    'role'
  ),
  opdFlowController.recordVitals
);

/**
 * @description Assign doctor for OPD encounter
 * @method POST
 * @route /api/v1/opd-flows/:id/assign-doctor
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Encounter human-friendly ID
 * @queryParams None
 * @bodyParams {string} provider_user_id - Provider user ID
 * @returns {Object} Updated OPD flow snapshot
 * @throws 401 Unauthorized
 * @throws 400 Invalid stage transition
 */
router.post(
  '/:id/assign-doctor',
  validateRequest({ params: encounterIdParamsSchema, body: assignDoctorSchema }),
  authenticate(),
  authorize(
    [ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN, ROLES.RECEPTIONIST, ROLES.NURSE],
    'role'
  ),
  opdFlowController.assignDoctor
);

/**
 * @description Record doctor review and create downstream orders
 * @method POST
 * @route /api/v1/opd-flows/:id/doctor-review
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Encounter human-friendly ID
 * @queryParams None
 * @bodyParams {string} note - Clinical note
 * @bodyParams {Array} [diagnoses] - Diagnosis entries
 * @bodyParams {Array} [procedures] - Procedure entries
 * @bodyParams {Array} [lab_requests] - Lab request entries
 * @bodyParams {Array} [radiology_requests] - Radiology request entries
 * @bodyParams {Array} [medications] - Medication order items
 * @bodyParams {string} [notes] - Additional notes
 * @returns {Object} Updated OPD flow snapshot
 * @throws 401 Unauthorized
 * @throws 400 Invalid stage transition
 */
router.post(
  '/:id/doctor-review',
  validateRequest({ params: encounterIdParamsSchema, body: doctorReviewSchema }),
  authenticate(),
  authorize([ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN, ROLES.DOCTOR], 'role'),
  opdFlowController.doctorReview
);

/**
 * @description Apply terminal OPD disposition and close encounter
 * @method POST
 * @route /api/v1/opd-flows/:id/disposition
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Encounter human-friendly ID
 * @queryParams None
 * @bodyParams {string} decision - ADMIT, SEND_TO_PHARMACY, or DISCHARGE
 * @bodyParams {string} [admission_facility_id] - Admission facility ID for ADMIT
 * @bodyParams {string} [notes] - Notes
 * @returns {Object} Updated OPD flow snapshot
 * @throws 401 Unauthorized
 * @throws 400 Invalid stage or disposition requirements
 */
router.post(
  '/:id/disposition',
  validateRequest({ params: encounterIdParamsSchema, body: dispositionSchema }),
  authenticate(),
  authorize([ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN, ROLES.DOCTOR], 'role'),
  opdFlowController.disposition
);

/**
 * @description Correct OPD stage progression with optional reason
 * @method POST
 * @route /api/v1/opd-flows/:id/correct-stage
 * @authentication Required (JWT)
 * @permissions Restricted clinical roles
 * @urlParams {string} id - Encounter Friendly ID
 * @queryParams None
 * @bodyParams {string} stage_to - Target stage
 * @bodyParams {string} [reason] - Correction reason
 * @returns {Object} Updated OPD flow snapshot
 * @throws 401 Unauthorized
 * @throws 403 Forbidden
 * @throws 400 Validation error
 */
router.post(
  '/:id/correct-stage',
  validateRequest({ params: encounterIdParamsSchema, body: correctStageSchema }),
  authenticate(),
  authorize(
    [ROLES.SUPER_ADMIN, ROLES.TENANT_ADMIN, ROLES.FACILITY_ADMIN, ROLES.NURSE, ROLES.DOCTOR],
    'role'
  ),
  opdFlowController.correctStage
);

module.exports = router;
