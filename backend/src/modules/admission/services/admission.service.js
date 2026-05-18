/**
 * Admission service
 *
 * @module modules/admission/services
 * @description Business logic layer for admission operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const admissionRepository = require('@repositories/admission/admission.repository');
const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/identifiers/service-identifier-resolution');

const buildPagination = (page, limit, total) => ({
  page,
  limit,
  total,
  totalPages: Math.ceil(total / limit),
  hasNextPage: page < Math.ceil(total / limit),
  hasPreviousPage: page > 1,
});

const buildEmptyListResult = (page, limit) => ({
  admissions: [],
  pagination: buildPagination(page, limit, 0),
});

const asPlainJsonObject = (value) => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return value;
};

const updatePatientAdmissionSnapshot = async (
  tx,
  patientId,
  snapshot = {}
) => {
  if (!patientId) return;

  const patient = await tx.patient.findFirst({
    where: { id: patientId, deleted_at: null },
    select: { extension_json: true },
  });

  if (!patient) return;

  await tx.patient.update({
    where: { id: patientId },
    data: {
      extension_json: {
        ...asPlainJsonObject(patient.extension_json),
        ...snapshot,
      },
    },
  });
};

const resolveAdmissionPayload = async (data = {}, { isCreate = false } = {}) => {
  const payload = { ...data };
  const wardInput = payload.ward_id;
  const roomInput = payload.room_id;
  const bedInput = payload.bed_id;

  delete payload.ward_id;
  delete payload.room_id;
  delete payload.bed_id;

  if (isCreate || Object.prototype.hasOwnProperty.call(payload, 'tenant_id')) {
    payload.tenant_id = await resolveIdentifierForPayload({
      value: payload.tenant_id,
      field: 'tenant_id',
      model: 'tenant',
      where: { deleted_at: null },
    });
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'facility_id')) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: payload.facility_id,
      field: 'facility_id',
      model: 'facility',
      where: { deleted_at: null },
      nullable: true,
    });
  }

  if (isCreate || Object.prototype.hasOwnProperty.call(payload, 'patient_id')) {
    payload.patient_id = await resolveIdentifierForPayload({
      value: payload.patient_id,
      field: 'patient_id',
      model: 'patient',
      where: { deleted_at: null },
    });
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'encounter_id')) {
    payload.encounter_id = await resolveIdentifierForPayload({
      value: payload.encounter_id,
      field: 'encounter_id',
      model: 'encounter',
      where: { deleted_at: null },
      nullable: true,
    });
  }

  if (payload.admitted_at) {
    payload.admitted_at = new Date(payload.admitted_at);
  }
  if (payload.discharged_at) {
    payload.discharged_at = new Date(payload.discharged_at);
  }

  if (isCreate) {
    payload.status = 'ADMITTED';
  } else if (payload.status) {
    payload.status = String(payload.status).trim().toUpperCase();
  }

  const wardId = await resolveIdentifierForPayload({
    value: wardInput,
    field: 'ward_id',
    model: 'ward',
    where: { deleted_at: null },
    nullable: !isCreate,
  });

  const roomId = await resolveIdentifierForPayload({
    value: roomInput,
    field: 'room_id',
    model: 'room',
    where: { deleted_at: null },
    nullable: !isCreate,
  });

  const bedId = await resolveIdentifierForPayload({
    value: bedInput,
    field: 'bed_id',
    model: 'bed',
    where: { deleted_at: null },
    nullable: !isCreate,
  });

  return { payload, wardId, roomId, bedId };
};

const assertBedSelectionIsValid = async (
  tx,
  { tenantId, facilityId, wardId, roomId, bedId }
) => {
  if (!wardId || !roomId || !bedId) {
    throw new HttpError('errors.validation.field.required', 400, [
      { field: !wardId ? 'ward_id' : !roomId ? 'room_id' : 'bed_id' },
    ]);
  }

  const ward = await tx.ward.findFirst({
    where: {
      id: wardId,
      deleted_at: null,
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
    select: { id: true },
  });

  if (!ward) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'ward_id' }]);
  }

  const room = await tx.room.findFirst({
    where: {
      id: roomId,
      ward_id: wardId,
      deleted_at: null,
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
    select: { id: true },
  });

  if (!room) {
    throw new HttpError('errors.validation.invalid', 400, [{ field: 'room_id' }]);
  }

  const bed = await tx.bed.findFirst({
    where: {
      id: bedId,
      ward_id: wardId,
      room_id: roomId,
      status: 'AVAILABLE',
      deleted_at: null,
      ...(tenantId ? { tenant_id: tenantId } : {}),
      ...(facilityId ? { facility_id: facilityId } : {}),
    },
    select: { id: true },
  });

  if (!bed) {
    throw new HttpError('errors.validation.invalid', 409, [{ field: 'bed_id' }]);
  }
};

const includeAdmissionBedAssignments = {
  patient: {
    select: {
      id: true,
      human_friendly_id: true,
      first_name: true,
      last_name: true,
      date_of_birth: true,
      gender: true,
    },
  },
  encounter: {
    select: {
      id: true,
      human_friendly_id: true,
      encounter_type: true,
      status: true,
    },
  },
  bed_assignments: {
    where: { deleted_at: null },
    orderBy: { assigned_at: 'desc' },
    include: {
      bed: {
        include: {
          ward: true,
          room: true,
        },
      },
    },
  },
};

/**
 * List admissions with pagination and filtering
 */
const listAdmissions = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    if (filters.tenant_id) {
      const tenantId = await resolveIdentifierForFilter({
        value: filters.tenant_id,
        model: 'tenant',
        where: { deleted_at: null },
      });
      if (tenantId === null) return buildEmptyListResult(page, limit);
      if (tenantId !== undefined) whereClause.tenant_id = tenantId;
    }
    if (filters.facility_id) {
      const facilityId = await resolveIdentifierForFilter({
        value: filters.facility_id,
        model: 'facility',
        where: { deleted_at: null },
      });
      if (facilityId === null) return buildEmptyListResult(page, limit);
      if (facilityId !== undefined) whereClause.facility_id = facilityId;
    }
    if (filters.patient_id) {
      const patientId = await resolveIdentifierForFilter({
        value: filters.patient_id,
        model: 'patient',
        where: { deleted_at: null },
      });
      if (patientId === null) return buildEmptyListResult(page, limit);
      if (patientId !== undefined) whereClause.patient_id = patientId;
    }
    if (filters.encounter_id) {
      const encounterId = await resolveIdentifierForFilter({
        value: filters.encounter_id,
        model: 'encounter',
        where: { deleted_at: null },
      });
      if (encounterId === null) return buildEmptyListResult(page, limit);
      if (encounterId !== undefined) whereClause.encounter_id = encounterId;
    }
    if (filters.status) whereClause.status = filters.status;

    const [admissions, total] = await Promise.all([
      admissionRepository.findMany(whereClause, skip, limit, orderBy, includeAdmissionBedAssignments),
      admissionRepository.count(whereClause),
    ]);

    return {
      admissions,
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get admission by ID
 */
const getAdmissionById = async (id, userId, ipAddress) => {
  try {
    const admission = await admissionRepository.findById(id, includeAdmissionBedAssignments);

    if (!admission) {
      throw new HttpError('errors.admission.not_found', 404);
    }

    return admission;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new admission
 * Per prisma.mdc: Mutations must create audit logs
 */
const createAdmission = async (data, userId, ipAddress) => {
  try {
    const { payload, wardId, roomId, bedId } = await resolveAdmissionPayload(data, {
      isCreate: true,
    });

    const admission = await prisma.$transaction(async (tx) => {
      await assertBedSelectionIsValid(tx, {
        tenantId: payload.tenant_id,
        facilityId: payload.facility_id,
        wardId,
        roomId,
        bedId,
      });

      const createdAdmission = await tx.admission.create({ data: payload });

      await tx.bed_assignment.create({
        data: {
          admission_id: createdAdmission.id,
          bed_id: bedId,
          assigned_at: createdAdmission.admitted_at || new Date(),
        },
      });

      await tx.bed.update({
        where: { id: bedId },
        data: { status: 'OCCUPIED' },
      });

      await updatePatientAdmissionSnapshot(tx, createdAdmission.patient_id, {
        admission_status: 'ADMITTED',
        active_admission_id: createdAdmission.id,
        active_admission_human_friendly_id:
          createdAdmission.human_friendly_id || null,
        current_bed_id: bedId,
        current_bed_assigned_at: (
          createdAdmission.admitted_at || new Date()
        ).toISOString(),
      });

      return tx.admission.findFirst({
        where: { id: createdAdmission.id, deleted_at: null },
        include: includeAdmissionBedAssignments,
      });
    });

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'admission',
      entity_id: admission.id,
      diff: { after: admission },
      ip_address: ipAddress,
    }).catch(() => {});

    return admission;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update admission
 */
const updateAdmission = async (id, data, userId, ipAddress) => {
  try {
    const before = await admissionRepository.findById(id, includeAdmissionBedAssignments);

    if (!before) {
      throw new HttpError('errors.admission.not_found', 404);
    }

    const { payload } = await resolveAdmissionPayload(data);
    const admission = await admissionRepository.update(id, payload);

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'admission',
      entity_id: admission.id,
      diff: { before, after: admission },
      ip_address: ipAddress,
    }).catch(() => {});

    return admission;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete admission (soft delete)
 */
const deleteAdmission = async (id, userId, ipAddress) => {
  try {
    const before = await admissionRepository.findById(id, includeAdmissionBedAssignments);

    if (!before) {
      throw new HttpError('errors.admission.not_found', 404);
    }

    await admissionRepository.softDelete(id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'admission',
      entity_id: id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Discharge patient from admission
 */
const dischargeAdmission = async (id, data, userId, ipAddress) => {
  try {
    const before = await admissionRepository.findById(id, includeAdmissionBedAssignments);

    if (!before) {
      throw new HttpError('errors.admission.not_found', 404);
    }

    if (before.status === 'DISCHARGED') {
      throw new HttpError('errors.admission.already_discharged', 400);
    }

    const dischargedAt = data.discharged_at
      ? new Date(data.discharged_at)
      : new Date();

    const admission = await prisma.$transaction(async (tx) => {
      const updatedAdmission = await tx.admission.update({
        where: { id },
        data: {
          status: 'DISCHARGED',
          discharged_at: dischargedAt,
        },
      });

      const activeAssignment = await tx.bed_assignment.findFirst({
        where: {
          admission_id: id,
          released_at: null,
          deleted_at: null,
        },
        orderBy: { assigned_at: 'desc' },
      });

      if (activeAssignment) {
        await tx.bed_assignment.update({
          where: { id: activeAssignment.id },
          data: { released_at: dischargedAt },
        });
        await tx.bed.update({
          where: { id: activeAssignment.bed_id },
          data: { status: 'AVAILABLE' },
        });
      }

      await updatePatientAdmissionSnapshot(tx, updatedAdmission.patient_id, {
        admission_status: 'DISCHARGED',
        active_admission_id: null,
        active_admission_human_friendly_id: null,
        current_bed_id: null,
        current_bed_assigned_at: null,
        last_discharged_admission_id: updatedAdmission.id,
        last_discharged_at: dischargedAt.toISOString(),
      });

      return tx.admission.findFirst({
        where: { id: updatedAdmission.id, deleted_at: null },
        include: includeAdmissionBedAssignments,
      });
    });

    createAuditLog({
      user_id: userId,
      action: 'DISCHARGE',
      entity: 'admission',
      entity_id: admission.id,
      diff: { before, after: admission },
      ip_address: ipAddress,
    }).catch(() => {});

    return admission;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Transfer admission (workflow action)
 */
const transferAdmission = async (id, data, userId, ipAddress) => {
  try {
    const before = await admissionRepository.findById(id, includeAdmissionBedAssignments);

    if (!before) {
      throw new HttpError('errors.admission.not_found', 404);
    }

    if (before.status === 'DISCHARGED' || before.status === 'CANCELLED') {
      throw new HttpError('errors.admission.cannot_transfer_terminal_status', 400);
    }

    const updateData = {
      status: 'TRANSFERRED',
    };

    if (Object.prototype.hasOwnProperty.call(data, 'facility_id')) {
      updateData.facility_id = await resolveIdentifierForPayload({
        value: data.facility_id,
        field: 'facility_id',
        model: 'facility',
        where: { deleted_at: null },
        nullable: true,
      });
    }

    const admission = await admissionRepository.update(id, updateData);

    createAuditLog({
      user_id: userId,
      action: 'TRANSFER',
      entity: 'admission',
      entity_id: admission.id,
      diff: {
        before,
        after: admission,
        metadata: {
          notes: data.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return admission;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listAdmissions,
  getAdmissionById,
  createAdmission,
  updateAdmission,
  deleteAdmission,
  dischargeAdmission,
  transferAdmission,
};
