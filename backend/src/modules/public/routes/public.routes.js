/**
 * Public routes
 */

const express = require('express');
const router = express.Router();
const publicController = require('@controllers/public/public.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { listPublicResourcesQuerySchema } = require('@validations/public/public.schema');

router.get('/services', validateRequest({ query: listPublicResourcesQuerySchema }), publicController.listPublicServices);
router.get('/providers', validateRequest({ query: listPublicResourcesQuerySchema }), publicController.listPublicProviders);

module.exports = router;
