const express = require('express');
const multer = require('multer');
const { HttpError } = require('@lib/errors');
const { PERMISSIONS } = require('@config/permissions');
const { isFeatureEnabled } = require('@config/feature-flags');
const { authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const tenantFacilityWorkspaceController = require('@controllers/tenant-facility-workspace/tenant-facility-workspace.controller');
const {
  facilityLogoParamsSchema,
  setupQuerySchema} = require('@validations/tenant-facility-workspace/tenant-facility-workspace.schema');

const router = express.Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    files: 1,
    fileSize: 5 * 1024 * 1024}});

// Permission RBAC so custom roles with facility:admin / tenant:admin / hr:* work
// (canonical FACILITY_ADMIN role name is not required).
const TENANT_FACILITY_WORKSPACE_SCOPES = [
  PERMISSIONS.PLATFORM_ADMIN,
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.HR_READ,
  PERMISSIONS.HR_WRITE,
];

/**
 * Read-only setup (facility identity + contacts) powers printed document headers.
 * Operational roles that print invoices/clinical docs must reach this without
 * facility-admin privileges. Mutations (logo upload/delete) stay admin/HR only.
 */
const TENANT_FACILITY_SETUP_READ_SCOPES = [
  ...TENANT_FACILITY_WORKSPACE_SCOPES,
  PERMISSIONS.BILLING_READ,
  PERMISSIONS.CLINICAL_READ,
  PERMISSIONS.PHARMACY_READ,
  PERMISSIONS.LAB_READ,
  PERMISSIONS.RADIOLOGY_READ,
  PERMISSIONS.PATIENT_READ,
  PERMISSIONS.PATIENTS_READ,
  PERMISSIONS.REPORTS_READ,
  PERMISSIONS.OPERATIONS_READ,
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
  authorize(TENANT_FACILITY_SETUP_READ_SCOPES, 'permission'),
  tenantFacilityWorkspaceController.getSetup
);

router.post(
  '/facilities/:facilityId/logo',
  upload.single('logo'),
  validateRequest({ params: facilityLogoParamsSchema }),
  authorize(TENANT_FACILITY_WORKSPACE_SCOPES, 'permission'),
  tenantFacilityWorkspaceController.uploadFacilityLogo
);

router.delete(
  '/facilities/:facilityId/logo',
  validateRequest({ params: facilityLogoParamsSchema }),
  authorize(TENANT_FACILITY_WORKSPACE_SCOPES, 'permission'),
  tenantFacilityWorkspaceController.deleteFacilityLogo
);

module.exports = router;
