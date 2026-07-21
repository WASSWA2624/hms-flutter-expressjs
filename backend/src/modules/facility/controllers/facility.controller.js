/**
 * Facility controller
 *
 * @module modules/facility/controllers
 * @description Handles HTTP requests for facility endpoints.
 * Per module-creation.mdc: All methods must use asyncHandler.
 * Per module-creation.mdc: Use response helpers from @lib/response.
 */

const facilityService = require('@services/facility/facility.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
);

module.exports = {
  listFacilities,
  getFacilityById,
  createFacility,
  updateFacility,
  deleteFacility,
  restoreFacility,
  permanentDeleteFacility,
  getFacilityBranches
};
