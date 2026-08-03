const pharmacyWorkspaceService = require('@services/pharmacy-workspace/pharmacy-workspace.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const getPharmacyWorkbench = asyncHandler(async (req, res) => {
  const {
    panel,
    status,
    location,
    pending_payment,
    payment_cleared,
    today_only,
    partial_stock,
    urgent,
    priority,
    from,
    to,
    patient_id,
    encounter_id,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'} = req.query;

  const data = await pharmacyWorkspaceService.getPharmacyWorkbench(
    {
      panel,
      status,
      location,
      pending_payment,
      payment_cleared,
      today_only,
      partial_stock,
      urgent,
      priority,
      from,
      to,
      patient_id,
      encounter_id,
      search},
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user || {}
  );

  return sendSuccess(res, 200, 'messages.pharmacy_workspace.workbench.success', data);
});

const getPharmacyOrderWorkflow = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.getPharmacyOrderWorkflow(req.params.id, req.user || {});
  return sendSuccess(res, 200, 'messages.pharmacy_workspace.workflow.success', data);
});

const searchDrugs = asyncHandler(async (req, res) => {
  const {
    search,
    name,
    code,
    form,
    strength,
    stock_status,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'asc'} = req.query;

  const data = await pharmacyWorkspaceService.searchDrugs(
    {
      search,
      name,
      code,
      form,
      strength,
      stock_status},
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user || {}
  );

  return sendSuccess(res, 200, 'messages.pharmacy_workspace.drugs.success', data);
});

const createPharmacyOrder = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.createPharmacyOrder(
    req.body,
    req.user?.id,
    req.ip,
    req.user || {}
  );
  return sendSuccess(res, 201, 'messages.pharmacy_workspace.order.create.success', data);
});

const prepareDispense = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.prepareDispense(
    req.params.id,
    req.body,
    req.user?.id,
    req.user?.role,
    req.ip,
    req.user || {}
  );
  return sendSuccess(res, 200, 'messages.pharmacy_workspace.prepare_dispense.success', data);
});

const attestDispense = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.attestDispense(
    req.params.id,
    req.body,
    req.user?.id,
    req.user?.role,
    req.ip,
    req.user || {}
  );
  return sendSuccess(res, 200, 'messages.pharmacy_workspace.attest_dispense.success', data);
});

const cancelPharmacyOrder = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.cancelPharmacyOrder(
    req.params.id,
    req.body,
    req.user?.id,
    req.user?.role,
    req.ip,
    req.user || {}
  );
  return sendSuccess(res, 200, 'messages.pharmacy_workspace.cancel.success', data);
});

const returnDispense = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.returnDispense(
    req.params.id,
    req.body,
    req.user?.id,
    req.user?.role,
    req.ip,
    req.user || {}
  );
  return sendSuccess(res, 200, 'messages.pharmacy_workspace.return.success', data);
});

const recordOrderBilling = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.recordOrderBilling(
    req.params.id,
    req.body,
    req.user?.id,
    req.user?.role,
    req.ip,
    req.user || {}
  );
  return sendSuccess(res, 200, 'messages.pharmacy_workspace.record_billing.success', data);
});

const getInventoryStock = asyncHandler(async (req, res) => {
  const {
    facility_id,
    inventory_item_id,
    low_stock_only,
    stock_status,
    expiring_within_days,
    expired_only,
    storage_room_id,
    storage_shelf_id,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by,
    order = 'desc'} = req.query;

  const data = await pharmacyWorkspaceService.getInventoryStock(
    {
      facility_id,
      inventory_item_id,
      low_stock_only,
      stock_status,
      expiring_within_days,
      expired_only,
      storage_room_id,
      storage_shelf_id,
      search},
    Number(page),
    Number(limit),
    sort_by,
    order,
    req.user || {}
  );

  return sendSuccess(res, 200, 'messages.pharmacy_workspace.inventory.stock.success', data);
});

const adjustInventoryStock = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.adjustInventoryStock(
    req.body,
    req.user?.id,
    req.user?.role,
    req.ip,
    req.user || {}
  );

  return sendSuccess(res, 200, 'messages.pharmacy_workspace.inventory.adjust.success', data);
});

const setupPharmacyDrug = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.setupPharmacyDrug(
    req.body,
    req.user?.id,
    req.ip,
    req.user || {}
  );

  return sendSuccess(res, 201, 'messages.pharmacy_workspace.drug.setup.success', data);
});

const upsertPharmacyDrugFacilityOffering = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.upsertPharmacyDrugFacilityOffering(
    req.params.drugId,
    req.body,
    req.user?.id,
    req.ip,
    req.user || {}
  );
  return sendSuccess(
    res,
    200,
    'messages.pharmacy_workspace.drug.facility_offering.upsert.success',
    data
  );
});

const checkPharmacyDrugSimilarity = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.checkPharmacyDrugSimilarity(
    req.body,
    req.user || {}
  );
  return sendSuccess(
    res,
    200,
    'messages.pharmacy_workspace.drug.similarity.success',
    data
  );
});

const resolveLegacyRoute = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.resolveLegacyRouteIdentifier(
    req.params.resource,
    req.params.id,
    req.user || {}
  );
  return sendSuccess(res, 200, 'messages.pharmacy_workspace.resolve_legacy.success', data);
});

const getPharmacyStorageLayout = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.getPharmacyStorageLayout(
    req.query,
    req.user || {}
  );
  return sendSuccess(res, 200, 'messages.pharmacy_workspace.storage.layout.success', data);
});

const createPharmacyStorageRoom = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.createPharmacyStorageRoom(
    req.body,
    req.user?.id,
    req.ip,
    req.user || {}
  );
  return sendSuccess(res, 201, 'messages.pharmacy_workspace.storage.room.create.success', data);
});

const checkPharmacyStorageRoomSimilarity = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.checkPharmacyStorageRoomSimilarity(
    req.body,
    req.user || {}
  );
  return sendSuccess(
    res,
    200,
    'messages.pharmacy_workspace.storage.room.similarity.success',
    data
  );
});

const updatePharmacyStorageRoom = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.updatePharmacyStorageRoom(
    req.params.roomId,
    req.body,
    req.user?.id,
    req.ip,
    req.user || {}
  );
  return sendSuccess(res, 200, 'messages.pharmacy_workspace.storage.room.update.success', data);
});

const createPharmacyStorageShelf = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.createPharmacyStorageShelf(
    req.params.roomId,
    req.body,
    req.user?.id,
    req.ip,
    req.user || {}
  );
  return sendSuccess(res, 201, 'messages.pharmacy_workspace.storage.shelf.create.success', data);
});

const checkPharmacyStorageShelfSimilarity = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.checkPharmacyStorageShelfSimilarity(
    req.params.roomId,
    req.body,
    req.user || {}
  );
  return sendSuccess(
    res,
    200,
    'messages.pharmacy_workspace.storage.shelf.similarity.success',
    data
  );
});

const updatePharmacyStorageShelf = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.updatePharmacyStorageShelf(
    req.params.shelfId,
    req.body,
    req.user?.id,
    req.ip,
    req.user || {}
  );
  return sendSuccess(res, 200, 'messages.pharmacy_workspace.storage.shelf.update.success', data);
});

const deletePharmacyStorageRoom = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.deletePharmacyStorageRoom(
    req.params.roomId,
    req.user?.id,
    req.ip,
    req.user || {}
  );
  return sendSuccess(res, 200, 'messages.pharmacy_workspace.storage.room.delete.success', data);
});

const restorePharmacyStorageRoom = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.restorePharmacyStorageRoom(
    req.params.roomId,
    req.user?.id,
    req.ip,
    req.user || {}
  );
  return sendSuccess(res, 200, 'messages.pharmacy_workspace.storage.room.restore.success', data);
});

const permanentDeletePharmacyStorageRoom = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.permanentDeletePharmacyStorageRoom(
    req.params.roomId,
    req.user?.id,
    req.ip,
    req.user || {}
  );
  return sendSuccess(
    res,
    200,
    'messages.pharmacy_workspace.storage.room.permanent_delete.success',
    data
  );
});

const deletePharmacyStorageShelf = asyncHandler(async (req, res) => {
  const data = await pharmacyWorkspaceService.deletePharmacyStorageShelf(
    req.params.shelfId,
    req.user?.id,
    req.ip,
    req.user || {}
  );
  return sendSuccess(res, 200, 'messages.pharmacy_workspace.storage.shelf.delete.success', data);
});

module.exports = {
  getPharmacyWorkbench,
  getPharmacyOrderWorkflow,
  searchDrugs,
  createPharmacyOrder,
  prepareDispense,
  attestDispense,
  cancelPharmacyOrder,
  returnDispense,
  recordOrderBilling,
  getInventoryStock,
  adjustInventoryStock,
  setupPharmacyDrug,
  upsertPharmacyDrugFacilityOffering,
  checkPharmacyDrugSimilarity,
  resolveLegacyRoute,
  getPharmacyStorageLayout,
  createPharmacyStorageRoom,
  checkPharmacyStorageRoomSimilarity,
  checkPharmacyStorageShelfSimilarity,
  updatePharmacyStorageRoom,
  createPharmacyStorageShelf,
  updatePharmacyStorageShelf,
  deletePharmacyStorageRoom,
  restorePharmacyStorageRoom,
  permanentDeletePharmacyStorageRoom,
  deletePharmacyStorageShelf};
