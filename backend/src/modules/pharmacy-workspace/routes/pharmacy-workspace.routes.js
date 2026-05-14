const express = require('express');
const { validateRequest } = require('@middlewares/validate.middleware');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { PERMISSIONS } = require('@config/permissions');
const pharmacyWorkspaceController = require('@controllers/pharmacy-workspace/pharmacy-workspace.controller');
const {
  orderWorkflowParamsSchema,
  getPharmacyWorkbenchQuerySchema,
  searchDrugsQuerySchema,
  createPharmacyOrderSchema,
  prepareDispenseSchema,
  attestDispenseSchema,
  cancelPharmacyOrderSchema,
  returnPharmacyOrderSchema,
  getInventoryStockQuerySchema,
  adjustInventorySchema,
  resolveLegacyRouteParamsSchema,
} = require('@validations/pharmacy-workspace/pharmacy-workspace.schema');

const router = express.Router();

const PHARMACY_WORKSPACE_READ_SCOPES = [PERMISSIONS.PHARMACY_READ, PERMISSIONS.OPERATIONS_READ];
const PHARMACY_WORKSPACE_WRITE_SCOPES = [PERMISSIONS.PHARMACY_WRITE];
const INVENTORY_WRITE_SCOPES = [PERMISSIONS.OPERATIONS_WRITE, PERMISSIONS.PHARMACY_WRITE];

router.get(
  '/workbench',
  validateRequest({ query: getPharmacyWorkbenchQuerySchema }),
  authenticate(),
  authorize(PHARMACY_WORKSPACE_READ_SCOPES, 'permission'),
  pharmacyWorkspaceController.getPharmacyWorkbench
);

router.get(
  '/drugs',
  validateRequest({ query: searchDrugsQuerySchema }),
  authenticate(),
  authorize(PHARMACY_WORKSPACE_READ_SCOPES, 'permission'),
  pharmacyWorkspaceController.searchDrugs
);

router.post(
  '/orders',
  validateRequest({ body: createPharmacyOrderSchema }),
  authenticate(),
  authorize(PHARMACY_WORKSPACE_WRITE_SCOPES, 'permission'),
  pharmacyWorkspaceController.createPharmacyOrder
);

router.get(
  '/resolve-legacy/:resource/:id',
  validateRequest({ params: resolveLegacyRouteParamsSchema }),
  authenticate(),
  authorize(PHARMACY_WORKSPACE_READ_SCOPES, 'permission'),
  pharmacyWorkspaceController.resolveLegacyRoute
);

router.get(
  '/orders/:id/workflow',
  validateRequest({ params: orderWorkflowParamsSchema }),
  authenticate(),
  authorize(PHARMACY_WORKSPACE_READ_SCOPES, 'permission'),
  pharmacyWorkspaceController.getPharmacyOrderWorkflow
);

router.post(
  '/orders/:id/prepare-dispense',
  validateRequest({ params: orderWorkflowParamsSchema, body: prepareDispenseSchema }),
  authenticate(),
  authorize(PHARMACY_WORKSPACE_WRITE_SCOPES, 'permission'),
  pharmacyWorkspaceController.prepareDispense
);

router.post(
  '/orders/:id/attest-dispense',
  validateRequest({ params: orderWorkflowParamsSchema, body: attestDispenseSchema }),
  authenticate(),
  authorize(PHARMACY_WORKSPACE_WRITE_SCOPES, 'permission'),
  pharmacyWorkspaceController.attestDispense
);

router.post(
  '/orders/:id/cancel',
  validateRequest({ params: orderWorkflowParamsSchema, body: cancelPharmacyOrderSchema }),
  authenticate(),
  authorize(PHARMACY_WORKSPACE_WRITE_SCOPES, 'permission'),
  pharmacyWorkspaceController.cancelPharmacyOrder
);

router.post(
  '/orders/:id/return',
  validateRequest({ params: orderWorkflowParamsSchema, body: returnPharmacyOrderSchema }),
  authenticate(),
  authorize(PHARMACY_WORKSPACE_WRITE_SCOPES, 'permission'),
  pharmacyWorkspaceController.returnDispense
);

router.get(
  '/inventory/stock',
  validateRequest({ query: getInventoryStockQuerySchema }),
  authenticate(),
  authorize(PHARMACY_WORKSPACE_READ_SCOPES, 'permission'),
  pharmacyWorkspaceController.getInventoryStock
);

router.post(
  '/inventory/adjust',
  validateRequest({ body: adjustInventorySchema }),
  authenticate(),
  authorize(INVENTORY_WRITE_SCOPES, 'permission'),
  pharmacyWorkspaceController.adjustInventoryStock
);

module.exports = router;
