const labQcLogRepository = require('@repositories/lab-qc-log/lab-qc-log.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  LAB_QC_LOG_WITH_RELATIONS_INCLUDE,
  buildPagination,
  normalizeSearchTerm,
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
  toDateOrNull,
} = require('@services/lab-workspace/lab.shared');
const { mapLabQcLogRecord } = require('@services/lab-workspace/lab.serializer');

const listLabQcLogs = async (filters, page, limit, sortBy, order, userId, ipAddress) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};
    if (filters.lab_test_id) {
      whereClause.lab_test_id = await resolveModelIdOrThrow({
        identifier: filters.lab_test_id,
        model: 'lab_test',
        where: { deleted_at: null },
        errorKey: 'errors.lab_test.not_found',
      });
    }

    const searchTerm = normalizeSearchTerm(filters.search);
    if (searchTerm) {
      whereClause.OR = [
        { human_friendly_id: { contains: searchTerm.upper } },
        { status: { contains: searchTerm.raw } },
        { notes: { contains: searchTerm.raw } },
        { lab_test: { human_friendly_id: { contains: searchTerm.upper } } },
        { lab_test: { name: { contains: searchTerm.raw } } },
        { lab_test: { code: { contains: searchTerm.raw } } },
      ];
    }

    const [labQcLogs, total] = await Promise.all([
      labQcLogRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        LAB_QC_LOG_WITH_RELATIONS_INCLUDE
      ),
      labQcLogRepository.count(whereClause),
    ]);

    return {
      labQcLogs: labQcLogs.map((record) => mapLabQcLogRecord(record)).filter(Boolean),
      pagination: buildPagination(page, limit, total),
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getLabQcLogById = async (id, userId, ipAddress) => {
  try {
    const labQcLog = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_qc_log',
      where: { deleted_at: null },
      include: LAB_QC_LOG_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_qc_log.not_found',
    });
    return mapLabQcLogRecord(labQcLog);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createLabQcLog = async (data, userId, ipAddress) => {
  try {
    const payload = { ...data };
    payload.lab_test_id = await resolveModelIdOrThrow({
      identifier: payload.lab_test_id,
      model: 'lab_test',
      where: { deleted_at: null },
      errorKey: 'errors.lab_test.not_found',
    });
    if (Object.prototype.hasOwnProperty.call(payload, 'logged_at')) {
      payload.logged_at = toDateOrNull(payload.logged_at, new Date());
    }

    const labQcLog = await labQcLogRepository.create(payload);
    const createdLog = await labQcLogRepository.findById(
      labQcLog.id,
      LAB_QC_LOG_WITH_RELATIONS_INCLUDE
    );

    createAuditLog({
      user_id: userId,
      action: 'CREATE',
      entity: 'lab_qc_log',
      entity_id: labQcLog.id,
      diff: { after: createdLog || labQcLog },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapLabQcLogRecord(createdLog || labQcLog);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateLabQcLog = async (id, data, userId, ipAddress) => {
  try {
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_qc_log',
      where: { deleted_at: null },
      include: LAB_QC_LOG_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_qc_log.not_found',
    });

    const payload = { ...data };
    if (Object.prototype.hasOwnProperty.call(payload, 'lab_test_id') && payload.lab_test_id) {
      payload.lab_test_id = await resolveModelIdOrThrow({
        identifier: payload.lab_test_id,
        model: 'lab_test',
        where: { deleted_at: null },
        errorKey: 'errors.lab_test.not_found',
      });
    }
    if (Object.prototype.hasOwnProperty.call(payload, 'logged_at')) {
      payload.logged_at = toDateOrNull(payload.logged_at, null);
    }

    const updated = await labQcLogRepository.update(before.id, payload);
    const labQcLog = await labQcLogRepository.findById(
      updated.id,
      LAB_QC_LOG_WITH_RELATIONS_INCLUDE
    );

    createAuditLog({
      user_id: userId,
      action: 'UPDATE',
      entity: 'lab_qc_log',
      entity_id: updated.id,
      diff: { before, after: labQcLog },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapLabQcLogRecord(labQcLog || updated);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [{ originalError: error.message }]);
  }
};

const deleteLabQcLog = async (id, userId, ipAddress) => {
  try {
    const before = await resolveModelRecordOrThrow({
      identifier: id,
      model: 'lab_qc_log',
      where: { deleted_at: null },
      include: LAB_QC_LOG_WITH_RELATIONS_INCLUDE,
      errorKey: 'errors.lab_qc_log.not_found',
    });

    await labQcLogRepository.softDelete(before.id);

    createAuditLog({
      user_id: userId,
      action: 'DELETE',
      entity: 'lab_qc_log',
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
  listLabQcLogs,
  getLabQcLogById,
  createLabQcLog,
  updateLabQcLog,
  deleteLabQcLog
};
