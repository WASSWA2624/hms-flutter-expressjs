const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const DEFAULT_INCLUDE = {
  tenant: { select: { id: true, human_friendly_id: true } },
  facility: { select: { id: true, human_friendly_id: true } },
  branch: { select: { id: true, human_friendly_id: true } },
  patient: { select: { id: true, human_friendly_id: true } },
  requested_by: { select: { id: true, human_friendly_id: true } },
  approved_by: { select: { id: true, human_friendly_id: true } },
  revoked_by: { select: { id: true, human_friendly_id: true } },
  reviews: {
    where: { deleted_at: null },
    include: {
      reviewer: { select: { id: true, human_friendly_id: true } },
    },
    orderBy: { decided_at: 'desc' },
  },
};

const findById = async (id, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.break_glass_access.findFirst({
      where: { id, deleted_at: null },
      include,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findMany = async (where = {}, skip = 0, take = 20, orderBy = { requested_at: 'desc' }, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.break_glass_access.findMany({
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
    return await prisma.break_glass_access.count({ where: { deleted_at: null, ...where } });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const create = async (data) => {
  try {
    return await prisma.break_glass_access.create({ data, include: DEFAULT_INCLUDE });
  } catch (error) {
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const update = async (id, data) => {
  try {
    return await prisma.break_glass_access.update({ where: { id }, data, include: DEFAULT_INCLUDE });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.break_glass_access.not_found', 404);
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  count,
  create,
  findById,
  findMany,
  update,
};
