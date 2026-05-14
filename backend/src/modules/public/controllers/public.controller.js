/**
 * Public controller
 */

const publicService = require('@services/public/public.service');
const { asyncHandler } = require('@lib/async');
const { sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listPublicServices = asyncHandler(async (req, res) => {
  const {
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const result = await publicService.listPublicServices(
    { search },
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by || 'name',
    order
  );

  sendPaginated(res, 'messages.public.services.list.success', result.items, result.pagination);
});

const listPublicProviders = asyncHandler(async (req, res) => {
  const {
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'
  } = req.query;

  const result = await publicService.listPublicProviders(
    { search },
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by || 'created_at',
    order
  );

  sendPaginated(res, 'messages.public.providers.list.success', result.items, result.pagination);
});

const listPublicBranches = asyncHandler(async (req, res) => {
  const {
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'
  } = req.query;

  const result = await publicService.listPublicBranches(
    { search },
    parseInt(page, 10),
    parseInt(limit, 10),
    sort_by || 'name',
    order
  );

  sendPaginated(res, 'messages.public.branches.list.success', result.items, result.pagination);
});

module.exports = {
  listPublicServices,
  listPublicProviders,
  listPublicBranches
};
