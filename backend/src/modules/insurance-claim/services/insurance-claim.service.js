/**
 * Insurance claim service
 *
 * @module modules/insurance-claim/services
 * @description Business logic layer for insurance claim operations.
 */

const insuranceClaimRepository = require('@repositories/insurance-claim/insurance-claim.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId,
} = require('@lib/billing/identifiers');

const CLAIM_INCLUDE = {
  coverage_plan: { select: { id: true, human_friendly_id: true, tenant_id: true } },
  invoice: {
    select: {
      id: true,
      human_friendly_id: true,
      tenant_id: true,
      patient_id: true,
      patient: { select: { id: true, human_friendly_id: true } },
    },
  },
};

const buildEmptyListResult = (page, limit) => ({
  insurance_claims: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const resolveTenantIdFromClaim = (record) =>
  record?.invoice?.tenant_id || record?.coverage_plan?.tenant_id || null;

const mapInsuranceClaimForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  return {
    ...record,
    display_id: resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id),
    coverage_plan_display_id: resolvePublicIdentifier(
      record?.coverage_plan_display_id,
      record?.coverage_plan?.human_friendly_id,
      record?.coverage_plan_id
    ),
    invoice_display_id: resolvePublicIdentifier(
      record?.invoice_display_id,
      record?.invoice?.human_friendly_id,
      record?.invoice_id
    ),
    patient_display_id: resolvePublicIdentifier(
      record?.patient_display_id,
      record?.invoice?.patient?.human_friendly_id,
      record?.invoice?.patient_id
    ),
    timeline_at: record?.timeline_at || record?.submitted_at || record?.created_at || null,
  };
};

/**
 * List insurance claims with pagination and filtering
 */
const listInsuranceClaims = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};

    if (filters.coverage_plan_id !== undefined) {
      const coveragePlanId = await resolveIdentifierForFilter({
        value: filters.coverage_plan_id,
        model: 'coverage_plan',
      });
      if (coveragePlanId === null) return buildEmptyListResult(page, limit);
      if (coveragePlanId !== undefined) whereClause.coverage_plan_id = coveragePlanId;
    }

    if (filters.invoice_id !== undefined) {
      const invoiceId = await resolveIdentifierForFilter({
        value: filters.invoice_id,
        model: 'invoice',
      });
      if (invoiceId === null) return buildEmptyListResult(page, limit);
      if (invoiceId !== undefined) whereClause.invoice_id = invoiceId;
    }

    if (filters.status) whereClause.status = filters.status;

    if (filters.submitted_at_from || filters.submitted_at_to) {
      whereClause.submitted_at = {};
      if (filters.submitted_at_from) whereClause.submitted_at.gte = new Date(filters.submitted_at_from);
      if (filters.submitted_at_to) whereClause.submitted_at.lte = new Date(filters.submitted_at_to);
    }

    const [insuranceClaims, total] = await Promise.all([
      insuranceClaimRepository.findMany(whereClause, skip, limit, orderBy, CLAIM_INCLUDE),
      insuranceClaimRepository.count(whereClause),
    ]);

    return {
      insurance_claims: insuranceClaims.map(mapInsuranceClaimForDisplay),
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
 * Get insurance claim by ID
 */
const getInsuranceClaimById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'insurance_claim',
      identifier: id,
    });

    const insuranceClaim = await insuranceClaimRepository.findById(resolvedId, CLAIM_INCLUDE);

    if (!insuranceClaim) {
      throw new HttpError('errors.insurance_claim.not_found', 404);
    }

    return mapInsuranceClaimForDisplay(insuranceClaim);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new insurance claim
 */
const createInsuranceClaim = async (data, userId, ipAddress) => {
  try {
    const coveragePlanId = await resolveIdentifierForPayload({
      value: data?.coverage_plan_id,
      field: 'coverage_plan_id',
      model: 'coverage_plan',
    });
    const invoiceId = await resolveIdentifierForPayload({
      value: data?.invoice_id,
      field: 'invoice_id',
      model: 'invoice',
    });

    const insuranceClaim = await insuranceClaimRepository.create({
      ...data,
      coverage_plan_id: coveragePlanId,
      invoice_id: invoiceId,
    });

    const createdRecord = await insuranceClaimRepository.findById(insuranceClaim.id, CLAIM_INCLUDE);

    createAuditLog({
      tenant_id: resolveTenantIdFromClaim(createdRecord),
      user_id: userId,
      action: 'CREATE',
      entity: 'insurance_claim',
      entity_id: insuranceClaim.id,
      diff: { after: insuranceClaim },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapInsuranceClaimForDisplay(createdRecord || insuranceClaim);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update insurance claim
 */
const updateInsuranceClaim = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'insurance_claim',
      identifier: id,
    });

    const before = await insuranceClaimRepository.findById(resolvedId, CLAIM_INCLUDE);

    if (!before) {
      throw new HttpError('errors.insurance_claim.not_found', 404);
    }

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'coverage_plan_id')) {
      payload.coverage_plan_id = await resolveIdentifierForPayload({
        value: payload.coverage_plan_id,
        field: 'coverage_plan_id',
        model: 'coverage_plan',
      });
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'invoice_id')) {
      payload.invoice_id = await resolveIdentifierForPayload({
        value: payload.invoice_id,
        field: 'invoice_id',
        model: 'invoice',
      });
    }

    const insuranceClaim = await insuranceClaimRepository.update(before.id, payload);
    const updatedRecord = await insuranceClaimRepository.findById(insuranceClaim.id, CLAIM_INCLUDE);

    createAuditLog({
      tenant_id: resolveTenantIdFromClaim(updatedRecord) || resolveTenantIdFromClaim(before),
      user_id: userId,
      action: 'UPDATE',
      entity: 'insurance_claim',
      entity_id: insuranceClaim.id,
      diff: { before, after: insuranceClaim },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapInsuranceClaimForDisplay(updatedRecord || insuranceClaim);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete insurance claim (soft delete)
 */
const deleteInsuranceClaim = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'insurance_claim',
      identifier: id,
    });

    const before = await insuranceClaimRepository.findById(resolvedId, CLAIM_INCLUDE);

    if (!before) {
      throw new HttpError('errors.insurance_claim.not_found', 404);
    }

    await insuranceClaimRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: resolveTenantIdFromClaim(before),
      user_id: userId,
      action: 'DELETE',
      entity: 'insurance_claim',
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
 * Submit insurance claim
 */
const submitInsuranceClaim = async (id, data = {}, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'insurance_claim',
      identifier: id,
    });

    const before = await insuranceClaimRepository.findById(resolvedId, CLAIM_INCLUDE);

    if (!before) {
      throw new HttpError('errors.insurance_claim.not_found', 404);
    }

    if (before.status === 'CANCELLED') {
      throw new HttpError('errors.insurance_claim.cannot_submit_cancelled', 400);
    }

    const insuranceClaim = await insuranceClaimRepository.update(before.id, {
      status: 'SUBMITTED',
      submitted_at: data.submitted_at ? new Date(data.submitted_at) : new Date(),
    });
    const updatedRecord = await insuranceClaimRepository.findById(insuranceClaim.id, CLAIM_INCLUDE);

    createAuditLog({
      tenant_id: resolveTenantIdFromClaim(updatedRecord) || resolveTenantIdFromClaim(before),
      user_id: userId,
      action: 'SUBMIT',
      entity: 'insurance_claim',
      entity_id: insuranceClaim.id,
      diff: {
        before,
        after: insuranceClaim,
        metadata: {
          notes: data.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapInsuranceClaimForDisplay(updatedRecord || insuranceClaim);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Reconcile insurance claim
 */
const reconcileInsuranceClaim = async (id, data = {}, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'insurance_claim',
      identifier: id,
    });

    const before = await insuranceClaimRepository.findById(resolvedId, CLAIM_INCLUDE);

    if (!before) {
      throw new HttpError('errors.insurance_claim.not_found', 404);
    }

    if (before.status === 'CANCELLED') {
      throw new HttpError('errors.insurance_claim.cannot_reconcile_cancelled', 400);
    }

    const insuranceClaim = await insuranceClaimRepository.update(before.id, {
      status: data.status || 'PAID',
    });
    const updatedRecord = await insuranceClaimRepository.findById(insuranceClaim.id, CLAIM_INCLUDE);

    createAuditLog({
      tenant_id: resolveTenantIdFromClaim(updatedRecord) || resolveTenantIdFromClaim(before),
      user_id: userId,
      action: 'RECONCILE',
      entity: 'insurance_claim',
      entity_id: insuranceClaim.id,
      diff: {
        before,
        after: insuranceClaim,
        metadata: {
          notes: data.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapInsuranceClaimForDisplay(updatedRecord || insuranceClaim);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listInsuranceClaims,
  getInsuranceClaimById,
  createInsuranceClaim,
  updateInsuranceClaim,
  deleteInsuranceClaim,
  submitInsuranceClaim,
  reconcileInsuranceClaim,
};
