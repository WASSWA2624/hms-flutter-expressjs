const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const baseSelect = {
  tenant: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  creator: {
    select: {
      id: true,
      human_friendly_id: true,
      email: true,
    },
  },
  facility: {
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
    },
  },
  schedules: {
    where: { deleted_at: null },
    select: {
      id: true,
      human_friendly_id: true,
      name: true,
      status: true,
    },
  },
  runs: {
    where: { deleted_at: null },
    take: 1,
    orderBy: [{ queued_at: 'desc' }, { created_at: 'desc' }],
    include: {
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
        },
      },
      requested_by: {
        select: {
          id: true,
          human_friendly_id: true,
          email: true,
          profile: {
            select: {
              first_name: true,
            },
          },
        },
      },
      schedule: {
        select: {
          id: true,
          human_friendly_id: true,
          name: true,
          retention_days: true,
        },
      },
    },
  },
  _count: {
    select: {
      schedules: {
        where: { deleted_at: null },
      },
    },
  },
};

const mapError = (error, fallbackKey = 'errors.database.unexpected') => {
  if (error?.code === 'P2025') {
    throw new HttpError('errors.report_definition.not_found', 404);
  }
  if (error?.code === 'P2002') {
    const target = error.meta?.target?.[0] || 'field';
    throw new HttpError('errors.database.unique_field', 409, [{ field: target }]);
  }
  if (error?.code === 'P2003') {
    const target = error.meta?.field_name || 'field';
    throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
  }
  throw new HttpError(fallbackKey, 500, [{ originalError: error?.message }]);
};

const findById = async (id) => {
  try {
    return await prisma.report_definition.findFirst({
      where: {
        id,
        deleted_at: null,
      },
      include: baseSelect,
    });
  } catch (error) {
    mapError(error);
  }
};

const findMany = async ({ where = {}, skip = 0, take = 20, orderBy = { updated_at: 'desc' } } = {}) => {
  try {
    return await prisma.report_definition.findMany({
      where: {
        deleted_at: null,
        ...where,
      },
      skip,
      take,
      orderBy,
      include: baseSelect,
    });
  } catch (error) {
    mapError(error);
  }
};

const count = async (where = {}) => {
  try {
    return await prisma.report_definition.count({
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
    return await prisma.report_definition.create({
      data,
      include: baseSelect,
    });
  } catch (error) {
    mapError(error);
  }
};

const update = async (id, data) => {
  try {
    return await prisma.report_definition.update({
      where: { id },
      data,
      include: baseSelect,
    });
  } catch (error) {
    mapError(error);
  }
};

const softDelete = async (id) => {
  try {
    return await prisma.report_definition.update({
      where: { id },
      data: {
        deleted_at: new Date(),
      },
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
