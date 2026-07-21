/**
 * Facility routes
 *
 * @module modules/facility/routes
 * @description Facility endpoints mounted at /api/v1/facilities
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const facilityController = require('@controllers/facility/facility.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createFacilitySchema,
  updateFacilitySchema,
  facilityIdParamsSchema,
  listFacilitiesQuerySchema
} = require('@validations/facility/facility.schema');
const { listQuerySchema } = require('@lib/validation/zod');

const FACILITY_READ_SCOPES = [
  PERMISSIONS.CLINICAL_READ,
  PERMISSIONS.OPERATIONS_READ,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];
const FACILITY_ADMIN_SCOPES = [
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.SYSTEM_ADMIN,
];
const PLATFORM_FACILITY_SCOPES = [PERMISSIONS.SYSTEM_ADMIN];


module.exports = router;
