/**
 * Auth module validation schemas
 *
 * @module modules/auth/schemas
 * @description Zod validation schemas for authentication endpoints.
 */

const { z } = require('zod');

const phoneSchema = z
  .string()
  .min(10, 'errors.validation.phone.min_length')
  .regex(/^[0-9]+$/, 'errors.validation.phone.format');

const facilityTypeSchema = z.enum(['HOSPITAL', 'CLINIC', 'LAB', 'PHARMACY', 'OTHER']);

// ==================== Identify ====================
const identifyBodySchema = z.object({
  identifier: z.string().min(1, 'errors.validation.field.required')
});

// ==================== Login ====================
const loginBodySchema = z.object({
  email: z.string().email('errors.validation.email.format').toLowerCase().optional(),
  phone: phoneSchema.optional(),
  password: z.string().min(8, 'errors.validation.password.min_length'),
  tenant_id: z.string().uuid('errors.validation.uuid.invalid').optional(),
  facility_id: z.string().uuid('errors.validation.uuid.invalid').optional()
}).refine((data) => Boolean(data.email || data.phone), {
  message: 'errors.validation.login.identifier_required',
  path: ['email']
});

// ==================== Register ====================
const registerBodySchema = z.object({
  email: z.string().email('errors.validation.email.format').toLowerCase(),
  password: z.string()
    .min(8, 'errors.validation.password.min_length')
    .regex(/[A-Z]/, 'errors.validation.password.uppercase')
    .regex(/[a-z]/, 'errors.validation.password.lowercase')
    .regex(/[0-9]/, 'errors.validation.password.number')
    .regex(/[^A-Za-z0-9]/, 'errors.validation.password.special'),
  facility_name: z.string().trim().min(1, 'errors.validation.field.required').max(255),
  admin_name: z.string().trim().min(1, 'errors.validation.field.required').max(255),
  facility_type: facilityTypeSchema,
  phone: phoneSchema.optional(),
  location: z.string().trim().max(255).optional(),
  interests: z.string().trim().max(2000).optional(),
});

// ==================== Verify Email ====================
const verifyEmailBodySchema = z.object({
  token: z.string().min(1, 'errors.validation.token.required'),
  email: z.string().email('errors.validation.email.format').toLowerCase().optional()
});

// ==================== Verify Phone ====================
const verifyPhoneBodySchema = z.object({
  token: z.string().min(1, 'errors.validation.token.required'),
  phone: phoneSchema
});

// ==================== Resend Verification ====================
const resendVerificationBodySchema = z.object({
  email: z.string().email('errors.validation.email.format').toLowerCase().optional(),
  phone: phoneSchema.optional(),
  type: z.enum(['email', 'phone'], { required_error: 'errors.validation.type.invalid' })
});

// ==================== Forgot Password ====================
const forgotPasswordBodySchema = z.object({
  email: z.string().email('errors.validation.email.format').toLowerCase(),
  tenant_id: z.string().uuid('errors.validation.uuid.invalid')
});

// ==================== Reset Password ====================
const resetPasswordBodySchema = z.object({
  token: z.string().min(1, 'errors.validation.token.required'),
  new_password: z.string()
    .min(8, 'errors.validation.password.min_length')
    .regex(/[A-Z]/, 'errors.validation.password.uppercase')
    .regex(/[a-z]/, 'errors.validation.password.lowercase')
    .regex(/[0-9]/, 'errors.validation.password.number')
    .regex(/[^A-Za-z0-9]/, 'errors.validation.password.special'),
  confirm_password: z.string().min(1, 'errors.validation.field.required')
}).refine((data) => data.new_password === data.confirm_password, {
  message: 'errors.validation.password.mismatch',
  path: ['confirm_password']
});

// ==================== Change Password ====================
const changePasswordBodySchema = z.object({
  old_password: z.string().min(1, 'errors.validation.field.required'),
  new_password: z.string()
    .min(8, 'errors.validation.password.min_length')
    .regex(/[A-Z]/, 'errors.validation.password.uppercase')
    .regex(/[a-z]/, 'errors.validation.password.lowercase')
    .regex(/[0-9]/, 'errors.validation.password.number')
    .regex(/[^A-Za-z0-9]/, 'errors.validation.password.special'),
  confirm_password: z.string().min(1, 'errors.validation.field.required')
}).refine((data) => data.new_password === data.confirm_password, {
  message: 'errors.validation.password.mismatch',
  path: ['confirm_password']
}).refine((data) => data.old_password !== data.new_password, {
  message: 'errors.validation.password.same',
  path: ['new_password']
});

// ==================== Refresh Token ====================
const refreshTokenBodySchema = z.object({
  refresh_token: z.string().min(1, 'errors.validation.field.required')
});

// ==================== Logout ====================
const logoutBodySchema = z.object({
  refresh_token: z.string().optional()
});

module.exports = {
  identifyBodySchema,
  loginBodySchema,
  registerBodySchema,
  verifyEmailBodySchema,
  verifyPhoneBodySchema,
  resendVerificationBodySchema,
  forgotPasswordBodySchema,
  resetPasswordBodySchema,
  changePasswordBodySchema,
  refreshTokenBodySchema,
  logoutBodySchema
};
