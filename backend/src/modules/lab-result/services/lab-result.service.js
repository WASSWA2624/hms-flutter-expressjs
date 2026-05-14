const labResultRepository = require('@repositories/lab-result/lab-result.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  LAB_RESULT_WITH_RELATIONS_INCLUDE,
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
  toDateOrNull,
} = require('@services/lab-workspace/lab.shared');
const { evaluateLabResult } = require('@services/lab-workspace/lab.interpretation');
const { mapLabResultRecord } = require('@services/lab-workspace/lab.serializer');

const resolveInterpretationContext = async (labOrderItemIdentifier) =>
  resolveModelRecordOrThrow({
    identifier: labOrderItemIdentifier,
    model: 'lab_order_item',
    where: { deleted_at: null },
    include: {
      lab_test: {
        include: {
          reference_ranges: {
            orderBy: { sort_order: 'asc' },
          },
          unit_options: {
            orderBy: { sort_order: 'asc' },
          },
          result_options: {
            orderBy: { sort_order: 'asc' },
          },
        },
      },
      lab_order: {
        include: {
          patient: {
            select: {
              id: true,
              date_of_birth: true,
              gender: true,
            },
          },
        },
      },
    },
    errorKey: 'errors.lab_order_item.not_found',
  });

const applyInterpretationIfNeeded = ({
  payload,
  itemContext,
  shouldInterpret,
  fallbackStatus = 'PENDING',
}) => {
  const nextPayload = { ...payload };
  if (!shouldInterpret) {
    nextPayload.result_unit =
      nextPayload.result_unit || itemContext?.lab_test?.unit || null;
    nextPayload.result_flag = null;
    nextPayload.is_positive = false;
    nextPayload.reference_range_label = null;
    nextPayload.reference_range_summary = null;
    return nextPayload;
  }

  const interpretation = evaluateLabResult({
    test: itemContext?.lab_test || {},
    patient: itemContext?.lab_order?.patient || {},
    resultValue: nextPayload.result_value,
    resultText: nextPayload.result_text,
    resultUnit: nextPayload.result_unit,
    fallbackStatus,
  });

  nextPayload.status = interpretation.status;
  nextPayload.result_unit = interpretation.result_unit || null;
  nextPayload.result_flag = interpretation.result_flag || null;
  nextPayload.is_positive = Boolean(interpretation.is_positive);
  nextPayload.reference_range_label = interpretation.reference_range_label || null;
  nextPayload.reference_range_summary = interpretation.reference_range_summary || null;
  return nextPayload;
};

const listLabResults = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };

    const whereClause = {};
    if (filters.lab_order_item_id) {
      whereClause.lab_order_item_id = await resolveModelIdOrThrow({
        identifier: filters.lab_order_item_id,
        model: 'lab_order_item',
        where: { deleted_at: null },
        errorKey: 'errors.lab_order_item.not_found',
      });
    }
    if (filters.status) whereClause.status = filters.status;

    const searchTerm = normalizeSearchTerm(filters.search);
    if (searchTerm) {
      whereClause.OR = [
        { human_friendly_id: { contains: searchTerm.upper } },
        { result_value: { contains: searchTerm.raw } },
        { result_flag: { contains: searchTerm.raw } },
        { reference_range_summary: { contains: searchTerm.raw } },
        { result_text: { contains: searchTerm.raw } },
        { lab_order_item: { human_friendly_id: { contains: searchTerm.upper } } },
        { lab_order_item: { lab_order: { human_friendly_id: { contains: searchTerm.upper } } } },
        { lab_order_item: { lab_test: { human_friendly_id: { contains: searchTerm.upper } } } },
        { lab_order_item: { lab_test: { name: { contains: searchTerm.raw } } } },
        { lab_order_item: { lab_test: { code: { contains: searchTerm.raw } } } },
        { lab_order_item: { lab_order: { patient: { human_friendly_id: { contains: searchTerm.upper } } } } },
        { lab_order_item: { lab_order: { patient: { first_name: { contains: searchTerm.raw } } } } },
        { lab_order_item: { lab_order: { patient: { last_name: { contains: searchTerm.raw } } } } },
      ];
    }

    const [labResults, total] = await Promise.all([
      labResultRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        LAB_RESULT_WITH_RELATIONS_INCLUDE
      ),
      labResultRepository.count(whereClause),
    ]);

    return {
      labResults: labResults.map((record) => mapLabResultRecord(record)).filter(Boolean),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getLabResultById = async (id, userId, ipAddress) => {
  try {
    const labResult = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_result',
      where: { deleted_at: null },
      include: LAB_RESULT_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_result.not_found',
    });
    return mapLabResultRecord(labResult);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createLabResult = async (data, userId, ipAddress) => {
  try {
    const payload = { ...data };
    payload.lab_order_item_id = await resolveModelIdOrThrow({
      identifier: payload.lab_order_item_id,
      model: 'lab_order_item',
      where: { deleted_at: null },
      errorKey: 'errors.lab_order_item.not_found',
    });
    if (Object.prototype.hasOwnProperty.call(payload, 'reported_at')) {
      payload.reported_at = toDateOrNull(payload.reported_at, null);
    }

    if (!payload.status) {
      payload.status = 'PENDING';
    }

    const itemContext = await resolveInterpretationContext(payload.lab_order_item_id);
    const shouldInterpret =
      payload.status !== 'PENDING'
      || Boolean(payload.reported_at);
    const interpretedPayload = applyInterpretationIfNeeded({
      payload,
      itemContext,
      shouldInterpret,
      fallbackStatus: payload.status || 'PENDING',
    });

    const labResult = await labResultRepository.create(interpretedPayload);
    const createdResult = await labResultRepository.findById(
      labResult.id,
      LAB_RESULT_WITH_RELATIONS_INCLUDE
    );

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'lab_result',
      entity_id: labResult.id,
      diff: { after: createdResult || labResult },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapLabResultRecord(createdResult || labResult);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateLabResult = async (id, data, userId, ipAddress) => {
  try {
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_result',
      where: { deleted_at: null },
      include: LAB_RESULT_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_result.not_found',
    });

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'lab_order_item_id') && payload.lab_order_item_id) {
      payload.lab_order_item_id = await resolveModelIdOrThrow({
        identifier: payload.lab_order_item_id,
        model: 'lab_order_item',
        where: { deleted_at: null },
        errorKey: 'errors.lab_order_item.not_found',
      });
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'reported_at')) {
      payload.reported_at = toDateOrNull(payload.reported_at, null);
    }

    const nextResultValue =
      Object.prototype.hasOwnProperty.call(payload, 'result_value')
        ? payload.result_value
        : before.result_value;
    const nextResultUnit =
      Object.prototype.hasOwnProperty.call(payload, 'result_unit')
        ? payload.result_unit
        : before.result_unit;
    const nextResultText =
      Object.prototype.hasOwnProperty.call(payload, 'result_text')
        ? payload.result_text
        : before.result_text;
    const nextStatus =
      Object.prototype.hasOwnProperty.call(payload, 'status')
        ? payload.status
        : before.status;
    const nextOrderItemId = payload.lab_order_item_id || before.lab_order_item_id;
    const itemContext = await resolveInterpretationContext(nextOrderItemId);
    const shouldInterpret =
      nextStatus !== 'PENDING'
      || Boolean(payload.reported_at)
      || Boolean(before.reported_at);

    const updatedPayload = applyInterpretationIfNeeded({
      payload: {
        ...payload,
        result_value: nextResultValue,
        result_unit: nextResultUnit,
        result_text: nextResultText,
        status: nextStatus,
      },
      itemContext,
      shouldInterpret,
      fallbackStatus: nextStatus || 'PENDING',
    });

    const updated = await labResultRepository.update(before.id, updatedPayload);
    const labResult = await labResultRepository.findById(updated.id, LAB_RESULT_WITH_RELATIONS_INCLUDE);

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'lab_result',
      entity_id: updated.id,
      diff: { before, after: labResult },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapLabResultRecord(labResult || updated);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteLabResult = async (id, userId, ipAddress) => {
  try {
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_result',
      where: { deleted_at: null },
      include: LAB_RESULT_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_result.not_found',
    });

    await labResultRepository.softDelete(before.id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'lab_result',
      entity_id: before.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const releaseLabResult = async (id, data = {}, userId, ipAddress) => {
  try {
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_result',
      where: { deleted_at: null },
      include: LAB_RESULT_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_result.not_found',
    });

    if (before.status !== 'PENDING') {
      throw new HttpError('errors.lab_result.already_released', 400);
    }

    const itemContext = await resolveInterpretationContext(before.lab_order_item_id);
    const basePayload = {
      status: data.status || before.status || 'NORMAL',
      result_value:
        Object.prototype.hasOwnProperty.call(data, 'result_value') ? data.result_value : before.result_value,
      result_unit:
        Object.prototype.hasOwnProperty.call(data, 'result_unit')
          ? data.result_unit
          : (before.result_unit || before?.lab_order_item?.lab_test?.unit || null),
      result_text:
        Object.prototype.hasOwnProperty.call(data, 'result_text') ? data.result_text : before.result_text,
      reported_at: toDateOrNull(data.reported_at, new Date()),
    };

    const updateData = applyInterpretationIfNeeded({
      payload: basePayload,
      itemContext,
      shouldInterpret: true,
      fallbackStatus: basePayload.status || 'NORMAL',
    });

    const updated = await labResultRepository.update(before.id, updateData);
    const labResult = await labResultRepository.findById(updated.id, LAB_RESULT_WITH_RELATIONS_INCLUDE);

    createAuditLog({
      user_id: userId,
      action: 'RELEASE',
      entity: 'lab_result',
      entity_id: updated.id,
      diff: {
        before,
        after: labResult,
        metadata: {
          notes: data.notes || null,
        },
      },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapLabResultRecord(labResult || updated);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listLabResults,
  getLabResultById,
  createLabResult,
  updateLabResult,
  deleteLabResult,
  releaseLabResult
};
