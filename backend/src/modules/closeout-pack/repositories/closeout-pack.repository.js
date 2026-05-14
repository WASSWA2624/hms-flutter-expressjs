const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const DEFAULT_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true } },
  facility: { select: { id: true, human_friendly_id: true } },
  branch: { select: { id: true, human_friendly_id: true } },
  office_context: { select: { id: true, human_friendly_id: true } },
  shift_close: { select: { id: true, human_friendly_id: true } },
  day_close: { select: { id: true, human_friendly_id: true } },
  handover: { select: { id: true, human_friendly_id: true } },
  custody_snapshot: { select: { id: true, human_friendly_id: true } },
  generated_by: { select: { id: true, human_friendly_id: true } },
};

const findById = async (id, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.closeout_pack.findFirst({
      where: { id, deleted_at: null },
      include,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findMany = async (where = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.closeout_pack.findMany({
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
    return await prisma.closeout_pack.count({ where: { deleted_at: null, ...where } });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const create = async (data) => {
  try {
    return await prisma.closeout_pack.create({ data, include: DEFAULT_INCLUDE });
  } catch (error) {
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const update = async (id, data) => {
  try {
    return await prisma.closeout_pack.update({ where: { id }, data, include: DEFAULT_INCLUDE });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.closeout_pack.not_found', 404);
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
