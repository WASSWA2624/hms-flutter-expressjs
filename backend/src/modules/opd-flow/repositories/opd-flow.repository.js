/**
 * OPD flow repository
 *
 * @module modules/opd-flow/repositories
 * @description Data access layer for OPD flow orchestration rooted on encounter records.
 * Per module-creation.mdc: Only standard CRUD operations allowed in repositories.
 * Per prisma.mdc: All queries use soft delete filtering (deleted_at: null).
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { withActivePatient } = require('@lib/patient-query-filters');

const PROVIDER_PROFILE_SELECT = {
  first_name: true,
  middle_name: true,
  last_name: true
};

const PROVIDER_STAFF_PROFILE_SELECT = {
  id: true,
  human_friendly_id: true,
  staff_number: true,
  position: true,
  practitioner_type: true,
  consultation_fee: true,
  consultation_currency: true,
  deleted_at: true
};

const PROVIDER_SELECT = {
  id: true,
  human_friendly_id: true,
  tenant_id: true,
  facility_id: true,
  email: true,
  phone: true,
  status: true,
  created_at: true,
  updated_at: true,
  deleted_at: true,
  version: true,
  profile: {
    select: PROVIDER_PROFILE_SELECT
  },
  staff_profile: {
    select: PROVIDER_STAFF_PROFILE_SELECT
  }
};

const BASE_INCLUDE = {
  tenant: true,
  facility: true,
  patient: true,
  provider: {
    select: PROVIDER_SELECT
  }
};

/**
 * Find OPD flow encounter by ID
 *
 * @param {string} id - Encounter ID
 * @param {Object} include - Additional relations to include
 * @returns {Promise<Object|null>} Encounter object or null
 */
const findById = async (id, include = {}) => {
  try {
    return await prisma.encounter.findFirst({
      where: withActivePatient({ id }),
      include: {
        ...BASE_INCLUDE,
        ...include
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find many OPD flow encounters with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} skip - Number of records to skip
 * @param {number} take - Number of records to take
 * @param {Object} orderBy - Sort order
 * @param {Object} include - Additional relations to include
 * @returns {Promise<Array>} Array of encounter records
 */
const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { started_at: 'desc' }, include = {}) => {
  try {
    const where = withActivePatient({
      encounter_type: { in: ['OPD', 'EMERGENCY'] },
      ...filters,
    });

    return await prisma.encounter.findMany({
      where,
      skip,
      take,
      orderBy,
      include: {
        ...BASE_INCLUDE,
        ...include
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Count OPD flow encounters with filters
 *
 * @param {Object} filters - Filter criteria
 * @returns {Promise<number>} Count of encounters
 */
const count = async (filters = {}) => {
  try {
    const where = withActivePatient({
      encounter_type: { in: ['OPD', 'EMERGENCY'] },
      ...filters,
    });

    return await prisma.encounter.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Find an open OPD/emergency encounter for a patient.
 *
 * @param {Object} filters - Filter criteria
 * @param {string} filters.tenantId - Tenant ID
 * @param {string} filters.patientId - Patient ID
 * @param {Array<string>} [filters.encounterTypes] - Encounter types to guard
 * @param {Object} [client] - Prisma client or transaction client
 * @returns {Promise<Object|null>} Open encounter or null
 */
const findOpenActiveEncounterForPatient = async (
  { tenantId, patientId, encounterTypes = ['OPD', 'EMERGENCY'] } = {},
  client = prisma
) => {
  try {
    if (!tenantId || !patientId) {
      return null;
    }

    return await client.encounter.findFirst({
      where: withActivePatient({
        tenant_id: tenantId,
        patient_id: patientId,
        status: 'OPEN',
        encounter_type: { in: encounterTypes }
      }),
      orderBy: { started_at: 'asc' },
      select: {
        id: true,
        human_friendly_id: true,
        tenant_id: true,
        facility_id: true,
        patient_id: true,
        encounter_type: true,
        status: true,
        started_at: true,
        extension_json: true
      }
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create OPD flow encounter
 *
 * @param {Object} data - Encounter payload
 * @returns {Promise<Object>} Created encounter
 */
const create = async (data) => {
  try {
    return await prisma.encounter.create({
      data,
      include: BASE_INCLUDE
    });
  } catch (error) {
    if (error.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update OPD flow encounter
 *
 * @param {string} id - Encounter ID
 * @param {Object} data - Update payload
 * @returns {Promise<Object>} Updated encounter
 */
const update = async (id, data) => {
  try {
    return await prisma.encounter.update({
      where: { id },
      data,
      include: BASE_INCLUDE
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.encounter.not_found', 404);
    }
    if (error.code === 'P2002') {
      const target = error.meta?.target?.[0] || 'field';
      throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
    }
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Soft delete OPD flow encounter
 * Per prisma.mdc: Only soft deletes allowed
 *
 * @param {string} id - Encounter ID
 * @returns {Promise<Object>} Soft-deleted encounter
 */
const softDelete = async (id) => {
  try {
    return await prisma.encounter.update({
      where: { id },
      data: {
        deleted_at: new Date()
      }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      throw new HttpError('errors.encounter.not_found', 404);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findById,
  findMany,
  count,
  findOpenActiveEncounterForPatient,
  create,
  update,
  softDelete
};
