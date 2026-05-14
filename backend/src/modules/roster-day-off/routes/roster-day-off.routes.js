/**
 * Roster day off routes
 */
const express = require('express');
const router = express.Router();
const rosterDayOffController = require('@controllers/roster-day-off/roster-day-off.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createRosterDayOffSchema,
  updateRosterDayOffSchema,
  rosterDayOffIdParamsSchema,
  listRosterDayOffsQuerySchema
} = require('@validations/roster-day-off/roster-day-off.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

router.get('/', validateRequest({ query: listRosterDayOffsQuerySchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), rosterDayOffController.list);
router.get('/:id', validateRequest({ params: rosterDayOffIdParamsSchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), rosterDayOffController.getById);
router.post('/', validateRequest({ body: createRosterDayOffSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), rosterDayOffController.create);
router.put('/:id', validateRequest({ params: rosterDayOffIdParamsSchema, body: updateRosterDayOffSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), rosterDayOffController.update);
router.delete('/:id', validateRequest({ params: rosterDayOffIdParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), rosterDayOffController.remove);

module.exports = router;

