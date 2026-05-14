/**
 * Campaign controller
 */

const campaignService = require('@services/campaign/campaign.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listCampaigns = asyncHandler(async (req, res) => {
  const {
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT
  } = req.query;

  const result = await campaignService.listCampaigns(
    req.user?.tenant_id,
    { search },
    parseInt(page, 10),
    parseInt(limit, 10)
  );

  sendPaginated(res, 'messages.campaign.list.success', result.campaigns, result.pagination);
});

const getCampaignMetrics = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const metrics = await campaignService.getCampaignMetrics(req.user?.tenant_id, id);

  sendSuccess(res, 200, 'messages.campaign.metrics.success', metrics);
});

module.exports = {
  listCampaigns,
  getCampaignMetrics
};
