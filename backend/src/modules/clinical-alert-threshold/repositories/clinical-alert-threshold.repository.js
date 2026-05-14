/**
 * Clinical alert threshold repository
 *
 * @module modules/clinical-alert-threshold/repositories
 * @description Data access layer for vital threshold configuration.
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const findMany = async (filters = {}, orderBy = [{ vital_type: 'asc' }, { component: 'asc' }, { age_band: 'asc' }]) => {
  try {
    return await prisma.clinical_vital_alert_threshold.findMany({
      where: {
        deleted_at: null,
        ...filters,
      },
      orderBy,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createMany = async (data = []) => {
  if (!Array.isArray(data) || data.length === 0) {
    return { count: 0 };
  }

  try {
    return await prisma.clinical_vital_alert_threshold.createMany({
      data,
    });
  } catch (error) {
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const softDeleteByScope = async ({ tenant_id, facility_id }) => {
  try {
    return await prisma.clinical_vital_alert_threshold.updateMany({
      where: {
        deleted_at: null,
        tenant_id,
        facility_id: facility_id || null,
      },
      data: {
        is_active: false,
        deleted_at: new Date(),
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  findMany,
  createMany,
  softDeleteByScope,
};

