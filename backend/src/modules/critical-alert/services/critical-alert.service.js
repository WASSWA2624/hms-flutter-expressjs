/**
 * Critical Alert service
 *
 * @module modules/critical-alert/services
 * @description Business logic layer for critical alert operations.
 */

const criticalAlertRepository = require('@repositories/critical-alert/critical-alert.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');

const UUID_LIKE_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const sanitize = (value) => String(value || '').trim();
const toPublicId = (value) => {
  const normalized = sanitize(value);
  if (!normalized || UUID_LIKE_REGEX.test(normalized)) return null;
  return normalized;
};
const resolvePublicIdentifier = (record) =>
  toPublicId(record?.human_friendly_id || record?.display_id || record?.id);
const resolvePatientDisplayName = (patient) =>
  [sanitize(patient?.first_name), sanitize(patient?.last_name)]
    .filter(Boolean)
    .join(' ')
    .trim() || null;

const CRITICAL_ALERT_INCLUDE = {
  icu_stay: {
    select: {
      id: true,
      human_friendly_id: true,
      admission: {
        select: {
          id: true,
          tenant_id: true,
          human_friendly_id: true,
          patient: {
            select: {
              id: true,
              human_friendly_id: true,
              first_name: true,
              last_name: true,
            },
          },
        },
      },
    },
  },
};

const mapIcuStayRelation = (stay) => {
  if (!stay) return null;
  return {
    id: resolvePublicIdentifier(stay),
    display_id: resolvePublicIdentifier(stay),
    human_friendly_id: resolvePublicIdentifier(stay),
    admission: stay.admission
      ? {
          id: resolvePublicIdentifier(stay.admission),
          display_id: resolvePublicIdentifier(stay.admission),
          human_friendly_id: resolvePublicIdentifier(stay.admission),
          patient_display_id: resolvePublicIdentifier(stay.admission.patient),
          patient_display_name: resolvePatientDisplayName(
            stay.admission.patient
          ),
          patient: stay.admission.patient
            ? {
                id: resolvePublicIdentifier(stay.admission.patient),
                display_id: resolvePublicIdentifier(stay.admission.patient),
                human_friendly_id: resolvePublicIdentifier(
                  stay.admission.patient
                ),
                first_name: stay.admission.patient.first_name || null,
                last_name: stay.admission.patient.last_name || null,
              }
            : null,
        }
      : null,
  };
};

const mapCriticalAlertRecord = (record) => {
  if (!record) return record;
  return {
    id: resolvePublicIdentifier(record),
    display_id: resolvePublicIdentifier(record),
    human_friendly_id: resolvePublicIdentifier(record),
    icu_stay_id: resolvePublicIdentifier(record.icu_stay),
    icu_stay_display_id: resolvePublicIdentifier(record.icu_stay),
    admission_display_id: resolvePublicIdentifier(record.icu_stay?.admission),
    patient_display_id: resolvePublicIdentifier(record.icu_stay?.admission?.patient),
    patient_display_name: resolvePatientDisplayName(record.icu_stay?.admission?.patient),
    severity: record.severity || null,
    message: record.message || null,
    created_at: record.created_at || null,
    updated_at: record.updated_at || null,
    icu_stay: mapIcuStayRelation(record.icu_stay),
  };
};

const buildEmptyPagination = (page, limit) => ({
  page,
  limit,
  total: 0,
  totalPages: 0,
  hasNextPage: false,
  hasPreviousPage: page > 1,
});

const resolveCriticalAlert = async (identifier) =>
  resolveModelIdByIdentifier({
    model: 'critical_alert',
    identifier,
    select: { id: true },
  });

const resolveIcuStay = async (identifier) =>
  resolveModelIdByIdentifier({
    model: 'icu_stay',
    identifier,
    select: {
      id: true,
      admission: { select: { tenant_id: true } },
    },
  });

const resolveAuditTenantId = (record, fallback = null) =>
  record?.icu_stay?.admission?.tenant_id || fallback || null;

const listCriticalAlerts = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { created_at: 'desc' };
    const whereClause = {};

    if (filters.icu_stay_id) {
      const resolvedIcuStay = await resolveIcuStay(filters.icu_stay_id);
      if (!resolvedIcuStay?.id) {
        return {
          critical_alerts: [],
          pagination: buildEmptyPagination(page, limit),
        };
      }
      whereClause.icu_stay_id = resolvedIcuStay.id;
    }

    if (filters.severity) whereClause.severity = filters.severity;
    if (filters.search) whereClause.message = { contains: filters.search };

    const [criticalAlerts, total] = await Promise.all([
      criticalAlertRepository.findMany(
        whereClause,
        skip,
        limit,
        orderBy,
        CRITICAL_ALERT_INCLUDE
      ),
      criticalAlertRepository.count(whereClause),
    ]);

    return {
      critical_alerts: criticalAlerts.map(mapCriticalAlertRecord),
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
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const getCriticalAlertById = async (id) => {
  try {
    const resolvedCriticalAlert = await resolveCriticalAlert(id);
    if (!resolvedCriticalAlert?.id) {
      throw new HttpError('errors.critical_alert.not_found', 404);
    }

    const criticalAlert = await criticalAlertRepository.findById(
      resolvedCriticalAlert.id,
      CRITICAL_ALERT_INCLUDE
    );
    if (!criticalAlert) {
      throw new HttpError('errors.critical_alert.not_found', 404);
    }

    return mapCriticalAlertRecord(criticalAlert);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const createCriticalAlert = async (data, userId, ipAddress) => {
  try {
    const resolvedIcuStay = await resolveIcuStay(data?.icu_stay_id);
    if (!resolvedIcuStay?.id) {
      throw new HttpError('errors.icu_stay.not_found', 404, [
        { field: 'icu_stay_id' },
      ]);
    }

    const createdCriticalAlert = await criticalAlertRepository.create({
      ...data,
      icu_stay_id: resolvedIcuStay.id,
    });
    const criticalAlert =
      (await criticalAlertRepository.findById(
        createdCriticalAlert.id,
        CRITICAL_ALERT_INCLUDE
      )) || createdCriticalAlert;

    createAuditLog({
      tenant_id: resolveAuditTenantId(
        criticalAlert,
        resolvedIcuStay.admission?.tenant_id
      ),
      user_id: userId,
      action: 'CREATE',
      entity: 'critical_alert',
      entity_id: criticalAlert.id,
      diff: { after: criticalAlert },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapCriticalAlertRecord(criticalAlert);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const updateCriticalAlert = async (id, data, userId, ipAddress) => {
  try {
    const resolvedCriticalAlert = await resolveCriticalAlert(id);
    if (!resolvedCriticalAlert?.id) {
      throw new HttpError('errors.critical_alert.not_found', 404);
    }

    const before = await criticalAlertRepository.findById(
      resolvedCriticalAlert.id,
      CRITICAL_ALERT_INCLUDE
    );
    if (!before) {
      throw new HttpError('errors.critical_alert.not_found', 404);
    }

    const updatedCriticalAlert = await criticalAlertRepository.update(
      resolvedCriticalAlert.id,
      data
    );
    const criticalAlert =
      (await criticalAlertRepository.findById(
        updatedCriticalAlert.id,
        CRITICAL_ALERT_INCLUDE
      )) || updatedCriticalAlert;

    createAuditLog({
      tenant_id: resolveAuditTenantId(criticalAlert, resolveAuditTenantId(before)),
      user_id: userId,
      action: 'UPDATE',
      entity: 'critical_alert',
      entity_id: criticalAlert.id,
      diff: { before, after: criticalAlert },
      ip_address: ipAddress,
    }).catch(() => {});

    return mapCriticalAlertRecord(criticalAlert);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

const deleteCriticalAlert = async (id, userId, ipAddress) => {
  try {
    const resolvedCriticalAlert = await resolveCriticalAlert(id);
    if (!resolvedCriticalAlert?.id) {
      throw new HttpError('errors.critical_alert.not_found', 404);
    }

    const before = await criticalAlertRepository.findById(
      resolvedCriticalAlert.id,
      CRITICAL_ALERT_INCLUDE
    );
    if (!before) {
      throw new HttpError('errors.critical_alert.not_found', 404);
    }

    await criticalAlertRepository.softDelete(resolvedCriticalAlert.id);

    createAuditLog({
      tenant_id: resolveAuditTenantId(before),
      user_id: userId,
      action: 'DELETE',
      entity: 'critical_alert',
      entity_id: resolvedCriticalAlert.id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('errors.server.unexpected', 500, [
      { originalError: error.message },
    ]);
  }
};

module.exports = {
  listCriticalAlerts,
  getCriticalAlertById,
  createCriticalAlert,
  updateCriticalAlert,
  deleteCriticalAlert,
};
