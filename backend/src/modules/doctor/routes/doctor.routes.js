/**
 * Doctor orchestration routes
 *
 * @module modules/doctor/routes
 */

const express = require('express');
const router = express.Router();
const doctorController = require('@controllers/doctor/doctor.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { ROLES } = require('@config/roles');
const {
  createDoctorSchema,
  updateDoctorSchema,
  doctorIdParamsSchema,
  listDoctorsQuerySchema,
} = require('@validations/doctor/doctor.schema');

const DOCTOR_ADMIN_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.HR,
];

router.get(
  '/',
  validateRequest({ query: listDoctorsQuerySchema }),
  authenticate(),
  authorize(DOCTOR_ADMIN_ROLES, 'role'),
  doctorController.listDoctors
);

router.get(
  '/:id',
  validateRequest({ params: doctorIdParamsSchema }),
  authenticate(),
  authorize(DOCTOR_ADMIN_ROLES, 'role'),
  doctorController.getDoctorById
);

router.post(
  '/',
  validateRequest({ body: createDoctorSchema }),
  authenticate(),
  authorize(DOCTOR_ADMIN_ROLES, 'role'),
  doctorController.createDoctor
);

router.put(
  '/:id',
  validateRequest({ params: doctorIdParamsSchema, body: updateDoctorSchema }),
  authenticate(),
  authorize(DOCTOR_ADMIN_ROLES, 'role'),
  doctorController.updateDoctor
);

module.exports = router;

