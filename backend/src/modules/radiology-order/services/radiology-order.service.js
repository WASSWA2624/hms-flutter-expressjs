/**
 * Radiology Order service
 *
 * @module modules/radiology-order/services
 * @description Business logic layer for radiology order operations.
 * Per module-creation.mdc: Services only import/use their own repository.
 * Per prisma.mdc: All mutations call createAuditLog.
 */

const radiologyOrderRepository = require('@repositories/radiology-order/radiology-order.repository');
const prisma = require('@prisma/client');
const {
  RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE,
} = require('@services/radiology-workspace/radiology.shared');
const {
  mapRadiologyOrderRecord,
} = require('@services/radiology-workspace/radiology.serializer');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  normalizeIdentifier,
  resolveModelIdByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const {
  resolveIdentifierForFilter,
  resolveIdentifierForPayload,
} = require('@lib/identifiers/service-identifier-resolution');

const buildPagination = (page, limit, total) => {
  const totalPages = Math.max(1, Math.ceil(total / limit));
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
  };
};

const buildEmptyListResult = (page, limit) => ({
  radiology_orders: [],
  pagination: buildPagination(page, limit, 0),
});

const serializeRadiologyOrder = (record) =>
  mapRadiologyOrderRecord(record, { includeChildren: true }) || record;

const fetchSerializedRadiologyOrderById = async (id) => {
  const record = await radiologyOrderRepository.findById(
    id,
    RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
  );
  return serializeRadiologyOrder(record);
};

const sanitizeString = (value) => (typeof value === 'string' ? value.trim() : '');

const resolveResourceId = async (model, identifier) => {
  const normalized = normalizeIdentifier(identifier);
  if (!normalized) return normalized;

  const resolved = await resolveModelIdByIdentifier({
    model,
    identifier: normalized,
    where: { deleted_at: null },
  });

  return resolved || normalized;
};

const resolveRadiologyTestLabel = async (radiologyTestId) => {
  const normalizedId = sanitizeString(radiologyTestId);
  if (!normalizedId) return '';

  const radiologyTest = await prisma.radiology_test.findFirst({
    where: { id: normalizedId, deleted_at: null },
    select: { human_friendly_id: true, name: true, code: true },
  });

  return sanitizeString(
    radiologyTest?.name || radiologyTest?.code || radiologyTest?.human_friendly_id
  );
};

const resolveOrCreateRadiologyTest = async ({
  request,
  tenantId,
  userId,
  ipAddress,
}) => {
  if (request?.radiology_test_id) {
    return resolveIdentifierForPayload({
      value: request.radiology_test_id,
      field: 'radiology_test_id',
      model: 'radiology_test',
      where: { deleted_at: null, tenant_id: tenantId },
      nullable: true,
    });
  }

  const newTest = request?.new_test || {};
  const name = sanitizeString(newTest.name);
  if (!name) {
    throw new HttpError('errors.validation.required', 400, [
      { field: 'requested_tests.new_test.name' },
    ]);
  }

  const code = sanitizeString(newTest.code);
  const existing = await prisma.radiology_test.findFirst({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      ...(code ? { code } : { name }),
    },
    select: { id: true },
  });
  if (existing) return existing.id;

  const radiologyTest = await prisma.radiology_test.create({
    data: {
      tenant_id: tenantId,
      name,
      code: code || null,
      modality: sanitizeString(newTest.modality) || 'OTHER',
    },
    select: { id: true },
  });

  createAuditLog({
    tenant_id: tenantId,
    user_id: userId,
    action: 'CREATE',
    entity: 'radiology_test',
    entity_id: radiologyTest.id,
    diff: { after: { ...newTest, id: radiologyTest.id } },
    ip_address: ipAddress,
  }).catch(() => {});

  return radiologyTest.id;
};

const createImagingRequestClinicalNote = async ({
  encounterId,
  userId,
  testLabel,
  clinicalNote,
}) => {
  const note = sanitizeString(clinicalNote);
  if (!encounterId || !userId || !note) return;

  try {
    await prisma.clinical_note.create({
      data: {
        encounter_id: encounterId,
        author_user_id: userId,
        note: `Imaging request${testLabel ? ` (${testLabel})` : ''}: ${note}`,
      },
    });
  } catch (_error) {
    // Request creation should not fail because note capture failed.
  }
};

const normalizeRequestDetails = (request = {}) => {
  const details = request.request_details && typeof request.request_details === 'object'
    ? { ...request.request_details }
    : {};

  const newTest = request.new_test && typeof request.new_test === 'object'
    ? request.new_test
    : null;

  return {
    request_mode: request.radiology_test_id ? 'existing' : 'new',
    radiology_test_id: sanitizeString(request.radiology_test_id) || null,
    new_test_name: sanitizeString(newTest?.name) || null,
    new_test_code: sanitizeString(newTest?.code) || null,
    modality: sanitizeString(newTest?.modality || details.modality) || null,
    standard_study_code: sanitizeString(details.standard_study_code) || null,
    body_region: sanitizeString(details.body_region) || null,
    laterality: sanitizeString(details.laterality) || null,
    priority: sanitizeString(details.priority) || null,
    ...details,
  };
};

const buildRequestDuplicateKey = (request = {}) => {
  if (request.radiology_test_id) {
    return `existing:${sanitizeString(request.radiology_test_id).toLowerCase()}`;
  }
  const newTest = request.new_test || {};
  const details = request.request_details || {};
  return [
    'new',
    sanitizeString(newTest.code).toLowerCase(),
    sanitizeString(newTest.name).toLowerCase(),
    sanitizeString(newTest.modality).toLowerCase(),
    sanitizeString(details.body_region).toLowerCase(),
    sanitizeString(details.laterality).toLowerCase(),
  ].join(':');
};

const assertNoDuplicateRequests = (requests = []) => {
  const seen = new Set();
  for (const request of requests) {
    const key = buildRequestDuplicateKey(request);
    if (!key || key === 'new:::::') continue;
    if (seen.has(key)) {
      throw new HttpError('errors.radiology_order.duplicate_request', 400, [
        { field: 'requested_tests' },
      ]);
    }
    seen.add(key);
  }
};

/**
 * List radiology orders with pagination and filtering
 *
 * @param {Object} filters - Query filters
 * @param {number} page - Page number
 * @param {number} limit - Items per page
 * @param {string} sortBy - Sort field
 * @param {string} order - Sort order
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Radiology orders and pagination data
 */
const listRadiologyOrders = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    // Build filter object
    const whereClause = {};
    
    if (filters.encounter_id !== undefined) {
      const encounterId = await resolveIdentifierForFilter({
        value: filters.encounter_id,
        model: 'encounter',
        where: { deleted_at: null },
      });
      if (encounterId === null) return buildEmptyListResult(page, limit);
      if (encounterId !== undefined) whereClause.encounter_id = encounterId;
    }
    if (filters.patient_id !== undefined) {
      const patientId = await resolveIdentifierForFilter({
        value: filters.patient_id,
        model: 'patient',
        where: { deleted_at: null },
      });
      if (patientId === null) return buildEmptyListResult(page, limit);
      if (patientId !== undefined) whereClause.patient_id = patientId;
    }
    if (filters.radiology_test_id !== undefined) {
      const radiologyTestId = await resolveIdentifierForFilter({
        value: filters.radiology_test_id,
        model: 'radiology_test',
        where: { deleted_at: null },
      });
      if (radiologyTestId === null) return buildEmptyListResult(page, limit);
      if (radiologyTestId !== undefined) whereClause.radiology_test_id = radiologyTestId;
    }
    if (filters.status) whereClause.status = filters.status;

    const [radiologyOrders, total] = await Promise.all([
      radiologyOrderRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
      ),
      radiologyOrderRepository.count(whereClause)
    ]);

    return {
      radiology_orders: radiologyOrders.map(serializeRadiologyOrder).filter(Boolean),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Get radiology order by ID
 *
 * @param {string} id - Radiology Order ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Radiology order data
 */
const getRadiologyOrderById = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('radiology_order', id);
    const radiologyOrder = await radiologyOrderRepository.findById(
      resolvedId,
      RADIOLOGY_ORDER_WITH_RELATIONS_INCLUDE
    );

    if (!radiologyOrder) {
      throw new HttpError('errors.radiology_order.not_found', 404);
    }

    return serializeRadiologyOrder(radiologyOrder);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Create new radiology order
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {Object} data - Radiology Order data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Created radiology order
 */
const createRadiologyOrder = async (data, userId, ipAddress) => {
  try {
    const orderedAt = data.ordered_at ? new Date(data.ordered_at) : new Date();
    const requestedTests = Array.isArray(data.requested_tests)
      ? data.requested_tests
      : [];
    const encounterId = await resolveIdentifierForPayload({
        value: data.encounter_id,
        field: 'encounter_id',
        model: 'encounter',
        where: { deleted_at: null },
        nullable: true,
      });
    const patientId = await resolveIdentifierForPayload({
        value: data.patient_id,
        field: 'patient_id',
        model: 'patient',
        where: { deleted_at: null },
      });
    const patient = await prisma.patient.findFirst({
      where: { id: patientId, deleted_at: null },
      select: { tenant_id: true },
    });
    if (!patient) {
      throw new HttpError('errors.patient.not_found', 404);
    }

    const baseOrderData = {
      encounter_id: encounterId,
      patient_id: patientId,
      status: 'ORDERED',
      ordered_at: orderedAt,
    };

    const orderRequests =
      requestedTests.length > 0
        ? requestedTests
        : [
            data.radiology_test_id
              ? { radiology_test_id: data.radiology_test_id }
              : null,
          ].filter(Boolean);

    if (!orderRequests.length) {
      throw new HttpError('errors.validation.required', 400, [
        { field: 'requested_tests' },
      ]);
    }

    assertNoDuplicateRequests(orderRequests);

    const createdOrders = [];
    for (const request of orderRequests) {
      const radiologyTestId = await resolveOrCreateRadiologyTest({
        request,
        tenantId: patient.tenant_id,
        userId,
        ipAddress,
      });
      const requestDetails = normalizeRequestDetails(request);
      const testLabel =
        sanitizeString(request?.new_test?.name) ||
        (await resolveRadiologyTestLabel(radiologyTestId));
      const radiologyOrder = await radiologyOrderRepository.create({
        ...baseOrderData,
        radiology_test_id: radiologyTestId || null,
        clinical_note: sanitizeString(request?.clinical_note) || null,
        request_details: requestDetails,
      });
      const serializedRadiologyOrder = await fetchSerializedRadiologyOrderById(
        radiologyOrder.id
      );
      createdOrders.push(serializedRadiologyOrder);

      await createImagingRequestClinicalNote({
        encounterId,
        userId,
        testLabel,
        clinicalNote: request?.clinical_note,
      });

      createAuditLog({
        user_id: userId,
        action: 'CREATE',
        entity: 'radiology_order',
        entity_id: radiologyOrder.id,
        diff: { after: radiologyOrder },
        ip_address: ipAddress,
      }).catch(() => {});
    }

    if (createdOrders.length === 1) return createdOrders[0];
    return {
      ...createdOrders[0],
      created_orders: createdOrders,
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Update radiology order
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Radiology Order ID
 * @param {Object} data - Update data
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<Object>} Updated radiology order
 */
const updateRadiologyOrder = async (id, data, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('radiology_order', id);

    // Get current state for audit
    const before = await radiologyOrderRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.radiology_order.not_found', 404);
    }

    const normalizedData = {
      ...data,
    };
    if (Object.prototype.hasOwnProperty.call(data, 'encounter_id')) {
      normalizedData.encounter_id = await resolveIdentifierForPayload({
        value: data.encounter_id,
        field: 'encounter_id',
        model: 'encounter',
        where: { deleted_at: null },
        nullable: true,
      });
    }
    if (Object.prototype.hasOwnProperty.call(data, 'patient_id')) {
      normalizedData.patient_id = await resolveIdentifierForPayload({
        value: data.patient_id,
        field: 'patient_id',
        model: 'patient',
        where: { deleted_at: null },
      });
    }
    if (Object.prototype.hasOwnProperty.call(data, 'radiology_test_id')) {
      normalizedData.radiology_test_id = await resolveIdentifierForPayload({
        value: data.radiology_test_id,
        field: 'radiology_test_id',
        model: 'radiology_test',
        where: { deleted_at: null },
        nullable: true,
      });
    }

    const radiologyOrder = await radiologyOrderRepository.update(resolvedId, normalizedData);
    const serializedRadiologyOrder = await fetchSerializedRadiologyOrderById(
      radiologyOrder.id
    );

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'radiology_order',
      entity_id: radiologyOrder.id,
      diff: { before, after: radiologyOrder },
      ip_address: ipAddress
    }).catch(() => {});

    return serializedRadiologyOrder;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

/**
 * Delete radiology order (soft delete)
 * Per prisma.mdc: Mutations must create audit logs
 *
 * @param {string} id - Radiology Order ID
 * @param {string} userId - User ID for audit
 * @param {string} ipAddress - User IP for audit
 * @returns {Promise<void>}
 */
const deleteRadiologyOrder = async (id, userId, ipAddress) => {
  try {
    const resolvedId = await resolveResourceId('radiology_order', id);

    // Get current state for audit
    const before = await radiologyOrderRepository.findById(resolvedId);

    if (!before) {
      throw new HttpError('errors.radiology_order.not_found', 404);
    }

    await radiologyOrderRepository.softDelete(resolvedId);

    // Create audit log (non-blocking)
    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'radiology_order',
      entity_id: resolvedId,
      diff: { before },
      ip_address: ipAddress
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listRadiologyOrders,
  getRadiologyOrderById,
  createRadiologyOrder,
  updateRadiologyOrder,
  deleteRadiologyOrder
};
