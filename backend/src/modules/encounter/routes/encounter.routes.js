/**
 * Encounter routes
 *
 * @module modules/encounter/routes
 * @description Encounter endpoints mounted at /api/v1/encounters
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const encounterController = require('@controllers/encounter/encounter.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createEncounterSchema,
  updateEncounterSchema,
  encounterIdParamsSchema,
  listEncountersQuerySchema
} = require('@validations/encounter/encounter.schema');

/**
 * @description List encounters with pagination and filters
 * @method GET
 * @route /api/v1/encounters/
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
 * @queryParams {string} [provider_user_id] - Filter by provider user ID (UUID)
 * @queryParams {string} [encounter_type] - Filter by encounter type (OPD, IPD, ICU, THEATRE, EMERGENCY, TELEMEDICINE)
 * @queryParams {string} [status] - Filter by status (OPEN, CLOSED, CANCELLED)
 * @bodyParams None
 * @returns {Object} Paginated list of encounters
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listEncountersQuerySchema }),

  authenticate(),
  encounterController.listEncounters
);

/**
 * @description Get encounter by ID
 * @method GET
 * @route /api/v1/encounters/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Encounter ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Encounter data
 * @throws 401 Unauthorized
 * @throws 404 Encounter not found
 */
router.get(
  '/:id',  validateRequest({ params: encounterIdParamsSchema }),

  authenticate(),
  encounterController.getEncounterById
);

/**
 * @description Create new encounter
 * @method POST
 * @route /api/v1/encounters/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} tenant_id - Tenant ID (required, UUID)
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} patient_id - Patient ID (required, UUID)
 * @bodyParams {string} [provider_user_id] - Provider user ID (UUID)
 * @bodyParams {string} encounter_type - Encounter type (required, OPD/IPD/ICU/THEATRE/EMERGENCY/TELEMEDICINE)
 * @bodyParams {string} status - Status (required, OPEN/CLOSED/CANCELLED)
 * @bodyParams {string} started_at - Start datetime (required, ISO 8601)
 * @bodyParams {string} [ended_at] - End datetime (ISO 8601)
 * @returns {Object} Created encounter
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createEncounterSchema }),

  authenticate(),
  encounterController.createEncounter
);

/**
 * @description Update encounter
 * @method PUT
 * @route /api/v1/encounters/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Encounter ID (UUID)
 * @queryParams None
 * @bodyParams {string} [facility_id] - Facility ID (UUID)
 * @bodyParams {string} [provider_user_id] - Provider user ID (UUID)
 * @bodyParams {string} [encounter_type] - Encounter type (OPD/IPD/ICU/THEATRE/EMERGENCY/TELEMEDICINE)
 * @bodyParams {string} [status] - Status (OPEN/CLOSED/CANCELLED)
 * @bodyParams {string} [started_at] - Start datetime (ISO 8601)
 * @bodyParams {string} [ended_at] - End datetime (ISO 8601)
 * @returns {Object} Updated encounter
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Encounter not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: encounterIdParamsSchema, body: updateEncounterSchema }),

  authenticate(),
  encounterController.updateEncounter
);

/**
 * @description Delete encounter (soft delete)
 * @method DELETE
 * @route /api/v1/encounters/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Encounter ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Encounter not found
 */
router.delete(
  '/:id',  validateRequest({ params: encounterIdParamsSchema }),

  authenticate(),
  encounterController.deleteEncounter
);

module.exports = router;
