/**
 * Appointment repository
 *
 * @module modules/appointment/repositories
 * @description Data access layer for appointment operations.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { withActivePatient } = require('@lib/patient-query-filters');

/**
 * Find appointment by ID
 *
 * @param {string} id - Appointment ID
 * @param {Object} include - Relations to include
 * @returns {Promise<Object|null>} Appointment object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.appointment.findFirst({
      where: withActivePatient({ id }, { allowNullPatient: true }),
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many appointments with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Relations to include
 * @returns {Promise<Array>} Array of appointments
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    const where = withActivePatient(filters, { allowNullPatient: true });

    return await prisma.appointment.findMany({
      where,
      skip,
      take,
      orderBy,
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count appointments with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of appointments
 */
const count = async (filters = {}) => {
  try {
    const where = withActivePatient(filters, { allowNullPatient: true });

    return await prisma.appointment.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new appointment
 *
 * @param {Object} data - Appointment data
 * @returns {Promise<Object>} Created appointment
 */
const create = async (data) => {
  try {
    return await prisma.appointment.create({
      data
    });
  } catch (error) {
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      // Foreign key constraint violation
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update appointment
 *
 * @param {string} id - Appointment ID
 * @param {Object} data - Update data
 * @returns {Promise<Object>} Updated appointment
 */
const update = async (id, data) => {
  try {
    return await prisma.appointment.update({
      where: { id },
      data
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.appointment.not_found', 404);
    }
    if (error.code === 'P2002') {
      // Unique constraint violation
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      // Foreign key constraint violation
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Soft delete appointment
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Appointment ID
 * @returns {Promise<Object>} Deleted appointment
 */
const softDelete = async (id) => {
  try {
    return await prisma.appointment.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.appointment.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find overlapping active appointments for a host in a time window.
 *
 * @param {Object} params
 * @param {string} params.providerUserId
 * @param {Date|string} params.scheduledStart
 * @param {Date|string} params.scheduledEnd
 * @param {string} [params.excludeAppointmentId]
 * @param {string} [params.tenantId]
 * @returns {Promise<Object|null>}
 */
const findOverlappingForProvider = async ({
  providerUserId,
  scheduledStart,
  scheduledEnd,
  excludeAppointmentId,
  tenantId,
}) => {
  try {
    if (!providerUserId || !scheduledStart || !scheduledEnd) {
      return null;
    }
    const start = new Date(scheduledStart);
    const end = new Date(scheduledEnd);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
      return null;
    }

    return await prisma.appointment.findFirst({
      where: {
        deleted_at: null,
        provider_user_id: providerUserId,
        ...(tenantId ? { tenant_id: tenantId } : {}),
        ...(excludeAppointmentId ? { id: { not: excludeAppointmentId } } : {}),
        status: { notIn: ['CANCELLED', 'NO_SHOW', 'COMPLETED'] },
        scheduled_start: { lt: end },
        scheduled_end: { gt: start },
      },
      select: {
        id: true,
        human_friendly_id: true,
        scheduled_start: true,
        scheduled_end: true,
        status: true,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find a non-terminal appointment for the same patient whose window overlaps
 * [scheduledStart, scheduledEnd). A patient cannot be in two places at once,
 * so this is the patient-side counterpart to findOverlappingForProvider.
 */
const findOverlappingForPatient = async ({
  patientId,
  scheduledStart,
  scheduledEnd,
  excludeAppointmentId,
  tenantId,
}) => {
  try {
    if (!patientId || !scheduledStart || !scheduledEnd) {
      return null;
    }
    const start = new Date(scheduledStart);
    const end = new Date(scheduledEnd);
    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end <= start) {
      return null;
    }

    return await prisma.appointment.findFirst({
      where: {
        deleted_at: null,
        patient_id: patientId,
        ...(tenantId ? { tenant_id: tenantId } : {}),
        ...(excludeAppointmentId ? { id: { not: excludeAppointmentId } } : {}),
        status: { notIn: ['CANCELLED', 'NO_SHOW', 'COMPLETED'] },
        scheduled_start: { lt: end },
        scheduled_end: { gt: start },
      },
      select: {
        id: true,
        human_friendly_id: true,
        scheduled_start: true,
        scheduled_end: true,
        status: true,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete,
  findOverlappingForProvider,
  findOverlappingForPatient,
};
