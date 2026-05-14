/**
 * Visit queue service
 *
 * @module modules/visit-queue/services
 * @description Business logic layer for visit queue operations.
 * Per module-creation.mdc: Only import/use its own repository, call audit logging for mutations.
 * Per prisma.mdc: Use $transaction for multi-step mutations.
 */

const visitQueueRepository = require('@repositories/visit-queue/visit-queue.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { isUuidLike } = require('@lib/identifiers/sanitize-friendly-ids');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

const USER_IDENTIFIER_MATCHERS = [({ rawValue }) => ({ email: rawValue }), ({ rawValue }) => ({ phone: rawValue })];
const ALLOWED_VISIT_QUEUE_SORT_FIELDS = new Set([
  'created_at',
  'updated_at',
  'queued_at',
  'status',
]);

const resolveSortBy = (value, fallback = 'queued_at') => {
  const normalized = String(value || '').trim();
  return ALLOWED_VISIT_QUEUE_SORT_FIELDS.has(normalized) ? normalized : fallback;
};

const resolveSortOrder = (value, fallback = 'desc') => {
  const normalized = String(value || '').trim().toLowerCase();
  if (normalized === 'asc' || normalized === 'desc') return normalized;
  return fallback;
};

const toPositiveInteger = (value, fallback) => {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return parsed;
};

const resolveDisplayName = (firstName, middleName, lastName) =>
  [firstName, middleName, lastName]
    .map((entry) => (typeof entry === 'string' ? entry.trim() : ''))
    .filter(Boolean)
    .join(' ');

const appendIfPresent = (target, key, value) => {
  if (value === undefined || value === null || value === '') return;
  target[key] = value;
};

const toDecimalNumber = (value) => {
  if (value === undefined || value === null) return 0;
  if (typeof value === 'number') return Number.isFinite(value) ? value : 0;
  if (typeof value === 'string') {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  if (typeof value?.toNumber === 'function') {
    try {
      const parsed = value.toNumber();
      return Number.isFinite(parsed) ? parsed : 0;
    } catch (error) {
      return 0;
    }
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
};

const normalizeUpper = (value) => String(value || '').trim().toUpperCase();

const PAYMENT_PAID_STATUSES = new Set([
  'COMPLETED',
  'PAID',
  'SUCCESS',
  'SUCCESSFUL',
  'APPROVED',
]);

const resolvePrimaryRecord = (records = []) => {
  if (!Array.isArray(records)) return null;
  return records.find((record) => record?.is_primary) || records[0] || null;
};

const resolveLatestInvoice = (invoices = []) => {
  if (!Array.isArray(invoices) || invoices.length === 0) return null;
  return invoices[0] || null;
};

const resolveInvoicePaymentSummary = (invoice = null) => {
  if (!invoice) return null;

  const payments = Array.isArray(invoice.payments) ? invoice.payments : [];
  const latestPayment = payments[0] || null;
  const paidAmount = payments.reduce((total, payment) => {
    const paymentStatus = normalizeUpper(payment?.status);
    if (!PAYMENT_PAID_STATUSES.has(paymentStatus)) return total;
    return total + toDecimalNumber(payment?.amount);
  }, 0);
  const totalAmount = toDecimalNumber(invoice?.total_amount);
  const amountToPay = Math.max(totalAmount - paidAmount, 0);

  return {
    latestPayment,
    totalAmount,
    paidAmount,
    amountToPay,
    hasOutstandingBalance: amountToPay > 0.009,
  };
};

const resolveReceptionFlow = (patient = null) => {
  const extension =
    patient?.extension_json && typeof patient.extension_json === 'object'
      ? patient.extension_json
      : {};
  const receptionFlow =
    extension?.reception_flow && typeof extension.reception_flow === 'object'
      ? extension.reception_flow
      : {};

  return {
    category: normalizeUpper(receptionFlow?.category) || null,
    label: receptionFlow?.label || receptionFlow?.category || null,
    notes: receptionFlow?.notes || null,
    registered_at: receptionFlow?.registered_at || null,
  };
};

const withVisitQueueProjection = (entry) => {
  if (!entry || typeof entry !== 'object') return entry;

  const primaryContact = resolvePrimaryRecord(entry?.patient?.contacts);
  const primaryIdentifier = resolvePrimaryRecord(entry?.patient?.identifiers);
  const latestInvoice = resolveLatestInvoice(entry?.patient?.invoices);
  const paymentSummary = resolveInvoicePaymentSummary(latestInvoice);
  const latestPayment = paymentSummary?.latestPayment || null;
  const receptionFlow = resolveReceptionFlow(entry?.patient);

  const projected = { ...entry };
  appendIfPresent(projected, 'tenant_human_friendly_id', entry?.tenant?.human_friendly_id);
  appendIfPresent(projected, 'tenant_name', entry?.tenant?.name);
  appendIfPresent(projected, 'facility_human_friendly_id', entry?.facility?.human_friendly_id);
  appendIfPresent(projected, 'facility_name', entry?.facility?.name);
  appendIfPresent(projected, 'patient_human_friendly_id', entry?.patient?.human_friendly_id);
  appendIfPresent(
    projected,
    'patient_display_name',
    resolveDisplayName(entry?.patient?.first_name, null, entry?.patient?.last_name)
  );
  appendIfPresent(projected, 'patient_first_name', entry?.patient?.first_name);
  appendIfPresent(projected, 'patient_last_name', entry?.patient?.last_name);
  appendIfPresent(projected, 'patient_date_of_birth', entry?.patient?.date_of_birth);
  appendIfPresent(projected, 'patient_gender', entry?.patient?.gender);
  appendIfPresent(projected, 'patient_primary_phone', primaryContact?.value);
  appendIfPresent(projected, 'patient_primary_contact_type', primaryContact?.contact_type);
  appendIfPresent(projected, 'patient_primary_identifier', primaryIdentifier?.identifier_value);
  appendIfPresent(projected, 'patient_primary_identifier_type', primaryIdentifier?.identifier_type);
  appendIfPresent(projected, 'patient_flow_category', receptionFlow.category);
  appendIfPresent(projected, 'patient_flow_label', receptionFlow.label);
  appendIfPresent(projected, 'patient_flow_notes', receptionFlow.notes);
  appendIfPresent(projected, 'patient_registered_at', receptionFlow.registered_at);
  appendIfPresent(projected, 'appointment_human_friendly_id', entry?.appointment?.human_friendly_id);
  appendIfPresent(projected, 'appointment_status', entry?.appointment?.status);
  appendIfPresent(projected, 'appointment_reason', entry?.appointment?.reason);
  appendIfPresent(projected, 'appointment_scheduled_start', entry?.appointment?.scheduled_start);
  appendIfPresent(projected, 'appointment_scheduled_end', entry?.appointment?.scheduled_end);
  appendIfPresent(projected, 'provider_human_friendly_id', entry?.provider?.human_friendly_id);
  appendIfPresent(
    projected,
    'provider_display_name',
    resolveDisplayName(
      entry?.provider?.profile?.first_name,
      entry?.provider?.profile?.middle_name,
      entry?.provider?.profile?.last_name
    )
  );
  appendIfPresent(projected, 'provider_email', entry?.provider?.email);
  appendIfPresent(projected, 'provider_phone', entry?.provider?.phone);
  appendIfPresent(projected, 'invoice_human_friendly_id', latestInvoice?.human_friendly_id);
  appendIfPresent(projected, 'invoice_status', latestInvoice?.status);
  appendIfPresent(projected, 'billing_status', latestInvoice?.billing_status);
  appendIfPresent(projected, 'currency', latestInvoice?.currency);
  appendIfPresent(projected, 'total_amount', paymentSummary?.totalAmount);
  appendIfPresent(projected, 'amount_paid', paymentSummary?.paidAmount);
  appendIfPresent(projected, 'amount_to_pay', paymentSummary?.amountToPay);
  appendIfPresent(projected, 'has_outstanding_balance', paymentSummary?.hasOutstandingBalance);
  appendIfPresent(projected, 'payment_human_friendly_id', latestPayment?.human_friendly_id);
  appendIfPresent(projected, 'payment_status', latestPayment?.status || latestInvoice?.billing_status || latestInvoice?.status);
  appendIfPresent(projected, 'payment_method', latestPayment?.method);
  appendIfPresent(projected, 'payment_paid_at', latestPayment?.paid_at);
  return projected;
};

const withVisitQueueProjectionList = (entries = []) =>
  (Array.isArray(entries) ? entries : []).map((entry) => withVisitQueueProjection(entry));

const buildEmptyListResult = (page, limit) => ({
  entries: [],
  pagination: {
    page,
    limit,
    total: 0,
    totalPages: 0,
    hasNextPage: false,
    hasPreviousPage: page > 1,
  },
});

const resolveFilterIdentifier = async ({
  value,
  model,
  where = {},
  additionalFriendlyMatchers = [],
}) => {
  if (value === undefined) return undefined;
  if (value === null) return null;

  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!normalized) return undefined;

  const matchers = (additionalFriendlyMatchers || []).map((matcher) => (rawValue, upperValue) =>
    matcher({ rawValue, upperValue })
  );

  const resolvedId = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where,
    additionalFriendlyMatchers: matchers,
  });

  if (resolvedId) return resolvedId;
  if (isUuidLike(normalized)) return normalized;
  return null;
};

const resolvePayloadIdentifier = async ({
  value,
  field,
  model,
  where = {},
  nullable = false,
  additionalFriendlyMatchers = [],
}) => {
  if (value === undefined) return undefined;
  if (value === null) {
    if (nullable) return null;
    throw new HttpError('errors.validation.field.required', 400, [{ field }]);
  }

  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!normalized) {
    throw new HttpError('errors.validation.invalid', 400, [{ field }]);
  }

  const matchers = (additionalFriendlyMatchers || []).map((matcher) => (rawValue, upperValue) =>
    matcher({ rawValue, upperValue })
  );

  const resolvedId = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where,
    additionalFriendlyMatchers: matchers,
  });

  if (resolvedId) return resolvedId;
  if (isUuidLike(normalized)) return normalized;

  throw new HttpError('errors.validation.invalid', 400, [{ field }]);
};

const resolveVisitQueuePayloadIdentifiers = async (data = {}, existing = null) => {
  const payload = { ...data };

  const tenantId =
    payload.tenant_id !== undefined
      ? await resolvePayloadIdentifier({
          value: payload.tenant_id,
          field: 'tenant_id',
          model: 'tenant',
        })
      : existing?.tenant_id;

  if (payload.tenant_id !== undefined) {
    payload.tenant_id = tenantId;
  }

  if (payload.facility_id !== undefined) {
    payload.facility_id = await resolvePayloadIdentifier({
      value: payload.facility_id,
      field: 'facility_id',
      model: 'facility',
      where: tenantId ? { tenant_id: tenantId } : {},
      nullable: true,
    });
  }

  if (payload.patient_id !== undefined) {
    payload.patient_id = await resolvePayloadIdentifier({
      value: payload.patient_id,
      field: 'patient_id',
      model: 'patient',
      where: tenantId ? { tenant_id: tenantId } : {},
    });
  }

  if (payload.appointment_id !== undefined) {
    payload.appointment_id = await resolvePayloadIdentifier({
      value: payload.appointment_id,
      field: 'appointment_id',
      model: 'appointment',
      where: tenantId ? { tenant_id: tenantId } : {},
      nullable: true,
    });
  }

  if (payload.provider_user_id !== undefined) {
    payload.provider_user_id = await resolvePayloadIdentifier({
      value: payload.provider_user_id,
      field: 'provider_user_id',
      model: 'user',
      where: tenantId ? { tenant_id: tenantId } : {},
      nullable: true,
      additionalFriendlyMatchers: USER_IDENTIFIER_MATCHERS,
    });
  }

  if (payload.queued_at !== undefined) {
    payload.queued_at = payload.queued_at instanceof Date ? payload.queued_at : new Date(payload.queued_at);
  }

  return payload;
};

const resolveVisitQueueRecordByIdentifier = async (identifier) => {
  const resolved = await resolveModelRecordByIdentifier({
    model: 'visit_queue',
    identifier,
    select: { id: true },
  });
  if (!resolved?.id) return null;
  const entry = await visitQueueRepository.findById(resolved.id);
  return withVisitQueueProjection(entry);
};

/**
 * List visit queue entries with pagination
 *
 * @param {Object} filters - Filter criteria
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order (asc/desc)
 * @returns {Promise<Object>} Visit queue entries and pagination metadata
 */
const listVisitQueues = async (filters = {}, page = 1, limit = 20, sortBy = 'queued_at', order = 'desc') => {
  try {
    const resolvedPage = toPositiveInteger(page, 1);
    const resolvedLimit = toPositiveInteger(limit, 20);
    const resolvedSortBy = resolveSortBy(sortBy, 'queued_at');
    const resolvedOrder = resolveSortOrder(order, 'desc');

    // Build repository filters
    const repoFilters = {};

    const resolvedTenantId = await resolveFilterIdentifier({
      value: filters.tenant_id,
      model: 'tenant',
    });
    if (filters.tenant_id !== undefined && resolvedTenantId === null) {
      return buildEmptyListResult(resolvedPage, resolvedLimit);
    }
    if (resolvedTenantId) {
      repoFilters.tenant_id = resolvedTenantId;
    }

    const resolvedFacilityId = await resolveFilterIdentifier({
      value: filters.facility_id,
      model: 'facility',
      where: resolvedTenantId ? { tenant_id: resolvedTenantId } : {},
    });
    if (filters.facility_id !== undefined && resolvedFacilityId === null) {
      return buildEmptyListResult(resolvedPage, resolvedLimit);
    }
    if (resolvedFacilityId !== undefined) {
      repoFilters.facility_id = resolvedFacilityId;
    }

    const resolvedPatientId = await resolveFilterIdentifier({
      value: filters.patient_id,
      model: 'patient',
      where: resolvedTenantId ? { tenant_id: resolvedTenantId } : {},
    });
    if (filters.patient_id !== undefined && resolvedPatientId === null) {
      return buildEmptyListResult(resolvedPage, resolvedLimit);
    }
    if (resolvedPatientId) {
      repoFilters.patient_id = resolvedPatientId;
    }

    const resolvedAppointmentId = await resolveFilterIdentifier({
      value: filters.appointment_id,
      model: 'appointment',
      where: resolvedTenantId ? { tenant_id: resolvedTenantId } : {},
    });
    if (filters.appointment_id !== undefined && resolvedAppointmentId === null) {
      return buildEmptyListResult(resolvedPage, resolvedLimit);
    }
    if (resolvedAppointmentId !== undefined) {
      repoFilters.appointment_id = resolvedAppointmentId;
    }

    const resolvedProviderUserId = await resolveFilterIdentifier({
      value: filters.provider_user_id,
      model: 'user',
      where: resolvedTenantId ? { tenant_id: resolvedTenantId } : {},
      additionalFriendlyMatchers: USER_IDENTIFIER_MATCHERS,
    });
    if (filters.provider_user_id !== undefined && resolvedProviderUserId === null) {
      return buildEmptyListResult(resolvedPage, resolvedLimit);
    }
    if (resolvedProviderUserId !== undefined) {
      repoFilters.provider_user_id = resolvedProviderUserId;
    }

    if (filters.status) {
      repoFilters.status = filters.status;
    }

    if (filters.search) {
      const searchTerm = String(filters.search).trim();
      const upperSearchTerm = searchTerm.toUpperCase();

      repoFilters.OR = [
        { human_friendly_id: { contains: upperSearchTerm } },
        {
          patient: {
            OR: [
              { human_friendly_id: { contains: upperSearchTerm } },
              { first_name: { contains: searchTerm } },
              { last_name: { contains: searchTerm } },
              {
                contacts: {
                  some: {
                    deleted_at: null,
                    value: { contains: searchTerm },
                  },
                },
              },
              {
                identifiers: {
                  some: {
                    deleted_at: null,
                    identifier_value: { contains: searchTerm },
                  },
                },
              },
            ],
          },
        },
        {
          provider: {
            OR: [
              { human_friendly_id: { contains: upperSearchTerm } },
              { email: { contains: searchTerm } },
              { phone: { contains: searchTerm } },
              {
                profile: {
                  is: {
                    OR: [
                      { first_name: { contains: searchTerm } },
                      { middle_name: { contains: searchTerm } },
                      { last_name: { contains: searchTerm } },
                    ],
                  },
                },
              },
            ],
          },
        },
        {
          appointment: {
            is: {
              OR: [
                { human_friendly_id: { contains: upperSearchTerm } },
                { reason: { contains: searchTerm } },
              ],
            },
          },
        },
      ];
    }

    // Calculate pagination
    const skip = (resolvedPage - 1) * resolvedLimit;
    const orderBy = { [resolvedSortBy]: resolvedOrder };

    // Fetch entries and count
    const [entries, total] = await Promise.all([
      visitQueueRepository.findMany(repoFilters, skip, resolvedLimit, orderBy),
      visitQueueRepository.count(repoFilters)
    ]);

    // Calculate pagination metadata
    const totalPages = Math.ceil(total / resolvedLimit);
    const hasNextPage = resolvedPage < totalPages;
    const hasPreviousPage = resolvedPage > 1;

    return {
      entries: withVisitQueueProjectionList(entries),
      pagination: {
        page: resolvedPage,
        limit: resolvedLimit,
        total,
        totalPages,
        hasNextPage,
        hasPreviousPage
      }
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get visit queue entry by ID
 *
 * @param {string} id - Visit queue entry ID
 * @returns {Promise<Object>} Visit queue entry
 * @throws {HttpError} 404 if not found
 */
const getVisitQueueById = async (id) => {
  const entry = await resolveVisitQueueRecordByIdentifier(id);
  
  if (!entry) {
    throw new HttpError('errors.visit_queue.not_found', 404);
  }

  return entry;
};

/**
 * Create visit queue entry
 *
 * @param {Object} data - Visit queue entry data
 * @param {Object} context - Request context for audit
 * @returns {Promise<Object>} Created visit queue entry
 */
const createVisitQueue = async (data, context = {}) => {
  const payload = await resolveVisitQueuePayloadIdentifiers(data);

  // Set queued_at to current time if not provided
  if (!payload.queued_at) {
    payload.queued_at = new Date();
  }

  const entry = await visitQueueRepository.create(payload);
  const projectedEntry = withVisitQueueProjection(entry);

  // Create audit log
  await createAuditLog({
    action: 'VISIT_QUEUE_CREATED',
    entity: 'visit_queue',
    entity_id: projectedEntry.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: projectedEntry.tenant_id,
      facility_id: projectedEntry.facility_id,
      patient_id: projectedEntry.patient_id,
      appointment_id: projectedEntry.appointment_id,
      provider_user_id: projectedEntry.provider_user_id,
      status: projectedEntry.status,
      queued_at: projectedEntry.queued_at
    }
  });

  return projectedEntry;
};

/**
 * Update visit queue entry
 *
 * @param {string} id - Visit queue entry ID
 * @param {Object} data - Update data
 * @param {Object} context - Request context for audit
 * @returns {Promise<Object>} Updated visit queue entry
 */
const updateVisitQueue = async (id, data, context = {}) => {
  // Check if entry exists and get before state
  const beforeEntry = await resolveVisitQueueRecordByIdentifier(id);
  
  if (!beforeEntry) {
    throw new HttpError('errors.visit_queue.not_found', 404);
  }

  const payload = await resolveVisitQueuePayloadIdentifiers(data, beforeEntry);
  const updatedEntry = await visitQueueRepository.update(beforeEntry.id, payload);
  const projectedUpdatedEntry = withVisitQueueProjection(updatedEntry);

  // Create audit log
  await createAuditLog({
    action: 'VISIT_QUEUE_UPDATED',
    entity: 'visit_queue',
    entity_id: beforeEntry.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      before: {
        facility_id: beforeEntry.facility_id,
        appointment_id: beforeEntry.appointment_id,
        provider_user_id: beforeEntry.provider_user_id,
        status: beforeEntry.status,
        queued_at: beforeEntry.queued_at
      },
      after: {
        facility_id: projectedUpdatedEntry.facility_id,
        appointment_id: projectedUpdatedEntry.appointment_id,
        provider_user_id: projectedUpdatedEntry.provider_user_id,
        status: projectedUpdatedEntry.status,
        queued_at: projectedUpdatedEntry.queued_at
      }
    }
  });

  return projectedUpdatedEntry;
};

/**
 * Delete visit queue entry (soft delete)
 *
 * @param {string} id - Visit queue entry ID
 * @param {Object} context - Request context for audit
 * @returns {Promise<void>}
 */
const deleteVisitQueue = async (id, context = {}) => {
  // Check if entry exists
  const entry = await resolveVisitQueueRecordByIdentifier(id);
  
  if (!entry) {
    throw new HttpError('errors.visit_queue.not_found', 404);
  }

  // Soft delete entry
  await visitQueueRepository.softDelete(entry.id);

  // Create audit log
  await createAuditLog({
    action: 'VISIT_QUEUE_DELETED',
    entity: 'visit_queue',
    entity_id: entry.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      tenant_id: entry.tenant_id,
      facility_id: entry.facility_id,
      patient_id: entry.patient_id,
      appointment_id: entry.appointment_id,
      provider_user_id: entry.provider_user_id,
      status: entry.status,
      queued_at: entry.queued_at
    }
  });
};

/**
 * Prioritize visit queue entry (workflow action)
 *
 * @param {string} id - Visit queue entry ID
 * @param {Object} data - Prioritization data
 * @param {string} [data.reason] - Prioritization reason
 * @param {string} [data.status] - Status override
 * @param {Object} context - Request context for audit
 * @returns {Promise<Object>} Updated visit queue entry
 */
const prioritizeVisitQueue = async (id, data = {}, context = {}) => {
  // Check if entry exists and get before state
  const beforeEntry = await resolveVisitQueueRecordByIdentifier(id);

  if (!beforeEntry) {
    throw new HttpError('errors.visit_queue.not_found', 404);
  }

  // Prevent invalid transitions for terminal statuses.
  if (beforeEntry.status === 'COMPLETED' || beforeEntry.status === 'CANCELLED' || beforeEntry.status === 'NO_SHOW') {
    throw new HttpError('errors.visit_queue.cannot_prioritize_terminal_status', 400);
  }

  const updateData = {
    // Keep queue recency at the front when prioritized.
    queued_at: new Date(),
    status: data.status || 'CONFIRMED'
  };

  const updatedEntry = await visitQueueRepository.update(beforeEntry.id, updateData);
  const projectedUpdatedEntry = withVisitQueueProjection(updatedEntry);

  await createAuditLog({
    action: 'VISIT_QUEUE_PRIORITIZED',
    entity: 'visit_queue',
    entity_id: beforeEntry.id,
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    facility_id: context.facility_id,
    ip_address: context.ip_address,
    user_agent: context.user_agent,
    details: {
      reason: data.reason || null,
      before: {
        status: beforeEntry.status,
        queued_at: beforeEntry.queued_at
      },
      after: {
        status: projectedUpdatedEntry.status,
        queued_at: projectedUpdatedEntry.queued_at
      }
    }
  });

  return projectedUpdatedEntry;
};

module.exports = {
  listVisitQueues,
  getVisitQueueById,
  createVisitQueue,
  updateVisitQueue,
  deleteVisitQueue,
  prioritizeVisitQueue
};
