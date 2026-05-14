/**
 * Appointment controller
 *
 * @module modules/appointment/controllers
 * @description Request handlers for appointment endpoints.
 * Per module-creation.mdc: All methods wrapped with asyncHandler.
 * Per response-format.mdc: Use standardized response helpers.
 */

const appointmentService = require('@services/appointment/appointment.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const GLOBAL_SCOPE_ROLES = new Set(['SUPER_ADMIN', 'APP_ADMIN', 'SYSTEM_ADMIN', 'PLATFORM_ADMIN']);

const normalizeScopeValue = (value) => {
  if (typeof value !== 'string') return '';
  return value.trim();
};

const hasGlobalScopeAccess = (user = {}) => {
  const roles = [
    ...(Array.isArray(user.roles) ? user.roles : []),
    user.role,
  ]
    .map((role) => String(role || '').trim().toUpperCase())
    .filter(Boolean);

  return roles.some((role) => GLOBAL_SCOPE_ROLES.has(role));
};

const buildAppointmentScope = (req = {}) => {
  const queryTenantId = normalizeScopeValue(req.query?.tenant_id);
  const queryFacilityId = normalizeScopeValue(req.query?.facility_id);
  const bodyTenantId = normalizeScopeValue(req.body?.tenant_id);
  const bodyFacilityId = normalizeScopeValue(req.body?.facility_id);
  const userTenantId = normalizeScopeValue(req.user?.tenant_id);
  const userFacilityId = normalizeScopeValue(req.user?.facility_id);

  const isGlobalUser = hasGlobalScopeAccess(req.user);
  const tenantId = isGlobalUser ? (bodyTenantId || queryTenantId) : (userTenantId || bodyTenantId || queryTenantId);
  const facilityId = isGlobalUser ? (bodyFacilityId || queryFacilityId) : (userFacilityId || bodyFacilityId || queryFacilityId);

  return {
    ...(tenantId ? { tenant_id: tenantId } : {}),
    ...(facilityId ? { facility_id: facilityId } : {}),
  };
};

/**
 * List appointments with pagination
 * GET /api/v1/appointments
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const listAppointments = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    patient_id,
    provider_user_id,
    status,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const filters = {
    tenant_id,
    facility_id,
    patient_id,
    provider_user_id,
    status,
    search,
    ...buildAppointmentScope(req)
  };

  const userId = req.user?.id;
  const ipAddress = req.ip;

  const result = await appointmentService.listAppointments(
    filters,
    parseInt(page),
    parseInt(limit),
    sort_by,
    order,
    userId,
    ipAddress
  );

  sendPaginated(res, 'messages.appointment.list.success', result.appointments, result.pagination);
});

/**
 * Get appointment by ID
 * GET /api/v1/appointments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const getAppointmentById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const appointment = await appointmentService.getAppointmentById(id, userId, ipAddress);

  sendSuccess(res, 200, 'messages.appointment.get.success', appointment);
});

/**
 * Create new appointment
 * POST /api/v1/appointments
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const createAppointment = asyncHandler(async (req, res) => {
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const scope = buildAppointmentScope(req);
  const payload = {
    ...req.body,
    tenant_id: scope.tenant_id ?? req.body?.tenant_id ?? null,
    facility_id: scope.facility_id ?? req.body?.facility_id ?? null,
  };

  const appointment = await appointmentService.createAppointment(payload, userId, ipAddress);

  sendSuccess(res, 201, 'messages.appointment.create.success', appointment);
});

/**
 * Update appointment
 * PUT /api/v1/appointments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const updateAppointment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const scope = buildAppointmentScope(req);
  const payload = {
    ...req.body,
    ...(scope.facility_id && Object.prototype.hasOwnProperty.call(req.body || {}, 'facility_id')
      ? { facility_id: scope.facility_id }
      : {}),
  };

  const appointment = await appointmentService.updateAppointment(id, payload, userId, ipAddress);

  sendSuccess(res, 200, 'messages.appointment.update.success', appointment);
});

/**
 * Delete appointment (soft delete)
 * DELETE /api/v1/appointments/:id
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const deleteAppointment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  await appointmentService.deleteAppointment(id, userId, ipAddress);

  sendNoContent(res);
});

/**
 * Cancel appointment
 * POST /api/v1/appointments/:id/cancel
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
const cancelAppointment = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { reason } = req.body;
  const userId = req.user?.id;
  const ipAddress = req.ip;

  const appointment = await appointmentService.cancelAppointment(id, reason, userId, ipAddress);

  sendSuccess(res, 200, 'messages.appointment.cancel.success', appointment);
});

module.exports = {
  listAppointments,
  getAppointmentById,
  createAppointment,
  updateAppointment,
  deleteAppointment,
  cancelAppointment
};
