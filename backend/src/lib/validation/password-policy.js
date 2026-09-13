/**
 * Password policy
 *
 * @module lib/validation/password-policy
 * @description The one set of password rules the API enforces wherever a
 * password is chosen: registration, reset, change, and administrator-created
 * accounts. The Flutter client mirrors these rules in
 * `frontend/lib/shared/forms/app_password_policy.dart`; change both together.
 */

const { z } = require('zod');

const PASSWORD_MIN_LENGTH = 8;

/**
 * Apply the password rules to a string schema.
 *
 * Accepts a pre-configured string schema (for example one that trims first) so
 * callers keep their own normalisation while sharing the rules and message keys.
 *
 * @param {import('zod').ZodString} [schema]
 * @returns {import('zod').ZodString}
 */
const applyPasswordPolicy = (schema = z.string()) =>
  schema
    .min(PASSWORD_MIN_LENGTH, 'errors.validation.password.min_length')
    .regex(/[A-Z]/, 'errors.validation.password.uppercase')
    .regex(/[a-z]/, 'errors.validation.password.lowercase')
    .regex(/[0-9]/, 'errors.validation.password.number')
    .regex(/[^A-Za-z0-9]/, 'errors.validation.password.special');

const passwordPolicySchema = applyPasswordPolicy();

module.exports = {
  PASSWORD_MIN_LENGTH,
  applyPasswordPolicy,
  passwordPolicySchema,
};
