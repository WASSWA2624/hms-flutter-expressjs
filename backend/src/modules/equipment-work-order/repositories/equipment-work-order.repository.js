const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const DEFAULT_INCLUDE = {
  equipment_registry: {
    select: {
      id: true,
      human_friendly_id: true,
      equipment_name: true,
      equipment_code: true,
      tenant_id: true,
    },
  },
  maintenance_plan: {
    select: {
      id: true,
      human_friendly_id: true,
      plan_name: true,
    },
  },
};

const buildWhere = (filters = {}) => {
  const { search, ...rest } = filters || {};
  const where = { deleted_at: null, ...rest };
  const normalizedSearch = String(search || '').trim();

  if (!normalizedSearch) return where;

  const searchUpper = normalizedSearch.toUpperCase();
  where.AND = [
    ...(Array.isArray(where.AND) ? where.AND : []),
    {
      OR: [
        { human_friendly_id: { contains: searchUpper } },
        { title: { contains: normalizedSearch, mode: 'insensitive' } },
        { description: { contains: normalizedSearch, mode: 'insensitive' } },
        { equipment_registry: { equipment_name: { contains: normalizedSearch } } },
        { equipment_registry: { equipment_code: { contains: normalizedSearch } } },
      ],
    },
  ];

  return where;
};

const findById = async (id, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.equipment_work_order.findFirst({ where: buildWhere({ id }), include });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findMany = async (filters = {}, skip = 0, take = 20, orderBy = { created_at: 'desc' }, include = DEFAULT_INCLUDE) => {
  try {
    return await prisma.equipment_work_order.findMany({ where: buildWhere(filters), skip, take, orderBy, include });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const count = async (filters = {}) => {
  try {
    return await prisma.equipment_work_order.count({ where: buildWhere(filters) });
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const create = async (data) => {
  try {
    return await prisma.equipment_work_order.create({ data, include: DEFAULT_INCLUDE });
  } catch (error) {
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const update = async (id, data) => {
  try {
    return await prisma.equipment_work_order.update({ where: { id }, data, include: DEFAULT_INCLUDE });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.equipment_work_order.not_found', 404);
    if (error.code === 'P2002') throw new HttpError('errors.database.unique_field', 409);
    if (error.code === 'P2003') throw new HttpError('errors.database.foreign_key_field', 400);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const softDelete = async (id) => {
  try {
    return await prisma.equipment_work_order.update({ where: { id }, data: { deleted_at: new Date() }, include: DEFAULT_INCLUDE });
  } catch (error) {
    if (error.code === 'P2025') throw new HttpError('errors.equipment_work_order.not_found', 404);
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const findRecipientUserIds = async (tenantId) => {
  try {
    const rows = await prisma.user_role.findMany({
      where: {
        tenant_id: tenantId,
        deleted_at: null,
        role: { name: { in: ['BIOMED', 'OPERATIONS', 'FACILITY_ADMIN', 'TENANT_ADMIN'] }, deleted_at: null },
        user: { deleted_at: null },
      },
      select: { user_id: true },
    });

    return Array.from(new Set(rows.map((entry) => entry.user_id).filter(Boolean)));
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = { findById, findMany, count, create, update, softDelete, findRecipientUserIds };
