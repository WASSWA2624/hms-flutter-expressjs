/**
 * Encounter service
 *
 * @module modules/encounter/services
 * @description Business logic layer for encounter operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const encounterRepository = require('@repositories/encounter/encounter.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { activeOpdLockKeyForEncounter } = require('@lib/opd-active-encounter');

const PATIENT_CONTACT_LOOKUP_TYPES = ['PHONE', 'EMAIL'];

const ENCOUNTER_LOOKUP_INCLUDE = {
  patient: {
    select: {
      id: true,
      human_friendly_id: true,
      first_name: true,
      last_name: true,
      date_of_birth: true,
      gender: true,
      contacts: {
        where: {
          deleted_at: null,
          contact_type: {
            in: PATIENT_CONTACT_LOOKUP_TYPES
          }
        },
        orderBy: [{ is_primary: 'desc' }, { updated_at: 'desc' }],
        select: {
          contact_type: true,
          value: true,
          is_primary: true
        }
      }
    }
  }
};

const normalizeSearchTerm = (value) => {
  const term = typeof value === 'string' ? value.trim() : '';
  if (!term) return null;
  return {
    raw: term,
    upper: term.toUpperCase()
  };
};

const normalizeContactType = (value) =>
  String(value || '')
    .trim()
    .toUpperCase();

const resolvePrimaryPatientContactByType = (contacts = [], type) => {
  const normalizedType = normalizeContactType(type);
  const matches = contacts.filter(
    (entry) => normalizeContactType(entry?.contact_type) === normalizedType
  );
  return matches.find((entry) => entry?.is_primary) || matches[0] || null;
};

const serializeEncounterPatient = (patient) => {
  if (!patient || typeof patient !== 'object') return patient;

  const contacts = Array.isArray(patient.contacts) ? patient.contacts : [];
  const primaryPhone =
    resolvePrimaryPatientContactByType(contacts, 'PHONE')?.value || null;
  const primaryEmail =
    resolvePrimaryPatientContactByType(contacts, 'EMAIL')?.value || null;

  return {
    ...patient,
    phone: primaryPhone,
    email: primaryEmail,
    primary_phone: primaryPhone,
    primary_email: primaryEmail,
    contact_phone: primaryPhone,
    contact_email: primaryEmail
  };
};

const serializeEncounterSummaries = (encounters = []) =>
  encounters.map((encounter) => {
    if (!encounter || typeof encounter !== 'object') return encounter;
    if (!encounter.patient) return encounter;
    return {
      ...encounter,
      patient: serializeEncounterPatient(encounter.patient)
    };
  });

/**
 * List encounters with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Encounters and pagination data
 */
const listEncounters = async (
  filters,
  page,
  limit,
  sortBy,
  order,
  userId,
  ipAddress
) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};

    if (filters.tenant_id) whereClause.tenant_id = filters.tenant_id;
    if (filters.facility_id) whereClause.facility_id = filters.facility_id;
    if (filters.patient_id) whereClause.patient_id = filters.patient_id;
    if (filters.provider_user_id)
      whereClause.provider_user_id = filters.provider_user_id;
    if (filters.encounter_type)
      whereClause.encounter_type = filters.encounter_type;
    if (filters.status) whereClause.status = filters.status;

    const searchTerm = normalizeSearchTerm(filters.search);
    if (searchTerm) {
      whereClause.OR = [
        { human_friendly_id: { contains: searchTerm.upper } },
        { patient: { human_friendly_id: { contains: searchTerm.upper } } },
        { patient: { first_name: { contains: searchTerm.raw } } },
        { patient: { last_name: { contains: searchTerm.raw } } },
        {
          patient: {
            contacts: {
              some: {
                deleted_at: null,
                contact_type: {
                  in: PATIENT_CONTACT_LOOKUP_TYPES
                },
                value: { contains: searchTerm.raw }
              }
            }
          }
        },
        { encounter_type: { contains: searchTerm.raw } },
        { status: { contains: searchTerm.raw } }
      ];
    }

    const [encounters, total] = await Promise.all([
      encounterRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        ENCOUNTER_LOOKUP_INCLUDE
      ),
      encounterRepository.count(whereClause)
    ]);

    const serializedEncounters = serializeEncounterSummaries(encounters);

    return {
      encounters: serializedEncounters,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1
      }
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message }
    ]);
  }
};

/**
 * Get encounter by ID
 *
 * @param {string} id - Encounter ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Encounter data
 */
const getEncounterById = async (id, userId, ipAddress) => {
  try {
    const encounter = await encounterRepository.findById(id);

    if (!encounter) {
      throw new HttpError('errors.encounter.not_found', 404);
    }

    return encounter;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message }
    ]);
  }
};

/**
 * Create new encounter
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Encounter data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created encounter
 */
const createEncounter = async (data, userId, ipAddress) => {
  try {
    const now = new Date();
    const payload = {
      ...data,
      provider_user_id: data.provider_user_id || userId || null,
      status: data.status || 'OPEN',
      started_at: data.started_at ? new Date(data.started_at) : now,
      ended_at: data.ended_at ? new Date(data.ended_at) : null
    };
    payload.active_opd_lock_key = activeOpdLockKeyForEncounter(payload);

    const encounter = await encounterRepository.create(payload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'encounter',
      entity_id: encounter.id,
      diff: { after: encounter },
      ip_address: ipAddress
    }).catch(() => {});

    return encounter;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message }
    ]);
  }
};

/**
 * Update encounter
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Encounter ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated encounter
 */
const updateEncounter = async (id, data, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await encounterRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.encounter.not_found', 404);
    }

    const payload = { ...data };
    if (
      String(payload.status || '').toUpperCase() === 'CLOSED' &&
      !payload.ended_at &&
      !before.ended_at
    ) {
      payload.ended_at = new Date();
    }
    payload.active_opd_lock_key = activeOpdLockKeyForEncounter({
      ...before,
      ...payload,
      status: payload.status || before.status
    });

    const encounter = await encounterRepository.update(id, payload);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'encounter',
      entity_id: encounter.id,
      diff: { before, after: encounter },
      ip_address: ipAddress
    }).catch(() => {});

    return encounter;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message }
    ]);
  }
};

/**
 * Delete encounter (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Encounter ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteEncounter = async (id, userId, ipAddress) => {
  try {
    // Get current state for audit
    const before = await encounterRepository.findById(id);

    if (!before) {
      throw new HttpError('errors.encounter.not_found', 404);
    }

    await encounterRepository.softDelete(id);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'encounter',
      entity_id: id,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message }
    ]);
  }
};

module.exports = {
  listEncounters,
  getEncounterById,
  createEncounter,
  updateEncounter,
  deleteEncounter
};
