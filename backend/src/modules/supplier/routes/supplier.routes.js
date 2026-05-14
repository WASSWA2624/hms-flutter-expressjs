/**
 * Supplier routes
 *
 * @module modules/supplier/routes
 * @description Express routes for supplier endpoints.
 * Per module-creation.mdc: Routes define endpoints and apply middlewares.
 * Per api.mdc: All endpoints under /api/v1/suppliers
 */

const express = require('express');
const router = express.Router();

const supplierController = require('@controllers/supplier/supplier.controller');
const validate = require('@middlewares/validate.middleware');
const {
  createSupplierSchema,
  updateSupplierSchema,
  supplierIdParamsSchema,
  listSuppliersQuerySchema
} = require('@validations/supplier/supplier.schema');

/**
 * @route GET /api/v1/suppliers
 * @desc List suppliers with pagination
 * @access Private
 */
router.get(
  '/',
  validate({ query: listSuppliersQuerySchema }),
  supplierController.listSuppliers
);

/**
 * @route GET /api/v1/suppliers/:id
 * @desc Get supplier by ID
 * @access Private
 */
router.get(
  '/:id',
  validate({ params: supplierIdParamsSchema }),
  supplierController.getSupplier
);

/**
 * @route POST /api/v1/suppliers
 * @desc Create new supplier
 * @access Private
 */
router.post(
  '/',
  validate({ body: createSupplierSchema }),
  supplierController.createSupplier
);

/**
 * @route PUT /api/v1/suppliers/:id
 * @desc Update supplier
 * @access Private
 */
router.put(
  '/:id',
  validate({ params: supplierIdParamsSchema, body: updateSupplierSchema }),
  supplierController.updateSupplier
);

/**
 * @route DELETE /api/v1/suppliers/:id
 * @desc Delete supplier (soft delete)
 * @access Private
 */
router.delete(
  '/:id',
  validate({ params: supplierIdParamsSchema }),
  supplierController.deleteSupplier
);

module.exports = router;
