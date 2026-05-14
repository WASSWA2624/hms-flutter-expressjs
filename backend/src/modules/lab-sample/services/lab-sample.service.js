const labSampleRepository = require('@repositories/lab-sample/lab-sample.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  LAB_SAMPLE_WITH_RELATIONS_INCLUDE,
  applyDateRangeFilter,
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
  toDateOrNull,
} = require('@services/lab-workspace/lab.shared');
const { mapLabSampleRecord } = require('@services/lab-workspace/lab.serializer');

const listLabSamples = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};

    if (filters.lab_order_id) {
      whereClause.lab_order_id = await resolveModelIdOrThrow({
        identifier: filters.lab_order_id,
        model: 'lab_order',
        where: { deleted_at: null },
        errorKey: 'errors.lab_order.not_found',
      });
    }

    if (filters.status) whereClause.status = filters.status;
    applyDateRangeFilter(whereClause, 'created_at', filters.created_at_from, filters.created_at_to);

    const searchTerm = normalizeSearchTerm(filters.search);
    if (searchTerm) {
      whereClause.OR = [
        { human_friendly_id: { contains: searchTerm.upper } },
        { lab_order: { human_friendly_id: { contains: searchTerm.upper } } },
        { lab_order: { patient: { human_friendly_id: { contains: searchTerm.upper } } } },
        { lab_order: { patient: { first_name: { contains: searchTerm.raw } } } },
        { lab_order: { patient: { last_name: { contains: searchTerm.raw } } } },
      ];
    }

    const [labSamples, total] = await Promise.all([
      labSampleRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        LAB_SAMPLE_WITH_RELATIONS_INCLUDE
      ),
      labSampleRepository.count(whereClause),
    ]);

    return {
      labSamples: labSamples.map((record) => mapLabSampleRecord(record)).filter(Boolean),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getLabSampleById = async (id, userId, ipAddress) => {
  try {
    const labSample = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_sample',
      where: { deleted_at: null },
      include: LAB_SAMPLE_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_sample.not_found',
    });

    return mapLabSampleRecord(labSample);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createLabSample = async (data, userId, ipAddress) => {
  try {
    const payload = { ...data };
    payload.lab_order_id = await resolveModelIdOrThrow({
      identifier: payload.lab_order_id,
      model: 'lab_order',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order.not_found',
    });

    if (Object.prototype.hasOwnProperty.call(payload, 'collected_at')) {
      payload.collected_at = toDateOrNull(payload.collected_at, null);
    }

    if (Object.prototype.hasOwnProperty.call(payload, 'received_at')) {
      payload.received_at = toDateOrNull(payload.received_at, null);
    }

    const labSample = await labSampleRepository.create(payload);
    const createdSample = await labSampleRepository.findById(
      labSample.id,
      LAB_SAMPLE_WITH_RELATIONS_INCLUDE
    );

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'lab_sample',
      entity_id: labSample.id,
      diff: { after: createdSample || labSample },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapLabSampleRecord(createdSample || labSample);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateLabSample = async (id, data, userId, ipAddress) => {
  try {
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_sample',
      where: { deleted_at: null },
      include: LAB_SAMPLE_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_sample.not_found',
    });

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'collected_at')) {
      payload.collected_at = toDateOrNull(payload.collected_at, null);
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'received_at')) {
      payload.received_at = toDateOrNull(payload.received_at, null);
    }

    const updated = await labSampleRepository.update(before.id, payload);
    const labSample = await labSampleRepository.findById(
      updated.id,
      LAB_SAMPLE_WITH_RELATIONS_INCLUDE
    );

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'lab_sample',
      entity_id: updated.id,
      diff: { before, after: labSample },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapLabSampleRecord(labSample || updated);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteLabSample = async (id, userId, ipAddress) => {
  try {
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_sample',
      where: { deleted_at: null },
      include: LAB_SAMPLE_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_sample.not_found',
    });

    await labSampleRepository.softDelete(before.id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'lab_sample',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listLabSamples,
  getLabSampleById,
  createLabSample,
  updateLabSample,
  deleteLabSample
};
