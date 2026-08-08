const { ROLES } = require('@config/roles');
const { PERMISSIONS } = require('@config/permissions');

const HR_FACILITY_SETUP_MODULE_IDS = Object.freeze([
  'user',
  'role',
  'permission',
  'role-permission',
  'user-role',
  'user-profile',
]);

const ADMIN_SETUP_ROLES = Object.freeze([
  ROLES.PLATFORM_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
]);

const ADMIN_SETUP_PERMISSIONS = Object.freeze([
  PERMISSIONS.TENANT_ADMIN,
  PERMISSIONS.FACILITY_ADMIN,
  PERMISSIONS.PLATFORM_ADMIN,
]);

const HR_SETUP_READ_PERMISSIONS = Object.freeze([
  PERMISSIONS.HR_READ,
  PERMISSIONS.HR_WRITE,
]);

const HR_SETUP_WRITE_PERMISSIONS = Object.freeze([
  PERMISSIONS.HR_WRITE,
  PERMISSIONS.UNIT_MANAGE,
]);

const text = (value) => String(value || '').trim();

const roleList = (user = {}) => {
  const roles = Array.isArray(user.roles) ? user.roles : [user.role];
  return roles
    .map((entry) => text(entry).toUpperCase())
    .filter(Boolean);
};

const permissionList = (user = {}) => {
  const permissions = Array.isArray(user.permissions) ? user.permissions : [];
  return permissions
    .map((entry) => text(entry).toLowerCase())
    .filter(Boolean);
};

const hasAnyPermission = (user = {}, required = []) => {
  const granted = new Set(permissionList(user));
  return required.some((entry) => granted.has(String(entry).toLowerCase()));
};

const isAdminSetupUser = (user = {}) =>
  roleList(user).some((entry) => ADMIN_SETUP_ROLES.includes(entry)) ||
  hasAnyPermission(user, ADMIN_SETUP_PERMISSIONS);

const canAccessHrFacilitySetup = (user = {}) =>
  hasAnyPermission(user, HR_SETUP_READ_PERMISSIONS);

const canWriteHrFacilitySetup = (user = {}) =>
  hasAnyPermission(user, HR_SETUP_WRITE_PERMISSIONS);

const isHrSetupOnlyUser = (user = {}) =>
  canAccessHrFacilitySetup(user) && !isAdminSetupUser(user);

const canAccessSettingsWorkspace = (user = {}) =>
  isAdminSetupUser(user) || canAccessHrFacilitySetup(user);

const filterSetupModulesForUser = (modules = [], user = {}) => {
  if (!isHrSetupOnlyUser(user)) {
    return modules;
  }

  return modules.filter((entry) => HR_FACILITY_SETUP_MODULE_IDS.includes(entry.id));
};

const canWriteSetupModule = (user = {}, moduleId = '') => {
  if (isAdminSetupUser(user)) {
    return true;
  }

  return (
    canWriteHrFacilitySetup(user) &&
    HR_FACILITY_SETUP_MODULE_IDS.includes(String(moduleId || '').trim())
  );
};

module.exports = {
  HR_FACILITY_SETUP_MODULE_IDS,
  canAccessHrFacilitySetup,
  canAccessSettingsWorkspace,
  canWriteHrFacilitySetup,
  canWriteSetupModule,
  filterSetupModulesForUser,
  isAdminSetupUser,
  isHrSetupOnlyUser,
};
