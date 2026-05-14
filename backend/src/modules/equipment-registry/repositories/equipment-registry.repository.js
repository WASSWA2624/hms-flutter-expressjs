const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const findById = async (id, include = {}) => {
  try {
    return await prisma.equipment_registry.findFirst({ where: { id, deleted_at: null }, include });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = {}) => {
  try {
    return await prisma.equipment_registry.findMany({ where: { deleted_at: null, ...filters }, skip, take, orderBy, include });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const count = async (filters = {}) => {
  try {
    return await prisma.equipment_registry.count({ where: { deleted_at: null, ...filters } });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const create = async (data) => {
  try {
    return await prisma.equipment_registry.create({ data });
  } catch (error) {
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const update = async (id, data) => {
  try {
    return await prisma.equipment_registry.update({ where: { id }, data });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.equipment_registry.not_found', 404);
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const softDelete = async (id) => {
  try {
    return await prisma.equipment_registry.update({ where: { id }, data: { deleted_at: new Date() } });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.equipment_registry.not_found', 404);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = { findById, findMany, count, create, update, softDelete };
