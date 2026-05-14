const express = require('express');
const abacPolicyController = require('@controllers/abac-policy/abac-policy.controller');
const { authorize, authenticate } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const { PERMISSIONS } = require('@config/permissions');
const {
  abacPolicyIdParamsSchema,
  createAbacPolicySchema,
  listAbacPoliciesQuerySchema,
  updateAbacPolicySchema,
} = require('@validations/abac-policy/abac-policy.schema');

const router = express.Router();

router.get('/', validateRequest({ query: listAbacPoliciesQuerySchema }), authenticate(), authorize([PERMISSIONS.COMPLIANCE_READ, PERMISSIONS.COMPLIANCE_REVIEW], 'permission'), abacPolicyController.listAbacPolicies);
router.get('/:id', validateRequest({ params: abacPolicyIdParamsSchema }), authenticate(), authorize([PERMISSIONS.COMPLIANCE_READ, PERMISSIONS.COMPLIANCE_REVIEW], 'permission'), abacPolicyController.getAbacPolicyById);
router.post('/', validateRequest({ body: createAbacPolicySchema }), authenticate(), authorize(PERMISSIONS.COMPLIANCE_REVIEW, 'permission'), abacPolicyController.createAbacPolicy);
router.put('/:id', validateRequest({ params: abacPolicyIdParamsSchema, body: updateAbacPolicySchema }), authenticate(), authorize(PERMISSIONS.COMPLIANCE_REVIEW, 'permission'), abacPolicyController.updateAbacPolicy);
router.delete('/:id', validateRequest({ params: abacPolicyIdParamsSchema }), authenticate(), authorize(PERMISSIONS.COMPLIANCE_REVIEW, 'permission'), abacPolicyController.deleteAbacPolicy);

module.exports = router;
