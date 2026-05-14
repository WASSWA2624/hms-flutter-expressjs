/**
 * Public service
 */

const publicRepository = require('@repositories/public/public.repository');

const buildPagination = (page, limit, total) => {
  const totalPages = Math.ceil(total / limit);
  return {
    page,
    limit,
    total,
    totalPages,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1
  };
};

const listPublicServices = async (filters = {}, page = 1, limit = 20, sortBy = 'name', order = 'asc') => {
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };

  const { items, total } = await publicRepository.listPublicServices(filters.search, skip, limit, orderBy);

  return {
    items,
    pagination: buildPagination(page, limit, total)
  };
};

const listPublicProviders = async (filters = {}, page = 1, limit = 20, sortBy = 'created_at', order = 'desc') => {
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };

  const { items, total } = await publicRepository.listPublicProviders(filters.search, skip, limit, orderBy);

  return {
    items,
    pagination: buildPagination(page, limit, total)
  };
};

const listPublicBranches = async (filters = {}, page = 1, limit = 20, sortBy = 'name', order = 'asc') => {
  const skip = (page - 1) * limit;
  const orderBy = { [sortBy]: order };

  const { items, total } = await publicRepository.listPublicBranches(filters.search, skip, limit, orderBy);

  return {
    items,
    pagination: buildPagination(page, limit, total)
  };
};

module.exports = {
  listPublicServices,
  listPublicProviders,
  listPublicBranches
};
