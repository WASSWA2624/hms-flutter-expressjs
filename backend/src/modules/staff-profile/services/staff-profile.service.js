/**
 * Staff profile service
 *
 * @module modules/staff-profile/services
 * @description Business logic layer for staff profile operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const { generateStaffNumber } = require('@lib/hr/staff-number');
const { syncStaffProfilePrimaryDepartment } = require('@lib/hr/staff-department-sync');
const staffProfileRepository = require('@repositories/staff-profile/staff-profile.repository');
const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/billing/identifiers');

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const {
  PRACTITIONER_TYPES,
  CONSULTATION_FEE_PRACTITIONER_TYPES,
} = require('@lib/hr/reference-data');
const ALLOWED_SORT_FIELDS = new Set([
  'created_at',
  'updated_at',
  'hire_date',
  'staff_number',
  'position',
  'practitioner_type',
  'human_friendly_id',
]);

const STAFF_PROFILE_INCLUDE = {
  tenant: {
    select: {
      id: true,
      human_friendly_id: true,
    },
  },
  user: {
    include: {
      profile: true
    }
  },
  department: true,
  compensations: {
    where: { deleted_at: null },
    orderBy: { effective_from: 'desc' },
  },
};

const normalizeIdentifier = (value) => (typeof value === 'string' ? value.trim() : '');
const isUuid = (value) => UUID_REGEX.test(normalizeIdentifier(value));

const buildUserDisplayName = (user = {}) => {
  const firstName = sanitizeIdentifier(user?.profile?.first_name);
  const middleName = sanitizeIdentifier(user?.profile?.middle_name);
  const lastName = sanitizeIdentifier(user?.profile?.last_name);
  return [firstName, middleName, lastName].filter(Boolean).join(' ');
};

const sortCompensationsForDisplay = (rows = []) => {
  const now = Date.now();
  return [...rows].sort((left, right) => {
    const leftActive = !left.effective_to || new Date(left.effective_to).getTime() >= now;
    const rightActive = !right.effective_to || new Date(right.effective_to).getTime() >= now;
    if (leftActive !== rightActive) return leftActive ? -1 : 1;
    return new Date(right.effective_from).getTime() - new Date(left.effective_from).getTime();
  });
};

const mapStaffProfileForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;
  const compensations = sortCompensationsForDisplay(record.compensations || []);
  return {
    ...record,
    compensations,
    display_id: resolvePublicIdentifier(
      record?.display_id,
      record?.human_friendly_id,
      record?.staff_number,
      record?.id
    ),
    tenant_display_id: resolvePublicIdentifier(
      record?.tenant_display_id,
      record?.tenant?.human_friendly_id,
      record?.tenant_id
    ),
    user_display_id: resolvePublicIdentifier(
      record?.user_display_id,
      record?.user?.human_friendly_id,
      record?.user_id
    ),
    user_full_name: buildUserDisplayName(record?.user || {}),
    department_display_id: resolvePublicIdentifier(
      record?.department_display_id,
      record?.department?.human_friendly_id,
      record?.department_id
    ),
    timeline_at: record?.updated_at || record?.created_at || null,
  };
};

const normalizePractitionerType = (value) => {
  const normalized = normalizeIdentifier(value).toUpperCase();
  return PRACTITIONER_TYPES.has(normalized) ? normalized : null;
};

const normalizeCurrencyCode = (value) => {
  const normalized = normalizeIdentifier(value).toUpperCase();
  return normalized || null;
};

const hasMeaningfulValue = (value) => {
  if (value === undefined || value === null) return false;
  if (typeof value === 'number') return Number.isFinite(value);
  if (typeof value === 'string') return value.trim() !== '';
  return true;
};

const toValidDate = (value) => {
  if (value === undefined || value === null || value === '') return null;
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
};

const normalizeConsultationFeePayload = (inputData = {}, { isEdit = false } = {}) => {
  const data = { ...inputData };
  const practitionerType = normalizePractitionerType(data.practitioner_type);
  const hasFee = hasMeaningfulValue(data.consultation_fee);
  const hasCurrency = hasMeaningfulValue(data.consultation_currency);

  if (data.practitioner_type !== undefined) {
    data.practitioner_type = practitionerType;
  }
  if (data.consultation_currency !== undefined) {
    data.consultation_currency = normalizeCurrencyCode(data.consultation_currency);
  }

  if (practitionerType && !CONSULTATION_FEE_PRACTITIONER_TYPES.has(practitionerType)) {
    data.consultation_fee = null;
    data.consultation_currency = null;
    data.is_fee_overridden = false;
    return data;
  }

  if (hasFee || hasCurrency) {
    if (!practitionerType && !isEdit) {
      data.practitioner_type = 'SPECIALIST';
    }
    if (!practitionerType && isEdit) {
      // Preserve current practitioner type on edit unless explicitly changed.
      data.is_fee_overridden = true;
      return data;
    }
    data.is_fee_overridden = data.is_fee_overridden !== undefined ? Boolean(data.is_fee_overridden) : true;
    return data;
  }

  if (data.is_fee_overridden !== undefined) {
    data.is_fee_overridden = Boolean(data.is_fee_overridden);
  }

  return data;
};

const extractCompensations = (data = {}) => {
  if (!Array.isArray(data.compensations)) return undefined;
  return data.compensations.map((entry) => ({
    pay_type: String(entry.pay_type || '').trim().toUpperCase(),
    rate: entry.rate,
    currency: String(entry.currency || '').trim().toUpperCase(),
    effective_from: entry.effective_from,
    effective_to: entry.effective_to || null,
    metadata_json:
      entry.metadata_json && typeof entry.metadata_json === 'object'
        ? entry.metadata_json
        : null,
  }));
};

const syncStaffCompensations = async (staffProfileId, compensations) => {
  if (!Array.isArray(compensations)) return;

  await prisma.$transaction(async (tx) => {
    await tx.staff_compensation.updateMany({
      where: {
        staff_profile_id: staffProfileId,
        deleted_at: null,
      },
      data: { deleted_at: new Date() },
    });

    for (const compensation of compensations) {
      await tx.staff_compensation.create({
        data: {
          staff_profile_id: staffProfileId,
          pay_type: compensation.pay_type,
          rate: compensation.rate,
          currency: compensation.currency,
          effective_from: compensation.effective_from,
          effective_to: compensation.effective_to,
          metadata_json: compensation.metadata_json || undefined,
        },
      });
    }
  });
};

const stripNestedStaffProfilePayload = (data = {}) => {
  const payload = { ...data };
  delete payload.compensations;
  return payload;
};

const upsertStaffPositionCatalogEntry = async ({
  tenantId,
  facilityId = null,
  positionName,
}) => {
  const normalizedName = normalizeIdentifier(positionName);
  if (!normalizedName || !tenantId || !prisma?.staff_position?.findFirst) {
    return null;
  }

  const existing = await prisma.staff_position.findFirst({
    where: {
      deleted_at: null,
      tenant_id: tenantId,
      name: normalizedName,
      ...(facilityId
        ? {
            OR: [{ facility_id: facilityId }, { facility_id: null }],
          }
        : { facility_id: null }),
    },
  });
  if (existing) {
    return existing;
  }

  return prisma.staff_position.create({
    data: {
      tenant_id: tenantId,
      facility_id: facilityId || null,
      name: normalizedName,
      is_active: true,
    },
  });
};

const resolveUserByIdentifier = async (identifier, tenantId = null) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;
  if (!prisma?.user?.findFirst) {
    return null;
  }

  const where = {
    deleted_at: null,
    ...(tenantId ? { tenant_id: tenantId } : {})
  };

  const userWhere = isUuid(normalized)
    ? { ...where, id: normalized }
    : {
        ...where,
        OR: [
          { human_friendly_id: normalized.toUpperCase() },
          { email: normalized },
          { phone: normalized }
        ]
      };

  return prisma.user.findFirst({ where: userWhere });
};

const resolveStaffProfileByIdentifier = async (identifier) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return null;
  if (isUuid(normalized)) {
    return staffProfileRepository.findById(normalized);
  }

  if (!prisma?.staff_profile?.findFirst) {
    return staffProfileRepository.findById(normalized);
  }

  return prisma.staff_profile.findFirst({
    where: {
      human_friendly_id: normalized.toUpperCase(),
      deleted_at: null
    },
    include: STAFF_PROFILE_INCLUDE
  });
};

const buildPagination = (page, limit, total) => {
  const totalPages = Math.ceil(total / limit);
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
};

const emptyResult = (page, limit) => ({
  staffProfiles: [],
  pagination: buildPagination(page, limit, 0),
});

/**
 * List staff profiles with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Staff profiles and pagination data
 */
const listStaffProfiles = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const normalizedSortBy = ALLOWED_SORT_FIELDS.has(sortBy) ? sortBy : 'created_at';
    const normalizedOrder = String(order || '').toLowerCase() === 'asc' ? 'asc' : 'desc';
    const orderBy = { [normalizedSortBy]: normalizedOrder };

    const whereClause = {};

    const tenantId = await resolveIdentifierForFilter({
      value: filters.tenant_id,
      model: 'tenant',
      where: { deleted_at: null },
    });
    if (filters.tenant_id && tenantId === null) return emptyResult(page, limit);
    if (tenantId) whereClause.tenant_id = tenantId;

    const departmentId = await resolveIdentifierForFilter({
      value: filters.department_id,
      model: 'department',
      where: { deleted_at: null },
    });
    if (filters.department_id && departmentId === null) return emptyResult(page, limit);
    if (departmentId) whereClause.department_id = departmentId;

    if (filters.staff_number) whereClause.staff_number = { contains: filters.staff_number };
    if (filters.position) whereClause.position = { contains: filters.position };
    if (typeof filters.is_fee_overridden === 'boolean') {
      whereClause.is_fee_overridden = filters.is_fee_overridden;
    }

    const hasConsultationFee = typeof filters.has_consultation_fee === 'boolean'
      ? filters.has_consultation_fee
      : undefined;
    if (hasConsultationFee === true) {
      whereClause.consultation_fee = { not: null };
    }
    if (hasConsultationFee === false) {
      whereClause.consultation_fee = null;
    }

    const hiredFrom = toValidDate(filters.hired_from);
    const hiredTo = toValidDate(filters.hired_to);
    if (hiredFrom || hiredTo) {
      whereClause.hire_date = {};
      if (hiredFrom) whereClause.hire_date.gte = hiredFrom;
      if (hiredTo) whereClause.hire_date.lte = hiredTo;
    }

    const practitionerType = normalizePractitionerType(filters.practitioner_type);
    if (practitionerType) {
      whereClause.practitioner_type = practitionerType;
    }

    if (filters.user_id) {
      const resolvedUser = await resolveUserByIdentifier(filters.user_id, tenantId || null);
      if (!resolvedUser) {
        return emptyResult(page, limit);
      }
      whereClause.user_id = resolvedUser.id;
    }

    if (filters.search) {
      const searchTerm = filters.search;
      const normalizedSearch = searchTerm.toUpperCase();

      whereClause.OR = [
        { human_friendly_id: { contains: normalizedSearch } },
        { staff_number: { contains: searchTerm } },
        { position: { contains: searchTerm } },
        { practitioner_type: { contains: normalizedSearch } },
        { user: { human_friendly_id: { contains: normalizedSearch } } },
        { user: { email: { contains: searchTerm } } },
        { user: { phone: { contains: searchTerm } } },
        { user: { profile: { first_name: { contains: searchTerm } } } },
        { user: { profile: { middle_name: { contains: searchTerm } } } },
        { user: { profile: { last_name: { contains: searchTerm } } } }
      ];
    }

    const [staffProfiles, total] = await Promise.all([
      staffProfileRepository.findMany(whereClause, skip, limit, orderBy, STAFF_PROFILE_INCLUDE),
      staffProfileRepository.count(whereClause)
    ]);

    const healedProfiles = await Promise.all(
      staffProfiles.map(async (profile) => {
        if (profile?.department_id) {
          return profile;
        }
        await syncStaffProfilePrimaryDepartment(profile.id);
        return (
          (await staffProfileRepository.findById(profile.id, STAFF_PROFILE_INCLUDE)) ||
          profile
        );
      })
    );

    return {
      staffProfiles: healedProfiles.map(mapStaffProfileForDisplay),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get staff profile by ID or human friendly ID
 *
 * @param {string} id - Staff profile identifier
 * @returns {Promise<Object>} Staff profile data
 */
const getStaffProfileById = async (id) => {
  try {
    const staffProfile = await resolveStaffProfileByIdentifier(id);

    if (!staffProfile) {
      throw new HttpError('errors.staff_profile.not_found', 404);
    }

    await syncStaffProfilePrimaryDepartment(staffProfile.id);
    const refreshedProfile =
      (await staffProfileRepository.findById(staffProfile.id, STAFF_PROFILE_INCLUDE)) ||
      staffProfile;

    return mapStaffProfileForDisplay(refreshedProfile);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Build normalized Prisma create payload for staff profiles (shared onboarding path).
 */
const buildStaffProfileCreateData = async (data) => {
  const tenantId = await resolveIdentifierForPayload({
    value: data.tenant_id,
    model: 'tenant',
    field: 'tenant_id',
    where: { deleted_at: null },
  });
  const shouldGenerateStaffNumber =
    data.generate_staff_number === true ||
    (data.generate_staff_number !== false && !normalizeIdentifier(data.staff_number));
  const departmentId = await resolveIdentifierForPayload({
    value: data.department_id,
    model: 'department',
    field: 'department_id',
    where: { deleted_at: null },
    nullable: true,
  });

  const resolvedUser = await resolveUserByIdentifier(data.user_id, tenantId || null);
  if (!resolvedUser) {
    throw new HttpError('errors.user.not_found', 404, [{ field: 'user_id' }]);
  }

  const payload = normalizeConsultationFeePayload(
    {
      ...stripNestedStaffProfilePayload(data),
      tenant_id: tenantId,
      department_id: departmentId,
      user_id: resolvedUser.id,
    },
    { isEdit: false },
  );

  if (shouldGenerateStaffNumber) {
    const generated = await generateStaffNumber({ tenantId });
    payload.staff_number = generated.staff_number;
  }

  delete payload.generate_staff_number;
  return payload;
};

/**
 * Create new staff profile
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Staff profile data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created staff profile
 */
const createStaffProfile = async (data, userId, ipAddress) => {
  try {
    const requestedCompensations = extractCompensations(data);
    const payload = await buildStaffProfileCreateData(data);

    const createdProfile = await staffProfileRepository.create(payload);
    await upsertStaffPositionCatalogEntry({
      tenantId: payload.tenant_id,
      facilityId: data.facility_id || null,
      positionName: payload.position,
    });
    await syncStaffCompensations(createdProfile.id, requestedCompensations);
    const createdWithRelations = await staffProfileRepository.findById(
      createdProfile.id,
      STAFF_PROFILE_INCLUDE
    );

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: payload.tenant_id,
      user_id: userId,
      action: 'CREATE',
      entity: 'staff_profile',
      entity_id: createdProfile.id,
      diff: { after: createdProfile },
      ip_address: ipAddress
    }).catch(() => {});

    return mapStaffProfileForDisplay(createdWithRelations || createdProfile);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update staff profile
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Staff profile identifier
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated staff profile
 */
const updateStaffProfile = async (id, data, userId, ipAddress) => {
  try {
    const before = await resolveStaffProfileByIdentifier(id);

    if (!before) {
      throw new HttpError('errors.staff_profile.not_found', 404);
    }

    const requestedCompensations = extractCompensations(data);
    const payload = normalizeConsultationFeePayload(stripNestedStaffProfilePayload(data), { isEdit: true });
    if (Object.prototype.hasOwnProperty.call(data, 'department_id')) {
      payload.department_id = await resolveIdentifierForPayload({
        value: data.department_id,
        model: 'department',
        field: 'department_id',
        where: { deleted_at: null },
        nullable: true,
      });
    }
    const updatedProfile = await staffProfileRepository.update(before.id, payload);
    if (Object.prototype.hasOwnProperty.call(data, 'position')) {
      await upsertStaffPositionCatalogEntry({
        tenantId: before.tenant_id,
        positionName: payload.position,
      });
    }
    await syncStaffCompensations(updatedProfile.id, requestedCompensations);
    const updatedWithRelations = await staffProfileRepository.findById(
      updatedProfile.id,
      STAFF_PROFILE_INCLUDE
    );

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: userId,
      action: 'UPDATE',
      entity: 'staff_profile',
      entity_id: updatedProfile.id,
      diff: { before, after: updatedProfile },
      ip_address: ipAddress
    }).catch(() => {});

    return mapStaffProfileForDisplay(updatedWithRelations || updatedProfile);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete staff profile (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Staff profile identifier
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteStaffProfile = async (id, userId, ipAddress) => {
  try {
    const before = await resolveStaffProfileByIdentifier(id);

    if (!before) {
      throw new HttpError('errors.staff_profile.not_found', 404);
    }

    await staffProfileRepository.softDelete(before.id);

    // Create audit log (non-blocking)
    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: userId,
      action: 'DELETE',
      entity: 'staff_profile',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listStaffProfiles,
  getStaffProfileById,
  buildStaffProfileCreateData,
  createStaffProfile,
  updateStaffProfile,
  deleteStaffProfile,
};
