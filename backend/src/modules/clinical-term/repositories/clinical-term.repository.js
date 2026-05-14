const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const findFavorites = async (where = {}, orderBy = [{ usage_count: 'desc' }, { last_used_at: 'desc' }, { created_at: 'desc' }]) => {
  try {
    return await prisma.clinical_term_favorite.findMany({
      where,
      orderBy,
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findFavorite = async (where = {}) => {
  try {
    return await prisma.clinical_term_favorite.findFirst({ where });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const createFavorite = async (data = {}) => {
  try {
    return await prisma.clinical_term_favorite.create({ data });
  } catch (error) {
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const updateFavorite = async (id, data = {}) => {
  try {
    return await prisma.clinical_term_favorite.update({
      where: { id },
      data,
    });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.clinical_term_favorite.not_found', 404);
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findRecentProcedures = async (where = {}, take = 12) => {
  try {
    return await prisma.procedure.findMany({
      where,
      orderBy: { created_at: 'desc' },
      take,
      select: {
        code: true,
        description: true,
        created_at: true,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findRecentDiagnoses = async (where = {}, take = 12) => {
  try {
    return await prisma.diagnosis.findMany({
      where,
      orderBy: { created_at: 'desc' },
      take,
      select: {
        code: true,
        description: true,
        created_at: true,
      },
    });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  createFavorite,
  findFavorite,
  findFavorites,
  findRecentDiagnoses,
  findRecentProcedures,
  updateFavorite,
};
