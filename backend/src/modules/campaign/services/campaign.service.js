/**
 * Campaign service
 */

const campaignRepository = require('@repositories/campaign/campaign.repository');

const listCampaigns = async (tenantId, filters = {}, page = 1, limit = 20) => {
  const skip = (page - 1) * limit;
  const { items, total } = await campaignRepository.listCampaigns(tenantId, filters.search, skip, limit);

  const totalPages = Math.ceil(total / limit);

  return {
    campaigns: items,
    pagination: {
      page,
      limit,
      total,
      totalPages,
      hasNextPage: page < totalPages,
      hasPreviousPage: page > 1
    }
  };
};

const getCampaignMetrics = async (tenantId, campaignId) => {
  const metrics = await campaignRepository.getCampaignMetrics(tenantId, campaignId);

  const conversionRate = metrics.views > 0
    ? Math.round((metrics.conversions / metrics.views) * 10000) / 100
    : 0;

  return {
    campaign_id: campaignId,
    ...metrics,
    conversion_rate_percent: conversionRate
  };
};

module.exports = {
  listCampaigns,
  getCampaignMetrics
};
