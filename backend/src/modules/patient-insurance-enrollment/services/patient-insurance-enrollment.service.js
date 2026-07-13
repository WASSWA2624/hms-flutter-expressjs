/**
 * Patient Insurance Enrollment service
 *
 * @module modules/patient-insurance-enrollment/services
 * @description Business logic layer for patient insurance enrollment operations.
 */

const prisma = require('@prisma/client');
const patientInsuranceEnrollmentRepository = require('@repositories/patient-insurance-enrollment/patient-insurance-enrollment.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  sanitizeIdentifier,
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');
const { getInsurerAdapter } = require('@lib/insurer/adapter');

const ENROLLMENT_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true } },
  facility: { select: { id: true, human_friendly_id: true, name: true } },
  patient: {
    select: {
      id: true,
      human_friendly_id: true,
      first_name: true,
      last_name: true,
    },
  },
  coverage_plan: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      provider_name: true,
      coverage_percentage: true,
    },
  },
};

const buildEmptyListResult = (page, limit) => ({
  enrollments: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const mapEnrollmentForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    ...record,
    display_id: resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id),
    tenant_display_id: resolvePublicIdentifier(
      record?.tenant_display_id,
      record?.tenant?.human_friendly_id,
      record?.tenant_id
    ),
    facility_display_id: resolvePublicIdentifier(
      record?.facility_display_id,
      record?.facility?.human_friendly_id,
      record?.facility_id
    ),
    patient_display_id: resolvePublicIdentifier(
      record?.patient_display_id,
      record?.patient?.human_friendly_id,
      record?.patient_id
    ),
    coverage_plan_display_id: resolvePublicIdentifier(
      record?.coverage_plan_display_id,
      record?.coverage_plan?.human_friendly_id,
      record?.coverage_plan_id
    ),
    timeline_at: record?.timeline_at || record?.verified_at || record?.valid_from || record?.created_at || null,
  };
};

const normalizeCreatePayload = async (data = {}) => {
  const payload = {
    ...data,
    tenant_id: await resolveIdentifierForPayload({
      value: data.tenant_id,
      model: 'tenant',
      field: 'tenant_id',
    }),
    facility_id: await resolveIdentifierForPayload({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      nullable: true,
    }),
    patient_id: await resolveIdentifierForPayload({
      value: data.patient_id,
      model: 'patient',
      field: 'patient_id',
    }),
    coverage_plan_id: await resolveIdentifierForPayload({
      value: data.coverage_plan_id,
      model: 'coverage_plan',
      field: 'coverage_plan_id',
    }),
  };

  if (payload.valid_from) payload.valid_from = new Date(payload.valid_from);
  if (payload.valid_to) payload.valid_to = new Date(payload.valid_to);

  return payload;
};

const normalizeUpdatePayload = async (data = {}) => {
  const payload = { ...data };

  if (Object.prototype.hasOwnProperty.call(data, 'facility_id')) {
    payload.facility_id = await resolveIdentifierForPayload({
      value: data.facility_id,
      model: 'facility',
      field: 'facility_id',
      nullable: true,
    });
  }

  if (Object.prototype.hasOwnProperty.call(data, 'patient_id')) {
    payload.patient_id = await resolveIdentifierForPayload({
      value: data.patient_id,
      model: 'patient',
      field: 'patient_id',
    });
  }

  if (Object.prototype.hasOwnProperty.call(data, 'coverage_plan_id')) {
    payload.coverage_plan_id = await resolveIdentifierForPayload({
      value: data.coverage_plan_id,
      model: 'coverage_plan',
      field: 'coverage_plan_id',
    });
  }

  if (Object.prototype.hasOwnProperty.call(data, 'valid_from') && data.valid_from) {
    payload.valid_from = new Date(data.valid_from);
  }

  if (Object.prototype.hasOwnProperty.call(data, 'valid_to') && data.valid_to) {
    payload.valid_to = new Date(data.valid_to);
  }

  return payload;
};

/**
 * Prefer integrations that match facility and/or coverage plan.
 */
const pickPreferredIntegration = (integrations = [], enrollment = {}) => {
  if (!Array.isArray(integrations) || integrations.length === 0) return null;

  const scored = integrations.map((integration) => {
    let score = 0;
    if (
      enrollment.facility_id &&
      integration.facility_id &&
      integration.facility_id === enrollment.facility_id
    ) {
      score += 20;
    } else if (integration.facility_id) {
      score -= 5;
    }

    if (
      enrollment.coverage_plan_id &&
      integration.coverage_plan_id &&
      integration.coverage_plan_id === enrollment.coverage_plan_id
    ) {
      score += 30;
    } else if (integration.coverage_plan_id) {
      score -= 5;
    }

    return { integration, score };
  });

  scored.sort((a, b) => b.score - a.score);
  return scored[0]?.integration || integrations[0];
};

/**
 * List patient insurance enrollments with pagination and filtering
 */
const listPatientInsuranceEnrollments = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};

    if (filters.tenant_id !== undefined) {
      const tenantId = await resolveIdentifierForFilter({
        value: filters.tenant_id,
        model: 'tenant',
      });
      if (tenantId === null) return buildEmptyListResult(page, limit);
      if (tenantId !== undefined) whereClause.tenant_id = tenantId;
    }

    if (filters.facility_id !== undefined) {
      const facilityId = await resolveIdentifierForFilter({
        value: filters.facility_id,
        model: 'facility',
        where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {},
      });
      if (facilityId === null) return buildEmptyListResult(page, limit);
      if (facilityId !== undefined) whereClause.facility_id = facilityId;
    }

    if (filters.patient_id !== undefined) {
      const patientId = await resolveIdentifierForFilter({
        value: filters.patient_id,
        model: 'patient',
        where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {},
      });
      if (patientId === null) return buildEmptyListResult(page, limit);
      if (patientId !== undefined) whereClause.patient_id = patientId;
    }

    if (filters.coverage_plan_id !== undefined) {
      const coveragePlanId = await resolveIdentifierForFilter({
        value: filters.coverage_plan_id,
        model: 'coverage_plan',
        where: whereClause.tenant_id ? { tenant_id: whereClause.tenant_id } : {},
      });
      if (coveragePlanId === null) return buildEmptyListResult(page, limit);
      if (coveragePlanId !== undefined) whereClause.coverage_plan_id = coveragePlanId;
    }

    if (filters.member_id) whereClause.member_id = filters.member_id;
    if (filters.status) whereClause.status = filters.status;

    const search = sanitizeIdentifier(filters.search);
    if (search) {
      whereClause.OR = [
        { member_id: { contains: search } },
        { notes: { contains: search } },
        { human_friendly_id: { contains: search.toUpperCase() } },
      ];
    }

    const [enrollments, total] = await Promise.all([
      patientInsuranceEnrollmentRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        ENROLLMENT_INCLUDE
      ),
      patientInsuranceEnrollmentRepository.count(whereClause),
    ]);

    return {
      enrollments: enrollments.map(mapEnrollmentForDisplay),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1,
      },
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get patient insurance enrollment by ID
 */
const getPatientInsuranceEnrollmentById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'patient_insurance_enrollment',
      identifier: id,
    });

    const enrollment = await patientInsuranceEnrollmentRepository.findById(
      resolvedId,
      ENROLLMENT_INCLUDE
    );

    if (!enrollment) {
      throw new HttpError('errors.patient_insurance_enrollment.not_found', 404);
    }

    return mapEnrollmentForDisplay(enrollment);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new patient insurance enrollment
 */
const createPatientInsuranceEnrollment = async (data, userId, ipAddress) => {
  try {
    const payload = await normalizeCreatePayload(data);
    const enrollment = await patientInsuranceEnrollmentRepository.create(payload);
    const createdRecord = await patientInsuranceEnrollmentRepository.findById(
      enrollment.id,
      ENROLLMENT_INCLUDE
    );

    createAuditLog({
      tenant_id: enrollment.tenant_id,
      user_id: userId,
      action: 'CREATE',
      entity: 'patient_insurance_enrollment',
      entity_id: enrollment.id,
      diff: { after: enrollment },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapEnrollmentForDisplay(createdRecord || enrollment);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update patient insurance enrollment
 */
const updatePatientInsuranceEnrollment = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'patient_insurance_enrollment',
      identifier: id,
    });

    const before = await patientInsuranceEnrollmentRepository.findById(
      resolvedId,
      ENROLLMENT_INCLUDE
    );

    if (!before) {
      throw new HttpError('errors.patient_insurance_enrollment.not_found', 404);
    }

    const payload = await normalizeUpdatePayload(data);
    const enrollment = await patientInsuranceEnrollmentRepository.update(before.id, payload);
    const updatedRecord = await patientInsuranceEnrollmentRepository.findById(
      enrollment.id,
      ENROLLMENT_INCLUDE
    );

    createAuditLog({
      tenant_id: enrollment.tenant_id || before.tenant_id,
      user_id: userId,
      action: 'UPDATE',
      entity: 'patient_insurance_enrollment',
      entity_id: enrollment.id,
      diff: { before, after: enrollment },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapEnrollmentForDisplay(updatedRecord || enrollment);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete patient insurance enrollment (soft delete)
 */
const deletePatientInsuranceEnrollment = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'patient_insurance_enrollment',
      identifier: id,
    });

    const before = await patientInsuranceEnrollmentRepository.findById(
      resolvedId,
      ENROLLMENT_INCLUDE
    );

    if (!before) {
      throw new HttpError('errors.patient_insurance_enrollment.not_found', 404);
    }

    await patientInsuranceEnrollmentRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: before.tenant_id,
      user_id: userId,
      action: 'DELETE',
      entity: 'patient_insurance_enrollment',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Verify enrollment eligibility via insurer adapter
 */
const verifyPatientInsuranceEnrollment = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'patient_insurance_enrollment',
      identifier: id,
    });

    const enrollment = await patientInsuranceEnrollmentRepository.findById(
      resolvedId,
      ENROLLMENT_INCLUDE
    );

    if (!enrollment) {
      throw new HttpError('errors.patient_insurance_enrollment.not_found', 404);
    }

    const integrations = await prisma.insurer_integration.findMany({
      where: {
        deleted_at: null,
        is_enabled: true,
        tenant_id: enrollment.tenant_id,
      },
      orderBy: { created_at: 'desc' },
    });

    const integration = pickPreferredIntegration(integrations, enrollment);

    if (!integration) {
      throw new HttpError('errors.insurer_integration.not_found', 404, [
        { reason: 'No enabled insurer integration for tenant' },
      ]);
    }

    const adapter = getInsurerAdapter(integration);
    const eligibility = await adapter.checkEligibility({
      memberId: enrollment.member_id,
      coveragePlan: enrollment.coverage_plan,
    });

    const nextStatus = eligibility?.eligible ? 'ACTIVE' : 'EXPIRED';
    const verifiedAt = new Date();

    const updated = await patientInsuranceEnrollmentRepository.update(enrollment.id, {
      status: nextStatus,
      verified_at: verifiedAt,
      last_verified_via: adapter.name || integration.adapter_type || 'STUB',
    });

    const updatedRecord = await patientInsuranceEnrollmentRepository.findById(
      updated.id,
      ENROLLMENT_INCLUDE
    );

    createAuditLog({
      tenant_id: enrollment.tenant_id,
      user_id: userId,
      action: 'UPDATE',
      entity: 'patient_insurance_enrollment',
      entity_id: enrollment.id,
      diff: {
        before: enrollment,
        after: updated,
        eligibility,
        integration_id: integration.id,
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return {
      enrollment: mapEnrollmentForDisplay(updatedRecord || updated),
      eligibility,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listPatientInsuranceEnrollments,
  getPatientInsuranceEnrollmentById,
  createPatientInsuranceEnrollment,
  updatePatientInsuranceEnrollment,
  deletePatientInsuranceEnrollment,
  verifyPatientInsuranceEnrollment,
};
