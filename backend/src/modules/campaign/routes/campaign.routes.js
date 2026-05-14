/**
 * Campaign routes
 */

const express = require('express');
const router = express.Router();
const campaignController = require('@controllers/campaign/campaign.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { campaignIdParamsSchema, listCampaignsQuerySchema } = require('@validations/campaign/campaign.schema');

router.get('/', validateRequest({ query: listCampaignsQuerySchema }), campaignController.listCampaigns);
router.get('/:id/metrics', validateRequest({ params: campaignIdParamsSchema }), campaignController.getCampaignMetrics);

module.exports = router;
