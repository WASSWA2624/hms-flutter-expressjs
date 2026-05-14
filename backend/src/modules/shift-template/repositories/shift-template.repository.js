/**
 * Shift template repository
 */
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const findById = async (id, include = {}) => {
  try {
    return await prisma.shift_template.findFirst({
      where: { id, deleted_at: null },
      include
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    const where = { deleted_at: null, ...filters };
    return await prisma.shift_template.findMany({ where, skip, take, orderBy, include });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const count = async (filters = {}) => {
  try {
    const where = { deleted_at: null, ...filters };
    return await prisma.shift_template.count({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const create = async (data) => {
  try {
    return await prisma.shift_template.create({ data });
  } catch (error) {
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409, [{ field: error.meta?.target?.[0] || 'field' }]);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400, [{ field: error.meta?.field_name || 'field' }]);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const update = async (id, data) => {
  try {
    return await prisma.shift_template.update({ where: { id }, data });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.shift_template.not_found', 404);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const softDelete = async (id) => {
  try {
    return await prisma.shift_template.update({ where: { id }, data: { deleted_at: new Date() } });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.shift_template.not_found', 404);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = { findById, findMany, count, create, update, softDelete };
