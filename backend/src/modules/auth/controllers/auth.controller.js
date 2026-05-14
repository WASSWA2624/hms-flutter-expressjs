/**
 * Auth controller
 *
 * @module modules/auth/controllers
 * @description Handles HTTP requests for authentication endpoints.
 */

const authService = require('@services/auth/auth.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const { HttpError } = require('@lib/errors');
const { randomBytes } = require('crypto');

const getRegistrationRequestContext = (req) => ({
  locale: req.locale || req.get('x-locale') || req.get('accept-language') || null,
  timezone: req.get('x-timezone') || null,
  platform: req.get('x-platform') || req.get('sec-ch-ua-platform') || null,
  referer: req.get('referer') || req.get('referrer') || null,
  origin: req.get('origin') || null,
  sec_ch_ua: req.get('sec-ch-ua') || null,
  sec_ch_ua_mobile: req.get('sec-ch-ua-mobile') || null,
});

/**
 * Identify users by identifier
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const identify = asyncHandler(async (req, res) => {
  const { identifier } = req.body;

  const result = await authService.identify({ identifier });

  return sendSuccess(res, 200, 'messages.auth.identify.success', result);
});

/**
 * Login user
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const login = asyncHandler(async (req, res) => {
  try {
    const { email, phone, password, tenant_id, facility_id } = req.body;
    const ip_address = req.ip;
    const user_agent = req.get('user-agent');

    const result = await authService.login({
      email,
      phone,
      password,
      tenant_id,
      facility_id,
      ip_address,
      user_agent
    });

    return sendSuccess(res, 200, 'messages.auth.login.success', result);
  } catch (error) {
    // Error is handled by global error handler with audit logging
    throw error;
  }
});

/**
 * Register new user
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const register = asyncHandler(async (req, res) => {
  const { email, password, facility_name, admin_name, facility_type, phone, location, interests } = req.body;
  const ip_address = req.ip;
  const user_agent = req.get('user-agent');
  const request_context = getRegistrationRequestContext(req);

  const result = await authService.register({
    email,
    password,
    facility_name,
    admin_name,
    facility_type,
    phone,
    location,
    interests,
    ip_address,
    user_agent,
    request_context,
  });

  return sendSuccess(res, 201, 'messages.auth.register.success', result);
});

/**
 * Verify email
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const verifyEmail = asyncHandler(async (req, res) => {
  const { token, email } = req.body;

  const result = await authService.verifyEmail({ token, email });

  return sendSuccess(res, 200, 'messages.auth.email_verified.success', result);
});

/**
 * Verify phone
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const verifyPhone = asyncHandler(async (req, res) => {
  const { token, phone } = req.body;

  const result = await authService.verifyPhone({ token, phone });

  return sendSuccess(res, 200, 'messages.auth.phone_verified.success', result);
});

/**
 * Resend verification
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const resendVerification = asyncHandler(async (req, res) => {
  const { email, phone, type } = req.body;
  const request_context = getRegistrationRequestContext(req);

  const result = await authService.resendVerification({ email, phone, type, request_context });

  return sendSuccess(res, 200, 'messages.auth.verification_sent.success', result);
});

/**
 * Forgot password
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const forgotPassword = asyncHandler(async (req, res) => {
  const { email, tenant_id } = req.body;
  const request_context = getRegistrationRequestContext(req);

  const result = await authService.forgotPassword({ email, tenant_id, request_context });

  return sendSuccess(res, 200, 'messages.auth.password_reset.email_sent', result);
});

/**
 * Reset password
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const resetPassword = asyncHandler(async (req, res) => {
  const { token, new_password } = req.body;

  const result = await authService.resetPassword({ token, new_password });

  return sendSuccess(res, 200, 'messages.auth.password_reset.success', result);
});

/**
 * Change password (authenticated)
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const changePassword = asyncHandler(async (req, res) => {
  const { old_password, new_password } = req.body;
  const user_id = req.user?.userId || req.user?.id;
  const ip_address = req.ip;
  const user_agent = req.get('user-agent');

  if (!user_id) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const result = await authService.changePassword({
    user_id,
    old_password,
    new_password,
    ip_address,
    user_agent
  });

  return sendSuccess(res, 200, 'messages.auth.password_changed.success', result);
});

/**
 * Refresh access token
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const refresh = asyncHandler(async (req, res) => {
  const { refresh_token } = req.body;
  const ip_address = req.ip;
  const user_agent = req.get('user-agent');

  const result = await authService.refresh({
    refresh_token,
    ip_address,
    user_agent
  });

  return sendSuccess(res, 200, 'messages.auth.token_refreshed.success', result);
});

/**
 * Logout user
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const logout = asyncHandler(async (req, res) => {
  const { refresh_token } = req.body;
  const user_id = req.user?.userId || req.user?.id;
  const ip_address = req.ip;
  const user_agent = req.get('user-agent');

  if (!user_id) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const result = await authService.logout({
    user_id,
    refresh_token,
    ip_address,
    user_agent
  });

  return sendSuccess(res, 200, 'messages.auth.logout.success', result);
});

/**
 * Get current user info
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getMe = asyncHandler(async (req, res) => {
  const userId = req.user?.userId || req.user?.id;

  if (!userId) {
    throw new HttpError('errors.auth.unauthorized', 401);
  }

  const result = await authService.getMe(userId);

  return sendSuccess(res, 200, 'messages.auth.user_info.retrieved', result);
});

/**
 * Get CSRF token
 * Generates a CSRF token and stores it in session
 * This token must be sent in x-csrf-token header for state-changing requests
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @returns {Promise<void>}
 */
const getCsrfToken = asyncHandler(async (req, res) => {
  // Generate a secure random token
  const token = randomBytes(32).toString('hex');
  
  // Store token in session
  if (!req.session) {
    req.session = {};
  }
  req.session._csrf = token;
  
  return sendSuccess(res, 200, 'messages.auth.csrf_token.generated', {
    token,
    header: 'x-csrf-token'
  });
});

module.exports = {
  identify,
  login,
  register,
  verifyEmail,
  verifyPhone,
  resendVerification,
  forgotPassword,
  resetPassword,
  changePassword,
  refresh,
  logout,
  getMe,
  getCsrfToken
};
