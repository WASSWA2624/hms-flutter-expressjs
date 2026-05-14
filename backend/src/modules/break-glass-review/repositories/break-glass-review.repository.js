const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const DEFAULT_INCLUDE = {
  break_glass_access: {
    include: {
      patient: { select: { id: true, human_friendly_id: true } },
      requested_by: { select: { id: true, human_friendly_id: true } },
      approved_by: { select: { id: true, human_friendly_id: true } },
    },
  },
  reviewer: { select: { id: true, human_friendly_id: true } },
  tenant: { select: { id: true, human_friendly_id: true } },
};

const findById = async (id, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.break_glass_review.findFirst({
      where: { id, deleted_at: null },
      include,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findMany = async (where = {}, skip = 0, take = 20, orderBy = { decided_at: 'desc' }, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.break_glass_review.findMany({
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
    return await prisma.break_glass_review.count({ where: { deleted_at: null, ...where } });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const create = async (data) => {
  try {
    return await prisma.break_glass_review.create({ data, include: DEFAULT_INCLUDE });
  } catch (error) {
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
};
