/**
 * Module service
 *
 * @module modules/module/services
 * @description Business logic for module operations.
 */

const moduleRepository = require('@repositories/module/module.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  createSubscriptionPublicId,
  PUBLIC_ID_PREFIXES,
} = require('@lib/subscriptions/constants');
const { serializeModule } = require('@lib/subscriptions/serializers');
const { resolveEntityId } = require('@lib/billing/identifiers');

const loadModuleRecord = async (identifier) => {
  const resolvedId = await resolveEntityId({
    model: 'module',
    identifier,
  });
  const record = await moduleRepository.findById(resolvedId);

  if (!record) {
    throw new HttpError('errors.module.not_found', 404);
  }

  return record;
};

const listModules = async (
  filters = {},
  page = 1,
  limit = 20,
  sort_by = 'created_at',
  order = 'desc'
) => {
  const repoFilters = {};

  if (filters.search) {
    repoFilters.OR = [
      { human_friendly_id: { contains: filters.search, mode: 'insensitive' } },
      { name: { contains: filters.search, mode: 'insensitive' } },
      { slug: { contains: filters.search, mode: 'insensitive' } },
      { description: { contains: filters.search, mode: 'insensitive' } },
    ];
  }

  const skip = (page - 1) * limit;
  const orderBy = {
    [sort_by]: order,
  };

  const [modules, total] = await Promise.all([
    moduleRepository.findMany(repoFilters, skip, limit, orderBy),
    moduleRepository.count(repoFilters),
  ]);

  const totalPages = Math.ceil(total / limit);
  const hasNextPage = page < totalPages;
  const hasPreviousPage = page > 1;

  return {
    modules: modules.map(serializeModule),
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage,
      hasPreviousPage,
    },
  };
};

const getModuleById = async (id) => {
  const moduleRecord = await loadModuleRecord(id);
  return serializeModule(moduleRecord);
};

const createModule = async (data, context) => {
  const created = await moduleRepository.create({
    ...data,
    human_friendly_id:
      data.human_friendly_id
      || createSubscriptionPublicId(PUBLIC_ID_PREFIXES.module),
  });
  const moduleRecord = await loadModuleRecord(created.id);

  createAuditLog({
    user_id: context.user?.id,
    action: 'CREATE',
    entity: 'module',
    entity_id: moduleRecord.id,
    diff: { after: moduleRecord },
    ip_address: context.ip,
    tenant_id: context.tenant_id || null,
  }).catch(() => {});

  return serializeModule(moduleRecord);
};

const updateModule = async (id, data, context) => {
  const existingModule = await loadModuleRecord(id);
  await moduleRepository.update(existingModule.id, data);
  const updatedModule = await loadModuleRecord(existingModule.id);

  createAuditLog({
    user_id: context.user?.id,
    action: 'UPDATE',
    entity: 'module',
    entity_id: updatedModule.id,
    diff: { before: existingModule, after: updatedModule },
    ip_address: context.ip,
    tenant_id: context.tenant_id || null,
  }).catch(() => {});

  return serializeModule(updatedModule);
};

const deleteModule = async (id, context) => {
  const existingModule = await loadModuleRecord(id);
  const deletedModule = await moduleRepository.softDelete(existingModule.id);

  createAuditLog({
    user_id: context.user?.id,
    action: 'DELETE',
    entity: 'module',
    entity_id: deletedModule.id,
    diff: { before: existingModule, after: deletedModule },
    ip_address: context.ip,
    tenant_id: context.tenant_id || null,
  }).catch(() => {});

  return deletedModule;
};

module.exports = {
  listModules,
  getModuleById,
  createModule,
  updateModule,
  deleteModule,
};
