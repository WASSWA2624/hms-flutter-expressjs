/**
 * Pre-authorization service
 *
 * @module modules/pre-authorization/services
 * @description Business logic layer for pre-authorization operations.
 */

const preAuthorizationRepository = require('@repositories/pre-authorization/pre-authorization.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolvePublicIdentifier,
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
  resolveEntityId} = require('@lib/billing/identifiers');
const { toDecimalNumber, toMoneyString, roundMoney } = require('@lib/billing/financials');
const { remainingAmount } = require('@lib/billing/pre-authorization-billing');
const { publishBillingRealtimeUpdate } = require('@lib/billing/realtime');
const { BILLING_EVENTS } = require('@lib/websocket');

const PRE_AUTH_INCLUDE = {
  coverage_plan: { select: { id: true, human_friendly_id: true, tenant_id: true, name: true, provider_name: true } },
  patient: { select: { id: true, human_friendly_id: true, first_name: true, last_name: true } },
  encounter: { select: { id: true, human_friendly_id: true } },
  admission: { select: { id: true, human_friendly_id: true } }};

const buildEmptyListResult = (page, limit) => ({
  pre_authorizations: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1}});

const resolveTenantIdFromPreAuthorization = (record) => record?.coverage_plan?.tenant_id || null;

const mapPreAuthorizationForDisplay = (record) => {
  if (!record || typeof record !== 'object') return record;

  const approved =
    record.approved_amount === null || record.approved_amount === undefined
      ? null
      : toDecimalNumber(record.approved_amount);
  const consumed =
    record.consumed_amount === null || record.consumed_amount === undefined
      ? null
      : toDecimalNumber(record.consumed_amount);
  const remaining = remainingAmount(record);

  return {
    ...record,
    display_id: resolvePublicIdentifier(record?.display_id, record?.human_friendly_id, record?.id),
    coverage_plan_display_id: resolvePublicIdentifier(
      record?.coverage_plan_display_id,
      record?.coverage_plan?.human_friendly_id,
      record?.coverage_plan_id
    ),
    patient_display_id: resolvePublicIdentifier(
      record?.patient_display_id,
      record?.patient?.human_friendly_id,
      record?.patient_id
    ),
    encounter_display_id: resolvePublicIdentifier(
      record?.encounter_display_id,
      record?.encounter?.human_friendly_id,
      record?.encounter_id
    ),
    admission_display_id: resolvePublicIdentifier(
      record?.admission_display_id,
      record?.admission?.human_friendly_id,
      record?.admission_id
    ),
    approved_amount: approved === null ? null : toMoneyString(approved),
    consumed_amount: consumed === null ? null : toMoneyString(consumed),
    remaining_amount: remaining === null ? null : toMoneyString(remaining),
    timeline_at: record?.timeline_at || record?.approved_at || record?.requested_at || record?.created_at || null};
};

const resolveOptionalIdentifier = async ({ value, field, model }) => {
  if (value === undefined) return undefined;
  if (value === null || String(value).trim() === '') return null;
  return resolveIdentifierForPayload({ value, field, model });
};

const assertApprovedAmountWhenRequired = (payload = {}, before = {}) => {
  const nextStatus = String(payload.status || before.status || '')
    .trim()
    .toUpperCase();
  if (nextStatus !== 'APPROVED' && nextStatus !== 'PARTIAL') {
    return;
  }
  const amount =
    payload.approved_amount !== undefined
      ? payload.approved_amount
      : before.approved_amount;
  if (amount === null || amount === undefined || amount === '') {
    throw new HttpError('errors.pre_authorization.approved_amount_required', 400);
  }
  if (roundMoney(toDecimalNumber(amount)) < 0) {
    throw new HttpError('errors.pre_authorization.approved_amount_required', 400);
  }
};

const publishPreAuthorizationBillingRealtime = async (record, userId) => {
  const tenantId = resolveTenantIdFromPreAuthorization(record);
  if (!tenantId) {
    return;
  }
  await publishBillingRealtimeUpdate({
    event: BILLING_EVENTS.BILLING_BALANCE_UPDATED,
    action: 'PRE_AUTH_UPDATED',
    invoice: {
      id: record?.id || null,
      human_friendly_id: record?.human_friendly_id || record?.display_id || null,
      tenant_id: tenantId,
      facility_id: null,
      patient_id: record?.patient_id || null,
      total_amount: record?.approved_amount ?? null,
      billing_status: record?.status || null,
      status: record?.status || null,
      patient: record?.patient || null,
    },
    actorUserId: userId || null,
  });
};

/**
 * List pre-authorizations with pagination and filtering
 */
const listPreAuthorizations = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};

    if (filters.coverage_plan_id !== undefined) {
      const coveragePlanId = await resolveIdentifierForFilter({
        value: filters.coverage_plan_id,
        model: 'coverage_plan'});
      if (coveragePlanId === null) return buildEmptyListResult(page, limit);
      if (coveragePlanId !== undefined) whereClause.coverage_plan_id = coveragePlanId;
    }

    if (filters.patient_id !== undefined) {
      const patientId = await resolveIdentifierForFilter({
        value: filters.patient_id,
        model: 'patient'});
      if (patientId === null) return buildEmptyListResult(page, limit);
      if (patientId !== undefined) whereClause.patient_id = patientId;
    }

    if (filters.encounter_id !== undefined) {
      const encounterId = await resolveIdentifierForFilter({
        value: filters.encounter_id,
        model: 'encounter'});
      if (encounterId === null) return buildEmptyListResult(page, limit);
      if (encounterId !== undefined) whereClause.encounter_id = encounterId;
    }

    if (filters.admission_id !== undefined) {
      const admissionId = await resolveIdentifierForFilter({
        value: filters.admission_id,
        model: 'admission'});
      if (admissionId === null) return buildEmptyListResult(page, limit);
      if (admissionId !== undefined) whereClause.admission_id = admissionId;
    }

    if (filters.status) whereClause.status = filters.status;

    if (filters.requested_at_from || filters.requested_at_to) {
      whereClause.requested_at = {};
      if (filters.requested_at_from) whereClause.requested_at.gte = new Date(filters.requested_at_from);
      if (filters.requested_at_to) whereClause.requested_at.lte = new Date(filters.requested_at_to);
    }

    if (filters.approved_at_from || filters.approved_at_to) {
      whereClause.approved_at = {};
      if (filters.approved_at_from) whereClause.approved_at.gte = new Date(filters.approved_at_from);
      if (filters.approved_at_to) whereClause.approved_at.lte = new Date(filters.approved_at_to);
    }

    const [preAuthorizations, total] = await Promise.all([
      preAuthorizationRepository.findMany(whereClause, skip, limit, orderBy, PRE_AUTH_INCLUDE),
      preAuthorizationRepository.count(whereClause)]);

    return {
      pre_authorizations: preAuthorizations.map(mapPreAuthorizationForDisplay),
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1}};
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get pre-authorization by ID
 */
const getPreAuthorizationById = async (id) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'pre_authorization',
      identifier: id});

    const preAuthorization = await preAuthorizationRepository.findById(resolvedId, PRE_AUTH_INCLUDE);

    if (!preAuthorization) {
      throw new HttpError('errors.pre_authorization.not_found', 404);
    }

    return mapPreAuthorizationForDisplay(preAuthorization);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new pre-authorization
 */
const createPreAuthorization = async (data, userId, ipAddress) => {
  try {
    const coveragePlanId = await resolveIdentifierForPayload({
      value: data?.coverage_plan_id,
      field: 'coverage_plan_id',
      model: 'coverage_plan'});

    const payload = { ...data, coverage_plan_id: coveragePlanId };
    payload.patient_id = await resolveOptionalIdentifier({
      value: data?.patient_id,
      field: 'patient_id',
      model: 'patient'});
    payload.encounter_id = await resolveOptionalIdentifier({
      value: data?.encounter_id,
      field: 'encounter_id',
      model: 'encounter'});
    payload.admission_id = await resolveOptionalIdentifier({
      value: data?.admission_id,
      field: 'admission_id',
      model: 'admission'});

    // When an insurer integration is configured, request authorization via adapter.
    // Manual Claims desk still works without an integration (status stays PENDING).
    let adapterResult = null;
    try {
      const prisma = require('@prisma/client');
      const { getInsurerAdapter } = require('@lib/insurer/adapter');
      const coveragePlan = await prisma.coverage_plan.findFirst({
        where: { id: coveragePlanId, deleted_at: null },
        include: { insurance_company: true }});
      const tenantId = coveragePlan?.tenant_id || null;
      if (tenantId) {
        const integrations = await prisma.insurer_integration.findMany({
          where: {
            deleted_at: null,
            is_enabled: true,
            tenant_id: tenantId,
            OR: [
              { coverage_plan_id: coveragePlanId },
              { coverage_plan_id: null },
              ...(coveragePlan?.insurance_company_id
                ? [{ insurance_company_id: coveragePlan.insurance_company_id }]
                : [])]},
          orderBy: { updated_at: 'desc' }});
        const integration =
          integrations.find((row) => row.coverage_plan_id === coveragePlanId) ||
          integrations.find(
            (row) =>
              coveragePlan?.insurance_company_id &&
              row.insurance_company_id === coveragePlan.insurance_company_id
          ) ||
          integrations.find((row) => !row.coverage_plan_id && !row.insurance_company_id) ||
          integrations[0] ||
          null;

        if (integration) {
          const adapter = getInsurerAdapter(integration);
          let memberId = null;
          if (payload.patient_id) {
            const enrollment = await prisma.patient_insurance_enrollment.findFirst({
              where: {
                deleted_at: null,
                patient_id: payload.patient_id,
                coverage_plan_id: coveragePlanId},
              orderBy: [{ is_primary: 'desc' }, { updated_at: 'desc' }]});
            memberId = enrollment?.member_id || null;
          }
          adapterResult = await adapter.authorize({
            memberId,
            amount: payload.approved_amount ?? null,
            reason: payload.reason || null,
            coveragePlan});
          if (adapterResult?.status === 'DENIED' || adapterResult?.approved === false) {
            payload.status = 'DENIED';
          } else if (adapterResult?.status === 'PARTIAL') {
            payload.status = 'PARTIAL';
          } else if (adapterResult?.approved) {
            payload.status = payload.status || 'APPROVED';
            if (!payload.approved_at) payload.approved_at = new Date();
          }
          if (adapterResult?.approvedAmount != null && payload.approved_amount == null) {
            payload.approved_amount = adapterResult.approvedAmount;
          }
          if (adapterResult?.reference) {
            payload.insurer_reference = adapterResult.reference;
          }
        }
      }
    } catch (_) {
      // Adapter failures must not block manual pre-auth creation.
      adapterResult = null;
    }

    if (!payload.status) {
      payload.status = 'PENDING';
    }

    assertApprovedAmountWhenRequired(payload, {});

    const preAuthorization = await preAuthorizationRepository.create(payload);

    const createdRecord = await preAuthorizationRepository.findById(preAuthorization.id, PRE_AUTH_INCLUDE);

    createAuditLog({
      tenant_id: resolveTenantIdFromPreAuthorization(createdRecord),
      user_id: userId,
      action: 'CREATE',
      entity: 'pre_authorization',
      entity_id: preAuthorization.id,
      diff: { after: preAuthorization, adapter: adapterResult },
      ip_address: ipAddress}).catch(() => {});

    const mapped = mapPreAuthorizationForDisplay(createdRecord || preAuthorization);
    await publishPreAuthorizationBillingRealtime(createdRecord || mapped, userId);
    return mapped;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update pre-authorization
 */
const updatePreAuthorization = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'pre_authorization',
      identifier: id});

    const before = await preAuthorizationRepository.findById(resolvedId, PRE_AUTH_INCLUDE);

    if (!before) {
      throw new HttpError('errors.pre_authorization.not_found', 404);
    }

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'coverage_plan_id')) {
      payload.coverage_plan_id = await resolveIdentifierForPayload({
        value: payload.coverage_plan_id,
        field: 'coverage_plan_id',
        model: 'coverage_plan'});
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'patient_id')) {
      payload.patient_id = await resolveOptionalIdentifier({
        value: payload.patient_id,
        field: 'patient_id',
        model: 'patient'});
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'encounter_id')) {
      payload.encounter_id = await resolveOptionalIdentifier({
        value: payload.encounter_id,
        field: 'encounter_id',
        model: 'encounter'});
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'admission_id')) {
      payload.admission_id = await resolveOptionalIdentifier({
        value: payload.admission_id,
        field: 'admission_id',
        model: 'admission'});
    }

    if (payload.status === 'APPROVED' && !payload.approved_at) {
      payload.approved_at = new Date();
    }
    if (payload.status === 'PARTIAL' && !payload.approved_at && !before.approved_at) {
      payload.approved_at = new Date();
    }

    assertApprovedAmountWhenRequired(payload, before);

    const preAuthorization = await preAuthorizationRepository.update(before.id, payload);
    const updatedRecord = await preAuthorizationRepository.findById(preAuthorization.id, PRE_AUTH_INCLUDE);

    createAuditLog({
      tenant_id: resolveTenantIdFromPreAuthorization(updatedRecord) || resolveTenantIdFromPreAuthorization(before),
      user_id: userId,
      action: 'UPDATE',
      entity: 'pre_authorization',
      entity_id: preAuthorization.id,
      diff: { before, after: preAuthorization },
      ip_address: ipAddress}).catch(() => {});

    const mapped = mapPreAuthorizationForDisplay(updatedRecord || preAuthorization);
    await publishPreAuthorizationBillingRealtime(updatedRecord || mapped, userId);
    return mapped;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete pre-authorization (soft delete)
 */
const deletePreAuthorization = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveEntityId({
      model: 'pre_authorization',
      identifier: id});

    const before = await preAuthorizationRepository.findById(resolvedId, PRE_AUTH_INCLUDE);

    if (!before) {
      throw new HttpError('errors.pre_authorization.not_found', 404);
    }

    await preAuthorizationRepository.softDelete(before.id);

    createAuditLog({
      tenant_id: resolveTenantIdFromPreAuthorization(before),
      user_id: userId,
      action: 'DELETE',
      entity: 'pre_authorization',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress}).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listPreAuthorizations,
  getPreAuthorizationById,
  createPreAuthorization,
  updatePreAuthorization,
  deletePreAuthorization};
