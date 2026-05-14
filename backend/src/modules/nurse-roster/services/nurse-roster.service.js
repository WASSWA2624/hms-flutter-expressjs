const nurseRosterRepository = require('@repositories/nurse-roster/nurse-roster.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { generateRosterAssignments } = require('@services/hr-workspace/hr-roster-engine');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

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
  rosters: [],
  pagination: buildPagination(page, limit, 0),
});

const listNurseRosters = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    const tenantId = await resolveIdentifierForFilter({
      value: filters.tenant_id,
      model: 'tenant',
      where: { deleted_at: null },
    });
    if (filters.tenant_id && tenantId === null) return emptyResult(page, limit);
    if (tenantId) whereClause.tenant_id = tenantId;

    const facilityId = await resolveIdentifierForFilter({
      value: filters.facility_id,
      model: 'facility',
      where: { deleted_at: null },
    });
    if (filters.facility_id && facilityId === null) return emptyResult(page, limit);
    if (facilityId) whereClause.facility_id = facilityId;

    const departmentId = await resolveIdentifierForFilter({
      value: filters.department_id,
      model: 'department',
      where: { deleted_at: null },
    });
    if (filters.department_id && departmentId === null) return emptyResult(page, limit);
    if (departmentId) whereClause.department_id = departmentId;

    if (filters.status) whereClause.status = filters.status;
    if (filters.period_start_from || filters.period_start_to) {
      whereClause.period_start = {};
      if (filters.period_start_from) whereClause.period_start.gte = new Date(filters.period_start_from);
      if (filters.period_start_to) whereClause.period_start.lte = new Date(filters.period_start_to);
    }

    const [rosters, total] = await Promise.all([
      nurseRosterRepository.findMany(whereClause, skip, limit, orderBy),
      nurseRosterRepository.count(whereClause),
    ]);

    return {
      rosters,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getNurseRosterById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'nurse_roster',
      identifier: id,
      where: { deleted_at: null },
    });
    const roster = await nurseRosterRepository.findById(resolvedId);
    if (!roster) throw new HttpError('errors.nurse_roster.not_found', 404);
    return roster;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createNurseRoster = async (data, userId, ipAddress) => {
  try {
    const payload = {
      ...data,
      tenant_id: await resolveIdentifierForPayload({
        value: data.tenant_id,
        model: 'tenant',
        field: 'tenant_id',
        where: { deleted_at: null },
      }),
      facility_id: await resolveIdentifierForPayload({
        value: data.facility_id,
        model: 'facility',
        field: 'facility_id',
        where: { deleted_at: null },
        nullable: true,
      }),
      department_id: await resolveIdentifierForPayload({
        value: data.department_id,
        model: 'department',
        field: 'department_id',
        where: { deleted_at: null },
        nullable: true,
      }),
    };

    const roster = await nurseRosterRepository.create(payload);
    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'nurse_roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: { after: roster },
      ip_address: ipAddress,
    }).catch(() => {});
    return roster;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateNurseRoster = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'nurse_roster',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await nurseRosterRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.nurse_roster.not_found', 404);

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(data, 'facility_id')) {
      payload.facility_id = await resolveIdentifierForPayload({
        value: data.facility_id,
        model: 'facility',
        field: 'facility_id',
        where: { deleted_at: null },
        nullable: true,
      });
    }
    if (Object.prototype.hasOwnProperty.call(data, 'department_id')) {
      payload.department_id = await resolveIdentifierForPayload({
        value: data.department_id,
        model: 'department',
        field: 'department_id',
        where: { deleted_at: null },
        nullable: true,
      });
    }

    const roster = await nurseRosterRepository.update(before.id, payload);
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'nurse_roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: { before, after: roster },
      ip_address: ipAddress,
    }).catch(() => {});
    return roster;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteNurseRoster = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'nurse_roster',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await nurseRosterRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.nurse_roster.not_found', 404);

    await nurseRosterRepository.softDelete(before.id);
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'nurse_roster',
      entity_id: before.id,
      tenant_id: before.tenant_id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const publishNurseRoster = async (id, notifyStaff, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'nurse_roster',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await nurseRosterRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.nurse_roster.not_found', 404);
    if (before.status === 'PUBLISHED') throw new HttpError('errors.nurse_roster.already_published', 400);

    const roster = await nurseRosterRepository.update(before.id, {
      status: 'PUBLISHED',
      published_at: new Date(),
    });

    createAuditLog({
      user_id: userId,
      action: 'PUBLISH',
      entity: 'nurse_roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: { before, after: roster, metadata: { notifyStaff } },
      ip_address: ipAddress,
    }).catch(() => {});

    return roster;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const generateNurseRoster = async (id, data = {}, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'nurse_roster',
      identifier: id,
      where: { deleted_at: null },
    });
    const before = await nurseRosterRepository.findById(resolvedId);
    if (!before) throw new HttpError('errors.nurse_roster.not_found', 404);
    if (before.status === 'PUBLISHED') throw new HttpError('errors.nurse_roster.cannot_generate_published', 400);

    const updateData = {
      status: 'DRAFT',
      published_at: null,
    };

    if (Object.prototype.hasOwnProperty.call(data, 'period_start')) {
      updateData.period_start = new Date(data.period_start);
    }
    if (Object.prototype.hasOwnProperty.call(data, 'period_end')) {
      updateData.period_end = new Date(data.period_end);
    }
    if (Object.prototype.hasOwnProperty.call(data, 'constraints')) {
      updateData.constraints = data.constraints;
    }

    const roster = await nurseRosterRepository.update(before.id, updateData);
    const generation = await generateRosterAssignments({
      rosterIdentifier: roster.id,
      constraints: Object.prototype.hasOwnProperty.call(data, 'constraints') ? data.constraints : undefined,
      replaceExistingAssignments: true,
      dryRun: false,
      userId,
      ipAddress,
    });

    createAuditLog({
      user_id: userId,
      action: 'GENERATE',
      entity: 'nurse_roster',
      entity_id: roster.id,
      tenant_id: roster.tenant_id,
      diff: {
        before,
        after: roster,
        metadata: {
          generation_summary: generation.generation_summary,
          coverage: generation.coverage,
          unassigned_shifts: generation.unassigned_shifts,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return {
      ...roster,
      generation_summary: generation.generation_summary,
      coverage: generation.coverage,
      assignments: generation.assignments,
      unassigned_shifts: generation.unassigned_shifts,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listNurseRosters,
  getNurseRosterById,
  createNurseRoster,
  updateNurseRoster,
  deleteNurseRoster,
  publishNurseRoster,
  generateNurseRoster,
};
