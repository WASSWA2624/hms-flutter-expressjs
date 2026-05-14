/**
 * Reusable Zod Validators
 * 
 * Shared validation utilities for use across all module schemas
 * Per validation.mdc: Reusable validators must live in src/lib/validation/zod.js
 * All module schemas should import from @lib/validation/zod
 * 
 * These validators follow snake_case naming convention for consistency with DB
 */

const { z } = require('zod');
const { SUPPORTED_LOCALES, DEFAULT_PAGE, DEFAULT_PAGE_LIMIT, MAX_PAGE_LIMIT } = require('@config/constants');

const FRIENDLY_IDENTIFIER_REGEX = /^(?=.*\d)[A-Za-z][A-Za-z0-9_-]*$/;

/**
 * Email validation
 * Validates email format
 */
const emailSchema = z.string()
  .email('Invalid email format')
  .toLowerCase()
  .trim();

/**
 * UUID validation
 * Validates UUID v4 format
 */
const uuidSchema = z.string()
  .uuid('Invalid UUID format');

const friendlyIdentifierSchema = z.string()
  .trim()
  .min(2, 'Identifier must be at least 2 characters')
  .max(64, 'Identifier must be at most 64 characters')
  .regex(FRIENDLY_IDENTIFIER_REGEX, 'Invalid identifier format')
  .transform((value) => value.toUpperCase());

const uuidOrFriendlyIdentifierSchema = z.union([uuidSchema, friendlyIdentifierSchema]);

/**
 * Phone number validation
 * Validates international phone number format (basic)
 * Allows digits, spaces, dashes, parentheses, and + prefix
 */
const phoneSchema = z.string()
  .regex(/^\+?[\d\s\-()]+$/, 'Invalid phone number format')
  .min(10, 'Phone number must be at least 10 digits')
  .max(20, 'Phone number must be at most 20 characters')
  .trim();

/**
 * URL validation
 * Validates URL format
 */
const urlSchema = z.string()
  .url('Invalid URL format')
  .trim();

/**
 * Password validation
 * Minimum 8 characters, must include uppercase, lowercase, number, and symbol
 */
const passwordSchema = z.string()
  .min(8, 'Password must be at least 8 characters long')
  .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
  .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
  .regex(/[0-9]/, 'Password must contain at least one number')
  .regex(/[^A-Za-z0-9]/, 'Password must contain at least one symbol');

/**
 * Positive integer validation
 * Validates positive integers (greater than 0)
 */
const positiveIntSchema = z.number()
  .int('Must be an integer')
  .positive('Must be a positive number');

/**
 * Non-negative integer validation
 * Validates non-negative integers (0 or greater)
 */
const nonNegativeIntSchema = z.number()
  .int('Must be an integer')
  .nonnegative('Must be a non-negative number');

/**
 * Pagination page validation
 * Validates page number (must be positive integer, default: 1)
 */
const pageSchema = z.coerce.number()
  .int('Page must be an integer')
  .positive('Page must be a positive number')
  .default(DEFAULT_PAGE);

/**
 * Pagination limit validation
 * Validates limit per page (must be positive integer, default: 20, max: 100)
 */
const limitSchema = z.coerce.number()
  .int('Limit must be an integer')
  .positive('Limit must be a positive number')
  .max(MAX_PAGE_LIMIT, `Limit cannot exceed ${MAX_PAGE_LIMIT}`)
  .default(DEFAULT_PAGE_LIMIT);

/**
 * Sort order validation
 * Validates sort order (asc or desc)
 */
const sortOrderSchema = z.enum(['asc', 'desc'], {
  errorMap: () => ({ message: 'Sort order must be "asc" or "desc"' })
}).default('asc');

/**
 * ISO date string validation
 * Validates ISO 8601 date format
 */
const isoDateSchema = z.string()
  .datetime('Invalid date format. Must be ISO 8601 format')
  .or(z.date());

/**
 * Date string validation (YYYY-MM-DD)
 * Validates date in YYYY-MM-DD format
 */
const dateStringSchema = z.string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format');

/**
 * Timestamp validation
 * Validates Unix timestamp (number or string)
 */
const timestampSchema = z.union([
  z.number().int().positive(),
  z.string().regex(/^\d+$/, 'Timestamp must be a numeric string').transform(Number)
]);

/**
 * Non-empty string validation
 * Validates string is not empty after trimming
 */
const nonEmptyStringSchema = z.string()
  .trim()
  .min(1, 'String cannot be empty');

/**
 * Optional non-empty string validation
 * Allows undefined/null or non-empty string
 */
const optionalNonEmptyStringSchema = z.string()
  .trim()
  .min(1, 'String cannot be empty')
  .optional();

/**
 * Slug validation
 * Validates URL-friendly slug format (lowercase, alphanumeric, hyphens, underscores)
 */
const slugSchema = z.string()
  .regex(/^[a-z0-9_-]+$/, 'Slug must contain only lowercase letters, numbers, hyphens, and underscores')
  .min(1, 'Slug cannot be empty')
  .max(100, 'Slug cannot exceed 100 characters')
  .toLowerCase()
  .trim();

/**
 * Currency amount validation
 * Validates positive decimal number (for money amounts)
 */
const currencySchema = z.number()
  .positive('Amount must be positive')
  .multipleOf(0.01, 'Amount must have at most 2 decimal places');

/**
 * Decimal string validation
 * Validates decimal number as string (for Prisma Decimal fields)
 * Accepts formats like: "123", "123.45", "0.99"
 */
const decimalStringSchema = z.string()
  .regex(/^\d+(\.\d{1,2})?$/, 'Must be a valid decimal number with up to 2 decimal places')
  .trim();

/**
 * Percentage validation
 * Validates percentage value (0-100)
 */
const percentageSchema = z.number()
  .min(0, 'Percentage must be at least 0')
  .max(100, 'Percentage cannot exceed 100');

/**
 * Boolean string validation
 * Converts string "true"/"false" to boolean
 */
const booleanStringSchema = z.string()
  .toLowerCase()
  .transform((val) => val === 'true')
  .pipe(z.boolean());

/**
 * ID parameter validation
 * Common schema for URL parameter IDs (UUID or integer)
 */
const idParamSchema = z.object({
  id: z.union([
    uuidSchema,
    z.string().regex(/^\d+$/, 'ID must be UUID or numeric string').transform(Number)
  ])
});

/**
 * Pagination query validation
 * Common schema for pagination query parameters
 */
const paginationQuerySchema = z.object({
  page: pageSchema.optional(),
  limit: limitSchema.optional()
});

/**
 * Sort query validation
 * Common schema for sorting query parameters
 */
const sortQuerySchema = z.object({
  sort_by: z.string().optional(),
  order: sortOrderSchema.optional()
});

/**
 * Combined pagination and sort query validation
 * Common schema for list endpoints with pagination and sorting
 */
const listQuerySchema = paginationQuerySchema.merge(sortQuerySchema);

/**
 * Locale validation
 * Validates locale format and supported locales
 */
const localeSchema = z.string()
  .regex(/^[a-z]{2,3}(-[A-Z]{2})?$/, 'Invalid locale format')
  .refine((value) => {
    const base = value.split('-')[0];
    return SUPPORTED_LOCALES.includes(value) || SUPPORTED_LOCALES.includes(base);
  }, { message: 'Unsupported locale' });

module.exports = {
  // Basic validators
  emailSchema,
  uuidSchema,
  friendlyIdentifierSchema,
  uuidOrFriendlyIdentifierSchema,
  phoneSchema,
  urlSchema,
  passwordSchema,
  
  // Number validators
  positiveIntSchema,
  nonNegativeIntSchema,
  currencySchema,
  decimalStringSchema,
  percentageSchema,
  
  // Pagination validators
  pageSchema,
  limitSchema,
  paginationQuerySchema,
  
  // Sort validators
  sortOrderSchema,
  sortQuerySchema,
  
  // Date validators
  isoDateSchema,
  dateStringSchema,
  timestampSchema,
  
  // String validators
  nonEmptyStringSchema,
  optionalNonEmptyStringSchema,
  slugSchema,
  
  // Type conversion validators
  booleanStringSchema,
  
  // Combined schemas
  idParamSchema,
  listQuerySchema,
  localeSchema
};

