/**
 * Appointment participant routes
 *
 * @module modules/appointment-participant/routes
 * @description Appointment participant endpoints mounted at /api/v1/appointment-participants
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const appointmentParticipantController = require('@controllers/appointment-participant/appointment-participant.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createAppointmentParticipantSchema,
  updateAppointmentParticipantSchema,
  appointmentParticipantIdParamsSchema,
  listAppointmentParticipantsQuerySchema
} = require('@validations/appointment-participant/appointment-participant.schema');

const SCHEDULING_READ_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.RECEPTIONIST,
  ROLES.OPERATIONS,
  ROLES.HR,
];
const SCHEDULING_WRITE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
  ROLES.RECEPTIONIST,
  ROLES.OPERATIONS,
  ROLES.HR,
];
const SCHEDULING_DELETE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.OPERATIONS,
  ROLES.HR,
];

/**
 * @description List appointment participants with pagination and filters
 * @method GET
 * @route /api/v1/appointment-participants/
 */
router.get(
  '/',  validateRequest({ query: listAppointmentParticipantsQuerySchema }),

  authenticate(),
  authorize(SCHEDULING_READ_ROLES, 'role'),
  appointmentParticipantController.listAppointmentParticipants
);

/**
 * @description Get appointment participant by ID
 * @method GET
 * @route /api/v1/appointment-participants/:id
 */
router.get(
  '/:id',  validateRequest({ params: appointmentParticipantIdParamsSchema }),

  authenticate(),
  authorize(SCHEDULING_READ_ROLES, 'role'),
  appointmentParticipantController.getAppointmentParticipantById
);

/**
 * @description Create new appointment participant
 * @method POST
 * @route /api/v1/appointment-participants/
 */
router.post(
  '/',  validateRequest({ body: createAppointmentParticipantSchema }),

  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  appointmentParticipantController.createAppointmentParticipant
);

/**
 * @description Update appointment participant
 * @method PUT
 * @route /api/v1/appointment-participants/:id
 */
router.put(
  '/:id',  validateRequest({ params: appointmentParticipantIdParamsSchema, body: updateAppointmentParticipantSchema }),

  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  appointmentParticipantController.updateAppointmentParticipant
);

/**
 * @description Delete appointment participant (soft delete)
 * @method DELETE
 * @route /api/v1/appointment-participants/:id
 */
router.delete(
  '/:id',  validateRequest({ params: appointmentParticipantIdParamsSchema }),

  authenticate(),
  authorize(SCHEDULING_DELETE_ROLES, 'role'),
  appointmentParticipantController.deleteAppointmentParticipant
);

module.exports = router;
