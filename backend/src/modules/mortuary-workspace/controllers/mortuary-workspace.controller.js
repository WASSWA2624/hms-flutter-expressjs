const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');
const mortuaryWorkspaceService = require('@services/mortuary-workspace/mortuary-workspace.service');

/**
 * Load the mortuary workspace payload for the selected filters and panel.
 *
 * @param {import('express').Request} req
 * @param {import('express').Response} res
 * @returns {Promise<import('express').Response>}
 */
const getWorkspace = asyncHandler(async (req, res) => {
  const { page = DEFAULT_PAGE, limit = DEFAULT_PAGE_LIMIT, sort_by, order = 'desc', ...filters } = req.query;
  const data = await mortuaryWorkspaceService.getWorkspace(
    filters,
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user
  );

  return sendSuccess(res, 200, 'messages.mortuary_workspace.workspace.success', data);
});

/**
 * Load reference filters and lookup values for Mortuary workspace forms.
 *
 * @param {import('express').Request} req
 * @param {import('express').Response} res
 * @returns {Promise<import('express').Response>}
 */
const getLookups = asyncHandler(async (req, res) => {
  const data = await mortuaryWorkspaceService.getLookups(req.query, req.user);
  return sendSuccess(res, 200, 'messages.mortuary_workspace.lookups.success', data);
});

module.exports = {
  getWorkspace,
  getLookups,
};
