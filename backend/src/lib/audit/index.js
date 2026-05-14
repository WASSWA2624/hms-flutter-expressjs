/**
 * Audit utilities barrel export
 * 
 * @description Centralized exports for audit helpers. Allows importing `@lib/audit`.
 * Per prisma.mdc and compliance.mdc: All mutations must create audit logs.
 */

const { createAuditLog } = require('@lib/audit/createAuditLog');

module.exports = {
  createAuditLog
};

