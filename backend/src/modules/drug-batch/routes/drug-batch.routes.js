/**
 * Drug batch routes
 *
 * @module modules/drug-batch/routes
 * @description Drug batch endpoints mounted at /api/v1/drug-batches
 * Per module-creation.mdc: Apply all required middlewares
 * Per api.mdc: All endpoints must follow REST conventions
 */

const express = require('express');
const router = express.Router();
const drugBatchController = require('@controllers/drug-batch/drug-batch.controller');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate } = require('@middlewares/auth.middleware');
const {
  createDrugBatchSchema,
  updateDrugBatchSchema,
  drugBatchIdParamsSchema,
  listDrugBatchesQuerySchema
} = require('@validations/drug-batch/drug-batch.schema');

/**
 * @description List drug batches with pagination and filters
 * @method GET
 * @route /api/v1/drug-batches/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams {number} [page=1] - Page number
 * @queryParams {number} [limit=20] - Items per page
 * @queryParams {string} [sort_by=created_at] - Field to sort by
 * @queryParams {string} [order=desc] - Sort order (asc/desc)
 * @queryParams {string} [drug_id] - Filter by drug ID (UUID)
 * @queryParams {string} [batch_number] - Filter by batch number (partial match)
 * @queryParams {string} [expired] - Filter by expiration status (true/false)
 * @queryParams {string} [search] - Search in batch number field
 * @bodyParams None
 * @returns {Object} Paginated list of drug batches
 * @throws 401 Unauthorized
 */
router.get(
  '/',  validateRequest({ query: listDrugBatchesQuerySchema }),

  authenticate(),
  drugBatchController.listDrugBatches
);

/**
 * @description Get drug batch by ID
 * @method GET
 * @route /api/v1/drug-batches/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Drug batch ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {Object} Drug batch data
 * @throws 401 Unauthorized
 * @throws 404 Drug batch not found
 */
router.get(
  '/:id',  validateRequest({ params: drugBatchIdParamsSchema }),

  authenticate(),
  drugBatchController.getDrugBatchById
);

/**
 * @description Create new drug batch
 * @method POST
 * @route /api/v1/drug-batches/
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams None
 * @queryParams None
 * @bodyParams {string} drug_id - Drug ID (required, UUID)
 * @bodyParams {string} batch_number - Batch number (required, max 80 chars)
 * @bodyParams {string} [expiry_date] - Expiry date (ISO 8601 datetime)
 * @bodyParams {number} [quantity=0] - Quantity (non-negative integer)
 * @returns {Object} Created drug batch
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.post(
  '/',  validateRequest({ body: createDrugBatchSchema }),

  authenticate(),
  drugBatchController.createDrugBatch
);

/**
 * @description Update drug batch
 * @method PUT
 * @route /api/v1/drug-batches/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Drug batch ID (UUID)
 * @queryParams None
 * @bodyParams {string} [batch_number] - Batch number (max 80 chars)
 * @bodyParams {string} [expiry_date] - Expiry date (ISO 8601 datetime)
 * @bodyParams {number} [quantity] - Quantity (non-negative integer)
 * @returns {Object} Updated drug batch
 * @throws 401 Unauthorized
 * @throws 400 Validation error
 * @throws 404 Drug batch not found
 * @throws 400 Foreign key constraint violation
 * @throws 409 Unique constraint violation
 */
router.put(
  '/:id',  validateRequest({ params: drugBatchIdParamsSchema, body: updateDrugBatchSchema }),

  authenticate(),
  drugBatchController.updateDrugBatch
);

/**
 * @description Delete drug batch (soft delete)
 * @method DELETE
 * @route /api/v1/drug-batches/:id
 * @authentication Required (JWT)
 * @permissions Authenticated users
 * @urlParams {string} id - Drug batch ID (UUID)
 * @queryParams None
 * @bodyParams None
 * @returns {void} 204 No Content
 * @throws 401 Unauthorized
 * @throws 404 Drug batch not found
 */
router.delete(
  '/:id',  validateRequest({ params: drugBatchIdParamsSchema }),

  authenticate(),
  drugBatchController.deleteDrugBatch
);

module.exports = router;
