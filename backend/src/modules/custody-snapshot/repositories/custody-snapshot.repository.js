const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const DEFAULT_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true } },
  facility: { select: { id: true, human_friendly_id: true } },
  branch: { select: { id: true, human_friendly_id: true } },
  office_context: { select: { id: true, human_friendly_id: true } },
  captured_by: { select: { id: true, human_friendly_id: true } },
};

const findById = async (id, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.custody_snapshot.findFirst({
      where: { id, deleted_at: null },
      include,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findMany = async (where = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.custody_snapshot.findMany({
      where: { deleted_at: null, ...where },
      skip,
      take,
      orderBy,
      include,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const count = async (where = {}) => {
  try {
    return await prisma.custody_snapshot.count({ where: { deleted_at: null, ...where } });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const create = async (data) => {
  try {
    return await prisma.custody_snapshot.create({ data, include: DEFAULT_INCLUDE });
  } catch (error) {
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const update = async (id, data) => {
  try {
    return await prisma.custody_snapshot.update({ where: { id }, data, include: DEFAULT_INCLUDE });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.custody_snapshot.not_found', 404);
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const softDelete = async (id) => update(id, { deleted_at: new Date() });

module.exports = {
  count,
  create,
  findById,
  findMany,
  softDelete,
  update,
};
