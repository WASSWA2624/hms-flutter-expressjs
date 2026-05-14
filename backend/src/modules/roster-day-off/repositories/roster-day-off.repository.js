/**
 * Roster day off repository
 */
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const findById = async (id, include = {}) => {
  try {
    return await prisma.roster_day_off.findFirst({
      where: { id, deleted_at: null },
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { off_date: 'asc' }, include = {}) => {
  try {
    const where = { deleted_at: null, ...filters };
    if (filters.off_date_from || filters.off_date_to) {
      where.off_date = {};
      if (filters.off_date_from) where.off_date.gte = new Date(filters.off_date_from);
      if (filters.off_date_to) where.off_date.lte = new Date(filters.off_date_to);
      delete where.off_date_from;
      delete where.off_date_to;
    }
    return await prisma.roster_day_off.findMany({ where, skip, take, orderBy, include });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const count = async (filters = {}) => {
  try {
    const where = { deleted_at: null, ...filters };
    if (filters.off_date_from || filters.off_date_to) {
      where.off_date = {};
      if (filters.off_date_from) where.off_date.gte = new Date(filters.off_date_from);
      if (filters.off_date_to) where.off_date.lte = new Date(filters.off_date_to);
      delete where.off_date_from;
      delete where.off_date_to;
    }
    return await prisma.roster_day_off.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const create = async (data) => {
  try {
    return await prisma.roster_day_off.create({ data: { ...data, off_date: new Date(data.off_date) } });
  } catch (error) {
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409, [{ field: 'nurse_roster_id, staff_profile_id, off_date' }]);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400, [{ field: error.meta?.field_name || 'field' }]);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const update = async (id, data) => {
  try {
    if (data.off_date) data.off_date = new Date(data.off_date);
    return await prisma.roster_day_off.update({ where: { id }, data });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.roster_day_off.not_found', 404);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const softDelete = async (id) => {
  try {
    return await prisma.roster_day_off.update({ where: { id }, data: { deleted_at: new Date() } });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.roster_day_off.not_found', 404);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = { findById, findMany, count, create, update, softDelete };
