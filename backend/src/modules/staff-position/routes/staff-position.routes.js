const express = require('express');
const router = express.Router();
const staffPositionController = require('@controllers/staff-position/staff-position.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  createStaffPositionSchema,
  updateStaffPositionSchema,
  staffPositionIdParamsSchema,
  listStaffPositionsQuerySchema,
} = require('@validations/staff-position/staff-position.schema');

const HR_READ_SCOPES = [PERMISSIONS.HR_READ];
const HR_WRITE_SCOPES = [PERMISSIONS.HR_WRITE];

router.get('/', validateRequest({ query: listStaffPositionsQuerySchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), staffPositionController.listStaffPositions);
router.get('/:id', validateRequest({ params: staffPositionIdParamsSchema }), authenticate(), authorize(HR_READ_SCOPES, 'permission'), staffPositionController.getStaffPositionById);
router.post('/', validateRequest({ body: createStaffPositionSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffPositionController.createStaffPosition);
router.put('/:id', validateRequest({ params: staffPositionIdParamsSchema, body: updateStaffPositionSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffPositionController.updateStaffPosition);
router.delete('/:id', validateRequest({ params: staffPositionIdParamsSchema }), authenticate(), authorize(HR_WRITE_SCOPES, 'permission'), staffPositionController.deleteStaffPosition);

module.exports = router;
