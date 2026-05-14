const express = require('express');
const breakGlassAccessController = require('@controllers/break-glass-access/break-glass-access.controller');
const { authorize, authenticate } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  breakGlassAccessIdParamsSchema,
  createBreakGlassAccessSchema,
  listBreakGlassAccessesQuerySchema,
  revokeBreakGlassAccessSchema,
} = require('@validations/break-glass-access/break-glass-access.schema');

const router = express.Router();

router.get('/', validateRequest({ query: listBreakGlassAccessesQuerySchema }), authenticate(), authorize([PERMISSIONS.BREAK_GLASS_REQUEST, PERMISSIONS.BREAK_GLASS_REVIEW, PERMISSIONS.BREAK_GLASS_APPROVE], 'permission'), breakGlassAccessController.listBreakGlassAccesses);
router.get('/:id', validateRequest({ params: breakGlassAccessIdParamsSchema }), authenticate(), authorize([PERMISSIONS.BREAK_GLASS_REQUEST, PERMISSIONS.BREAK_GLASS_REVIEW, PERMISSIONS.BREAK_GLASS_APPROVE], 'permission'), breakGlassAccessController.getBreakGlassAccessById);
router.post('/', validateRequest({ body: createBreakGlassAccessSchema }), authenticate(), authorize(PERMISSIONS.BREAK_GLASS_REQUEST, 'permission'), breakGlassAccessController.createBreakGlassAccess);
router.post('/:id/revoke', validateRequest({ params: breakGlassAccessIdParamsSchema, body: revokeBreakGlassAccessSchema }), authenticate(), authorize([PERMISSIONS.BREAK_GLASS_REQUEST, PERMISSIONS.BREAK_GLASS_REVIEW, PERMISSIONS.BREAK_GLASS_APPROVE], 'permission'), breakGlassAccessController.revokeBreakGlassAccess);

module.exports = router;
