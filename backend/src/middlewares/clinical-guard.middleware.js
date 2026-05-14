/**
 * Clinical workflow guard middleware
 *
 * Protects append-first workflows by blocking destructive delete actions for doctor roles,
 * while allowing administrative roles to perform cleanup operations.
 */

const { HttpError } = require('@lib/errors');
const { ROLES, normalizeRoleName } = require('@config/roles');

const ADMIN_ROLES = new Set([
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
]);

const DOCTOR_ROLES = new Set([ROLES.DOCTOR]);

const normalizeRoles = (user = {}) => {
  const rawRoles = Array.isArray(user.roles)
    ? user.roles
    : user.role
      ? [user.role]
      : [];

  return rawRoles
    .map((role) => normalizeRoleName(role) || String(role || '').trim().toUpperCase())
    .filter(Boolean);
};

const requireClinicalDeletePrivilege = () => (req, _res, next) => {
  try {
    const roles = normalizeRoles(req.user);
    const hasAdminRole = roles.some((role) => ADMIN_ROLES.has(role));
    const hasDoctorRole = roles.some((role) => DOCTOR_ROLES.has(role));

    if (hasDoctorRole && !hasAdminRole) {
      return next(new HttpError('errors.auth.insufficient_permissions', 403));
    }

    return next();
  } catch (error) {
    return next(error);
  }
};

module.exports = {
  requireClinicalDeletePrivilege,
};
