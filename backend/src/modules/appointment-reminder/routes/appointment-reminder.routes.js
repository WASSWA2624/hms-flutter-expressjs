/**
 * Appointment reminder routes
 */

const express = require('express');
const router = express.Router();
const appointmentReminderController = require('@controllers/appointment-reminder/appointment-reminder.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createAppointmentReminderSchema,
  updateAppointmentReminderSchema,
  markAppointmentReminderSentSchema,
  appointmentReminderIdParamsSchema,
  listAppointmentRemindersQuerySchema
} = require('@validations/appointment-reminder/appointment-reminder.schema');

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

router.get(
  '/',  validateRequest({ query: listAppointmentRemindersQuerySchema }),

  authenticate(),
  authorize(SCHEDULING_READ_ROLES, 'role'),
  appointmentReminderController.listAppointmentReminders
);

router.get(
  '/:id',  validateRequest({ params: appointmentReminderIdParamsSchema }),

  authenticate(),
  authorize(SCHEDULING_READ_ROLES, 'role'),
  appointmentReminderController.getAppointmentReminderById
);

router.post(
  '/',  validateRequest({ body: createAppointmentReminderSchema }),

  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  appointmentReminderController.createAppointmentReminder
);

router.put(
  '/:id',  validateRequest({ params: appointmentReminderIdParamsSchema, body: updateAppointmentReminderSchema }),

  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  appointmentReminderController.updateAppointmentReminder
);

router.delete(
  '/:id',  validateRequest({ params: appointmentReminderIdParamsSchema }),

  authenticate(),
  authorize(SCHEDULING_DELETE_ROLES, 'role'),
  appointmentReminderController.deleteAppointmentReminder
);

router.post(
  '/:id/mark-sent',  validateRequest({ params: appointmentReminderIdParamsSchema, body: markAppointmentReminderSentSchema }),

  authenticate(),
  authorize(SCHEDULING_WRITE_ROLES, 'role'),
  appointmentReminderController.markAppointmentReminderSent
);

module.exports = router;
