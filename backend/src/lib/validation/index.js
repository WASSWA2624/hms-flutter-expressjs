/**
 * Validation utilities barrel export
 * 
 * @description Centralized exports for validation helpers. Allows importing `@lib/validation`.
 * Per validation.mdc: All validations must use Zod schemas from this module.
 */

const validationSchemas = require('@lib/validation/zod');

module.exports = {
  ...validationSchemas
};

