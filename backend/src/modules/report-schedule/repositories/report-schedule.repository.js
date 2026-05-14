const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const includeShape = {
  facility: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  report_definition: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      default_format: true,
    },
  },
  creator: {
    select: {
      id: true,
      human_friendly_id: true,
      email: true,
    },
  },
  _count: {
    select: {
      runs: {
        where: {
          deleted_at: null,
          status: { in: ['QUEUED', 'PROCESSING'] },
        },
      },
    },
  },
};

const mapError = (error) => {
  if (error?.code === 'P2025') {
    throw new HttpError('errors.report_schedule.not_found', 404);
  }
  if (error?.code === 'P2002') {
    const target = error.meta?.target?.[0] || 'field';
    throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
  }
  if (error?.code === 'P2003') {
    const target = error.meta?.field_name || 'field';
    throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
  }
  throw new HttpError('errors.database.unexpected', 500, [{ originalError: error?.message }]);
};

const findById = async (id) => {
  try {
    return await prisma.report_schedule.findFirst({
      where: { id, deleted_at: null },
      include: includeShape,
    });
  } catch (error) {
    mapError(error);
  }
};

const findMany = async ({ where = {}, skip = 0, take = 20, orderBy = { next_run_at: 'asc' } } = {}) => {
  try {
    return await prisma.report_schedule.findMany({
      where: {
        deleted_at: null,
        ...where,
      },
      skip,
      take,
      orderBy,
      include: includeShape,
    });
  } catch (error) {
    mapError(error);
  }
};

const count = async (where = {}) => {
  try {
    return await prisma.report_schedule.count({
      where: {
        deleted_at: null,
        ...where,
      },
    });
  } catch (error) {
    mapError(error);
  }
};

const create = async (data) => {
  try {
    return await prisma.report_schedule.create({
      data,
      include: includeShape,
    });
  } catch (error) {
    mapError(error);
  }
};

const update = async (id, data) => {
  try {
    return await prisma.report_schedule.update({
      where: { id },
      data,
      include: includeShape,
    });
  } catch (error) {
    mapError(error);
  }
};

const softDelete = async (id) => {
  try {
    return await prisma.report_schedule.update({
      where: { id },
      data: { deleted_at: new Date() },
    });
  } catch (error) {
    mapError(error);
  }
};

module.exports = {
  count,
  create,
  findById,
  findMany,
  softDelete,
  update,
};
