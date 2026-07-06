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
  recordOrderBillingSchema,
  getInventoryStockQuerySchema,
  adjustInventorySchema,
  setupPharmacyDrugSchema,
  resolveLegacyRouteParamsSchema,
  getPharmacyStorageLayoutQuerySchema,
  createPharmacyStorageRoomSchema,
  updatePharmacyStorageRoomSchema,
  pharmacyStorageRoomParamsSchema,
  createPharmacyStorageShelfSchema,
  updatePharmacyStorageShelfSchema,
  pharmacyStorageShelfParamsSchema,
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
  '/drugs/setup',
  validateRequest({ body: setupPharmacyDrugSchema }),
  authenticate(),
  authorize(INVENTORY_WRITE_SCOPES, 'permission'),
  pharmacyWorkspaceController.setupPharmacyDrug
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

router.post(
  '/orders/:id/record-billing',
  validateRequest({ params: orderWorkflowParamsSchema, body: recordOrderBillingSchema }),
  authenticate(),
  authorize(PHARMACY_WORKSPACE_WRITE_SCOPES, 'permission'),
  pharmacyWorkspaceController.recordOrderBilling
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

router.get(
  '/storage/layout',
  validateRequest({ query: getPharmacyStorageLayoutQuerySchema }),
  authenticate(),
  authorize(PHARMACY_WORKSPACE_READ_SCOPES, 'permission'),
  pharmacyWorkspaceController.getPharmacyStorageLayout
);

router.post(
  '/storage/rooms',
  validateRequest({ body: createPharmacyStorageRoomSchema }),
  authenticate(),
  authorize(INVENTORY_WRITE_SCOPES, 'permission'),
  pharmacyWorkspaceController.createPharmacyStorageRoom
);

router.put(
  '/storage/rooms/:roomId',
  validateRequest({
    params: pharmacyStorageRoomParamsSchema,
    body: updatePharmacyStorageRoomSchema,
  }),
  authenticate(),
  authorize(INVENTORY_WRITE_SCOPES, 'permission'),
  pharmacyWorkspaceController.updatePharmacyStorageRoom
);

router.post(
  '/storage/rooms/:roomId/shelves',
  validateRequest({
    params: pharmacyStorageRoomParamsSchema,
    body: createPharmacyStorageShelfSchema,
  }),
  authenticate(),
  authorize(INVENTORY_WRITE_SCOPES, 'permission'),
  pharmacyWorkspaceController.createPharmacyStorageShelf
);

router.put(
  '/storage/shelves/:shelfId',
  validateRequest({
    params: pharmacyStorageShelfParamsSchema,
    body: updatePharmacyStorageShelfSchema,
  }),
  authenticate(),
  authorize(INVENTORY_WRITE_SCOPES, 'permission'),
  pharmacyWorkspaceController.updatePharmacyStorageShelf
);

module.exports = router;
