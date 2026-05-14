/**
 * Campaign repository
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const getCampaignIdFromEventName = (eventName = '') => {
  const parts = String(eventName).split('.');
  if (parts.length < 3 || parts[0] !== 'campaign') {
    return null;
  }
  return parts[1];
};

const getCampaignMetricFromEventName = (eventName = '') => {
  const parts = String(eventName).split('.');
  if (parts.length < 3 || parts[0] !== 'campaign') {
    return null;
  }
  return parts[2];
};

const listCampaigns = async (tenantId, search, skip, take) => {
  try {
    const where = {
      deleted_at: null,
      event_name: {
        startsWith: 'campaign.'
      }
    };

    if (tenantId) {
      where.tenant_id = tenantId;
    }

    const events = await prisma.analytics_event.findMany({
      where,
      orderBy: {
        occurred_at: 'desc'
      },
      select: {
        event_name: true,
        occurred_at: true
      },
      take: 5000
    });

    const campaignMap = new Map();

    for (const event of events) {
      const campaignId = getCampaignIdFromEventName(event.event_name);
      if (!campaignId) continue;

      if (!campaignMap.has(campaignId)) {
        campaignMap.set(campaignId, {
          id: campaignId,
          last_event_at: event.occurred_at,
          status: 'ACTIVE'
        });
      }
    }

    let campaigns = Array.from(campaignMap.values());

    if (search) {
      const normalized = search.toLowerCase();
      campaigns = campaigns.filter((campaign) => campaign.id.toLowerCase().includes(normalized));
    }

    const total = campaigns.length;
    const items = campaigns.slice(skip, skip + take);

    return { items, total };
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

const getCampaignMetrics = async (tenantId, campaignId) => {
  try {
    const where = {
      deleted_at: null,
      event_name: {
        startsWith: `campaign.${campaignId}.`
      }
    };

    if (tenantId) {
      where.tenant_id = tenantId;
    }

    const events = await prisma.analytics_event.findMany({
      where,
      select: {
        event_name: true,
        occurred_at: true
      }
    });

    const metrics = {
      views: 0,
      clicks: 0,
      conversions: 0,
      total_events: events.length,
      last_event_at: null
    };

    for (const event of events) {
      const metric = getCampaignMetricFromEventName(event.event_name);
      if (metric === 'view') metrics.views += 1;
      if (metric === 'click') metrics.clicks += 1;
      if (metric === 'conversion') metrics.conversions += 1;

      if (!metrics.last_event_at || new Date(event.occurred_at) > new Date(metrics.last_event_at)) {
        metrics.last_event_at = event.occurred_at;
      }
    }

    return metrics;
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  listCampaigns,
  getCampaignMetrics
};
