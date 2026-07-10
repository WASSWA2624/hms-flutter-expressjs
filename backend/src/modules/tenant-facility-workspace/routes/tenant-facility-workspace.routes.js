const express = require('express');
const multer = require('multer');
const { HttpError } = require('@lib/errors');
const { ROLES } = require('@config/roles');
const { isFeatureEnabled } = require('@config/feature-flags');
const { authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const tenantFacilityWorkspaceController = require('@controllers/tenant-facility-workspace/tenant-facility-workspace.controller');
const {
  facilityLogoParamsSchema,
  setupQuerySchema,
} = require('@validations/tenant-facility-workspace/tenant-facility-workspace.schema');

const router = express.Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    files: 1,
    fileSize: 5 * 1024 * 1024,
  },
});

const TENANT_FACILITY_WORKSPACE_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.HR,
];

const requireTenantFacilityWorkspaceV1 = (_req, _res, next) => {
  if (!isFeatureEnabled('tenant_facility_workspace_v1')) {
    return next(new HttpError('errors.tenant_facility.workspace_not_enabled', 404));
  }
  return next();
};

router.use(requireTenantFacilityWorkspaceV1);

router.get(
  '/setup',
  validateRequest({ query: setupQuerySchema }),
  authorize(TENANT_FACILITY_WORKSPACE_ROLES, 'role'),
  tenantFacilityWorkspaceController.getSetup
);

router.post(
  '/facilities/:facilityId/logo',
  upload.single('logo'),
  validateRequest({ params: facilityLogoParamsSchema }),
  authorize(TENANT_FACILITY_WORKSPACE_ROLES, 'role'),
  tenantFacilityWorkspaceController.uploadFacilityLogo
);

router.delete(
  '/facilities/:facilityId/logo',
  validateRequest({ params: facilityLogoParamsSchema }),
  authorize(TENANT_FACILITY_WORKSPACE_ROLES, 'role'),
  tenantFacilityWorkspaceController.deleteFacilityLogo
);

module.exports = router;
