jest.mock('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn()}));
jest.mock('@lib/websocket', () => ({
  emitToUsers: jest.fn(),
  PHARMACY_EVENTS: { PHARMACY_CATALOG_UPDATED: 'pharmacy.catalog_updated' },
  INVENTORY_EVENTS: { INVENTORY_STOCK_UPDATED: 'inventory.stock_updated' }}));
jest.mock('@lib/realtime/recipients', () => ({
  findRealtimeRecipientUserIds: jest.fn()}));
jest.mock('@lib/facility-context', () => ({
  resolveOperationalFacilityId: jest.fn()}));
jest.mock('@lib/billing/pricing-permissions', () => ({
  hasPermission: jest.fn()}));
jest.mock('@prisma/client', () => ({}));

const pharmacyWorkspaceRepository = require('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
const { createAuditLog } = require('@lib/audit');
const { emitToUsers } = require('@lib/websocket');
const { findRealtimeRecipientUserIds } = require('@lib/realtime/recipients');
const { resolveOperationalFacilityId } = require('@lib/facility-context');
const { hasPermission } = require('@lib/billing/pricing-permissions');
const medicErpSource = require('@lib/pharmacy/drug-import/sources/medic-erp.source');
const pharmacyDrugImportService = require('@services/pharmacy-workspace/pharmacy-drug-import.service');
const {
  buildMedicErpRow,
  buildMedicErpWorkbookBuffer} = require('../../../lib/pharmacy/drug-import/medic-erp-workbook.fixture');

const tx = { tx: true };
const user = {
  id: 'user-internal-1',
  tenant_id: 'tenant-internal-1',
  facility_id: 'facility-internal-1',
  roles: ['PHARMACIST']};
const facility = {
  id: 'facility-internal-1',
  human_friendly_id: 'FAC0000001',
  name: 'Fairbanks Medical Centre'};

const buildFile = async (rows, options) => ({
  originalname: 'stock.xlsx',
  buffer: await buildMedicErpWorkbookBuffer(rows, options)});

const existingDrugRecord = (overrides = {}) => ({
  id: 'drug-internal-existing',
  human_friendly_id: 'DRG0000050',
  name: 'AZITHROMYCIN 500MG TABLET',
  generic_name: 'AZITHROMYCIN 500MG TABLET',
  brand_name: 'ZAHA',
  code: null,
  form: 'Tablet',
  strength: '500 mg',
  buy_unit_price: '4300.00',
  unit_price: '6000.00',
  currency: 'UGX',
  supplier_id: null,
  supplier: null,
  inventory_maps: [
    {
      inventory_item_id: 'item-internal-existing',
      inventory_item: { stocks: [{ quantity: 10 }] }}],
  ...overrides});

const preview = (file) =>
  pharmacyDrugImportService.previewDrugImport({
    file,
    payload: { source: 'MEDIC_ERP' },
    user});

const commit = (file, payload) =>
  pharmacyDrugImportService.commitDrugImport({
    file,
    payload: { source: 'MEDIC_ERP', decisions: [], ...payload },
    userId: 'user-internal-1',
    ipAddress: '127.0.0.1',
    user});

const flushRealtime = () => new Promise((resolve) => setImmediate(resolve));

describe('pharmacy drug import service', () => {
  let sequence;

  beforeEach(() => {
    jest.clearAllMocks();
    sequence = 0;
    hasPermission.mockReturnValue(true);
    resolveOperationalFacilityId.mockResolvedValue(null);
    findRealtimeRecipientUserIds.mockResolvedValue(['user-internal-1']);
    createAuditLog.mockResolvedValue();

    pharmacyWorkspaceRepository.findFacilityForImport.mockResolvedValue(facility);
    pharmacyWorkspaceRepository.findDrugsForImport.mockResolvedValue([]);
    pharmacyWorkspaceRepository.findSuppliersForImport.mockResolvedValue([]);
    pharmacyWorkspaceRepository.withTransaction.mockImplementation(async (callback) => callback(tx));
    pharmacyWorkspaceRepository.txCreateDrug.mockImplementation(async (_tx, data) => {
      sequence += 1;
      return { id: `drug-internal-${sequence}`, human_friendly_id: `DRG000000${sequence}`, ...data };
    });
    pharmacyWorkspaceRepository.txCreateInventoryItem.mockImplementation(async (_tx, data) => ({
      id: `item-internal-${sequence}`,
      ...data}));
    pharmacyWorkspaceRepository.txCreateDrugInventoryMap.mockResolvedValue({});
    pharmacyWorkspaceRepository.txFindInventoryMapByDrug.mockResolvedValue(null);
    pharmacyWorkspaceRepository.txFindStockByInventoryItemAndFacility.mockResolvedValue(null);
    pharmacyWorkspaceRepository.txCreateInventoryStock.mockResolvedValue({});
    pharmacyWorkspaceRepository.txUpdateInventoryStock.mockResolvedValue({});
    pharmacyWorkspaceRepository.txCreateStockMovement.mockResolvedValue({});
    pharmacyWorkspaceRepository.txFindDrugBatchByDrugAndNumber.mockResolvedValue(null);
    pharmacyWorkspaceRepository.txFindDrugBatchesByDrug.mockResolvedValue([]);
    pharmacyWorkspaceRepository.txCreateDrugBatch.mockResolvedValue({});
    pharmacyWorkspaceRepository.txUpdateDrugBatch.mockResolvedValue({});
    pharmacyWorkspaceRepository.txUpdateDrug.mockImplementation(async (_tx, id, data) => ({
      id,
      human_friendly_id: 'DRG0000050',
      ...data}));
    pharmacyWorkspaceRepository.txCreateSupplier.mockImplementation(async (_tx, data) => ({
      id: 'supplier-internal-1',
      ...data}));
  });

  describe('previewDrugImport', () => {
    it('returns a reviewable plan for the current facility using public ids only', async () => {
      pharmacyWorkspaceRepository.findDrugsForImport.mockResolvedValue([existingDrugRecord()]);
      const file = await buildFile([
        buildMedicErpRow(),
        buildMedicErpRow({ product_brand: 'SWAZI', batch_number: 'BG10425' })]);

      const result = await preview(file);

      expect(pharmacyWorkspaceRepository.findDrugsForImport).toHaveBeenCalledWith(
        'tenant-internal-1',
        'facility-internal-1'
      );
      expect(result).toMatchObject({
        source: 'MEDIC_ERP',
        source_label: 'Medic-ERP',
        file_name: 'stock.xlsx',
        sheet_name: 'Stock',
        facility: { id: 'FAC0000001', name: 'Fairbanks Medical Centre' },
        template: { is_valid: true, missing_columns: [] },
        can_commit: true,
        can_write_pricing: true,
        summary: { products: 2, existing_products: 1, similar_products: 1 }});
      expect(result.plan_hash).toMatch(/^[a-f0-9]{64}$/);

      const existing = result.products.find((product) => product.status === 'EXISTING');
      expect(existing.match.drug).toMatchObject({ id: 'DRG0000050', facility_quantity: 10 });
      const similar = result.products.find((product) => product.status === 'SIMILAR');
      expect(similar).toMatchObject({ default_action: 'CREATE', requires_review: true });
      expect(JSON.stringify(result)).not.toContain('-internal-');
    });

    it('reports template gaps without loading the catalog', async () => {
      const columns = medicErpSource.columns.filter((column) => column !== 'cost');
      const file = await buildFile([buildMedicErpRow()], { columns });

      const result = await preview(file);

      expect(result).toMatchObject({
        template: { is_valid: false, missing_columns: ['cost'] },
        can_commit: false,
        plan_hash: null,
        products: []});
      expect(pharmacyWorkspaceRepository.findDrugsForImport).not.toHaveBeenCalled();
    });

    it('rejects non-xlsx uploads and users without a facility', async () => {
      const file = await buildFile([buildMedicErpRow()]);

      await expect(preview({ ...file, originalname: 'stock.csv' })).rejects.toMatchObject({
        message: 'errors.pharmacy_drug_import.invalid_file',
        statusCode: 400});
      await expect(
        pharmacyDrugImportService.previewDrugImport({
          file,
          payload: { source: 'MEDIC_ERP' },
          user: { ...user, facility_id: null }})
      ).rejects.toMatchObject({
        message: 'errors.pharmacy_drug_import.facility_required',
        statusCode: 400});
    });
  });

  describe('commitDrugImport', () => {
    it('refuses a plan hash that no longer matches the file and catalog', async () => {
      const file = await buildFile([buildMedicErpRow()]);

      await expect(commit(file, { plan_hash: 'a'.repeat(64) })).rejects.toMatchObject({
        message: 'errors.pharmacy_drug_import.stale_preview',
        statusCode: 409});
      expect(pharmacyWorkspaceRepository.withTransaction).not.toHaveBeenCalled();
    });

    it('creates new products with stock and batches in the current facility', async () => {
      const file = await buildFile([
        buildMedicErpRow(),
        buildMedicErpRow({
          batch_number: 'PAD31015',
          available_quantity: 5,
          updated_on: '2026-07-11T00:00:00.000Z'})]);
      const { plan_hash: planHash } = await preview(file);

      const result = await commit(file, { plan_hash: planHash, currency: 'ugx' });

      expect(pharmacyWorkspaceRepository.withTransaction).toHaveBeenCalledWith(
        expect.any(Function),
        expect.objectContaining({ timeout: expect.any(Number) })
      );
      expect(pharmacyWorkspaceRepository.txCreateDrug).toHaveBeenCalledWith(
        tx,
        expect.objectContaining({
          tenant_id: 'tenant-internal-1',
          name: 'AZITHROMYCIN 500MG TABLET',
          brand_name: 'ZAHA',
          form: 'Tablet',
          strength: '500 mg',
          unit_price: 7000,
          buy_unit_price: 4300,
          currency: 'UGX'})
      );
      expect(pharmacyWorkspaceRepository.txCreateInventoryStock).toHaveBeenCalledWith(tx, {
        inventory_item_id: 'item-internal-1',
        facility_id: 'facility-internal-1',
        quantity: 9,
        reorder_level: 0});
      expect(pharmacyWorkspaceRepository.txCreateStockMovement).toHaveBeenCalledWith(
        tx,
        expect.objectContaining({
          facility_id: 'facility-internal-1',
          movement_type: 'INBOUND',
          reason: 'PURCHASE',
          quantity: 9})
      );
      expect(pharmacyWorkspaceRepository.txCreateDrugBatch).toHaveBeenCalledTimes(2);
      expect(pharmacyWorkspaceRepository.txFindDrugBatchByDrugAndNumber).not.toHaveBeenCalled();
      expect(result).toMatchObject({
        facility: { id: 'FAC0000001' },
        stock_mode: 'REPLACE',
        summary: {
          created: 1,
          batches_created: 2,
          stock_rows_created: 1,
          quantity_imported: 9}});

      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          entity: 'drug_import',
          entity_id: result.import_id,
          diff: {
            metadata: expect.objectContaining({ created_drug_ids: ['DRG0000001'] })}})
      );
      await flushRealtime();
      expect(emitToUsers).toHaveBeenCalledWith(
        ['user-internal-1'],
        'pharmacy.catalog_updated',
        expect.objectContaining({ action: 'IMPORT', facility_id: 'facility-internal-1' })
      );
    });

    it('replaces facility stock for linked drugs and clears stale facility batches', async () => {
      pharmacyWorkspaceRepository.findDrugsForImport.mockResolvedValue([existingDrugRecord()]);
      pharmacyWorkspaceRepository.txFindInventoryMapByDrug.mockResolvedValue({
        inventory_item_id: 'item-internal-existing'});
      pharmacyWorkspaceRepository.txFindStockByInventoryItemAndFacility.mockResolvedValue({
        id: 'stock-internal-1',
        quantity: 10});
      pharmacyWorkspaceRepository.txFindDrugBatchByDrugAndNumber.mockResolvedValue({
        id: 'batch-internal-1',
        batch_number: 'PA09025',
        quantity: 7,
        expiry_date: new Date('2028-05-31T00:00:00.000Z')});
      pharmacyWorkspaceRepository.txFindDrugBatchesByDrug.mockResolvedValue([
        { id: 'batch-internal-1', batch_number: 'PA09025', quantity: 4, storage_room: null },
        {
          id: 'batch-internal-stale',
          batch_number: 'OLD1',
          quantity: 6,
          storage_room: { facility_id: 'facility-internal-1' }},
        {
          id: 'batch-internal-other',
          batch_number: 'OTHER',
          quantity: 2,
          storage_room: { facility_id: 'facility-internal-2' }}]);
      const file = await buildFile([buildMedicErpRow()]);
      const plan = await preview(file);

      const result = await commit(file, {
        plan_hash: plan.plan_hash,
        decisions: [{ key: plan.products[0].key, action: 'UPDATE' }]});

      expect(pharmacyWorkspaceRepository.txCreateDrug).not.toHaveBeenCalled();
      expect(pharmacyWorkspaceRepository.txUpdateDrug).toHaveBeenCalledWith(
        tx,
        'drug-internal-existing',
        { unit_price: 7000 }
      );
      expect(pharmacyWorkspaceRepository.txUpdateInventoryStock).toHaveBeenCalledWith(
        tx,
        'stock-internal-1',
        { quantity: 4 }
      );
      expect(pharmacyWorkspaceRepository.txCreateStockMovement).toHaveBeenCalledWith(
        tx,
        expect.objectContaining({ movement_type: 'ADJUSTMENT', reason: 'OTHER', quantity: 6 })
      );
      expect(pharmacyWorkspaceRepository.txUpdateDrugBatch).toHaveBeenCalledWith(
        tx,
        'batch-internal-1',
        { quantity: 4 }
      );
      expect(pharmacyWorkspaceRepository.txUpdateDrugBatch).toHaveBeenCalledWith(
        tx,
        'batch-internal-stale',
        { quantity: 0 }
      );
      expect(pharmacyWorkspaceRepository.txUpdateDrugBatch).not.toHaveBeenCalledWith(
        tx,
        'batch-internal-other',
        expect.anything()
      );
      expect(result.summary).toMatchObject({
        updated: 1,
        batches_updated: 1,
        batches_cleared: 1,
        stock_rows_adjusted: 1});
    });

    it('adds file quantities on top of current stock in ADD mode', async () => {
      pharmacyWorkspaceRepository.findDrugsForImport.mockResolvedValue([existingDrugRecord()]);
      pharmacyWorkspaceRepository.txFindInventoryMapByDrug.mockResolvedValue({
        inventory_item_id: 'item-internal-existing'});
      pharmacyWorkspaceRepository.txFindStockByInventoryItemAndFacility.mockResolvedValue({
        id: 'stock-internal-1',
        quantity: 10});
      pharmacyWorkspaceRepository.txFindDrugBatchByDrugAndNumber.mockResolvedValue({
        id: 'batch-internal-1',
        batch_number: 'PA09025',
        quantity: 7,
        expiry_date: new Date('2028-05-31T00:00:00.000Z')});
      const file = await buildFile([buildMedicErpRow()]);
      const { plan_hash: planHash } = await preview(file);

      const result = await commit(file, { plan_hash: planHash, stock_mode: 'ADD' });

      expect(pharmacyWorkspaceRepository.txUpdateDrug).not.toHaveBeenCalled();
      expect(pharmacyWorkspaceRepository.txUpdateInventoryStock).toHaveBeenCalledWith(
        tx,
        'stock-internal-1',
        { quantity: 14 }
      );
      expect(pharmacyWorkspaceRepository.txCreateStockMovement).toHaveBeenCalledWith(
        tx,
        expect.objectContaining({ movement_type: 'INBOUND', reason: 'PURCHASE', quantity: 4 })
      );
      expect(pharmacyWorkspaceRepository.txUpdateDrugBatch).toHaveBeenCalledWith(
        tx,
        'batch-internal-1',
        { quantity: 11 }
      );
      expect(pharmacyWorkspaceRepository.txFindDrugBatchesByDrug).not.toHaveBeenCalled();
      expect(result).toMatchObject({ stock_mode: 'ADD', summary: { merged: 1 } });
    });

    it('requires review confirmation when products resemble catalog drugs', async () => {
      pharmacyWorkspaceRepository.findDrugsForImport.mockResolvedValue([existingDrugRecord()]);
      const file = await buildFile([buildMedicErpRow({ product_brand: 'SWAZI' })]);
      const { plan_hash: planHash } = await preview(file);

      await expect(commit(file, { plan_hash: planHash })).rejects.toMatchObject({
        message: 'errors.pharmacy_drug_import.review_required',
        statusCode: 400});

      await expect(
        commit(file, { plan_hash: planHash, confirm_review: true })
      ).resolves.toMatchObject({ summary: { created: 1 } });
    });

    it('clears stock for drugs missing from the file only when replacing stock', async () => {
      pharmacyWorkspaceRepository.findDrugsForImport.mockResolvedValue([
        existingDrugRecord({
          id: 'drug-internal-old',
          human_friendly_id: 'DRG0000077',
          name: 'OLD SYRUP',
          generic_name: 'OLD SYRUP',
          brand_name: null,
          form: 'Syrup',
          strength: null,
          inventory_maps: [
            { inventory_item_id: 'item-internal-old', inventory_item: { stocks: [{ quantity: 9 }] } }]})]);
      pharmacyWorkspaceRepository.txFindStockByInventoryItemAndFacility.mockImplementation(
        async (_tx, inventoryItemId) =>
          inventoryItemId === 'item-internal-old' ? { id: 'stock-internal-old', quantity: 9 } : null
      );
      const file = await buildFile([buildMedicErpRow()]);
      const plan = await preview(file);
      expect(plan.stocked_drugs.map((drug) => drug.id)).toEqual(['DRG0000077']);

      await expect(
        commit(file, { plan_hash: plan.plan_hash, stock_mode: 'ADD', clear_missing_stock: true })
      ).rejects.toMatchObject({
        message: 'errors.pharmacy_drug_import.clear_missing_requires_replace'});

      const result = await commit(file, { plan_hash: plan.plan_hash, clear_missing_stock: true });

      expect(pharmacyWorkspaceRepository.txUpdateInventoryStock).toHaveBeenCalledWith(
        tx,
        'stock-internal-old',
        { quantity: 0 }
      );
      expect(pharmacyWorkspaceRepository.txCreateStockMovement).toHaveBeenCalledWith(
        tx,
        expect.objectContaining({
          inventory_item_id: 'item-internal-old',
          movement_type: 'ADJUSTMENT',
          quantity: 9})
      );
      expect(result.summary).toMatchObject({ created: 1, stock_cleared: 1 });
    });

    it('skips prices without pricing permission and reuses matching suppliers', async () => {
      hasPermission.mockReturnValue(false);
      pharmacyWorkspaceRepository.findSuppliersForImport.mockResolvedValue([
        { id: 'supplier-internal-9', name: 'Kampala Pharma Ltd' }]);
      const file = await buildFile([
        buildMedicErpRow({ supplier: 'KAMPALA PHARMA LTD' }),
        buildMedicErpRow({ product_brand: 'SWAZI', batch_number: 'B2', supplier: 'Nile Distributors' })]);
      const { plan_hash: planHash } = await preview(file);

      await commit(file, { plan_hash: planHash, currency: 'UGX' });

      const createdDrugs = pharmacyWorkspaceRepository.txCreateDrug.mock.calls.map((call) => call[1]);
      createdDrugs.forEach((data) => {
        expect(data).not.toHaveProperty('unit_price');
        expect(data).not.toHaveProperty('buy_unit_price');
        expect(data).not.toHaveProperty('currency');
      });
      expect(createdDrugs.map((data) => data.supplier_id)).toEqual(
        expect.arrayContaining(['supplier-internal-9', 'supplier-internal-1'])
      );
      expect(pharmacyWorkspaceRepository.txCreateSupplier).toHaveBeenCalledTimes(1);
      expect(pharmacyWorkspaceRepository.txCreateSupplier).toHaveBeenCalledWith(tx, {
        tenant_id: 'tenant-internal-1',
        name: 'Nile Distributors'});
    });

    it('refuses to commit when every product is skipped', async () => {
      const file = await buildFile([buildMedicErpRow()]);
      const plan = await preview(file);

      await expect(
        commit(file, {
          plan_hash: plan.plan_hash,
          decisions: [{ key: plan.products[0].key, action: 'SKIP' }]})
      ).rejects.toMatchObject({ message: 'errors.pharmacy_drug_import.nothing_to_import' });
    });

    it('saves reviewer-edited values for new drugs and their batches', async () => {
      const file = await buildFile([buildMedicErpRow()]);
      const plan = await preview(file);
      const [product] = plan.products;
      expect(product.batches[0].key).toBe('PA09025');

      const result = await commit(file, {
        plan_hash: plan.plan_hash,
        decisions: [
          {
            key: product.key,
            action: 'CREATE',
            values: {
              name: 'Azithromycin 500 mg Tablet',
              unit_price: 7500,
              supplier_name: 'Nile Distributors'},
            batches: [
              { key: 'PA09025', batch_number: 'PA-09025', expiry_date: '2029-06-30', quantity: 6 }]}]});

      expect(pharmacyWorkspaceRepository.txCreateDrug).toHaveBeenCalledWith(
        tx,
        expect.objectContaining({
          name: 'Azithromycin 500 mg Tablet',
          generic_name: 'Azithromycin 500 mg Tablet',
          brand_name: 'ZAHA',
          unit_price: 7500,
          buy_unit_price: 4300,
          supplier_id: 'supplier-internal-1'})
      );
      expect(pharmacyWorkspaceRepository.txCreateDrugBatch).toHaveBeenCalledWith(tx, {
        drug_id: 'drug-internal-1',
        batch_number: 'PA-09025',
        expiry_date: new Date('2029-06-30T00:00:00.000Z'),
        quantity: 6});
      expect(result.summary).toMatchObject({ created: 1, quantity_imported: 6 });
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          diff: { metadata: expect.objectContaining({ edited_product_keys: [product.key] }) }})
      );
    });

    it('keeps catalog values the reviewer chose over the file when updating', async () => {
      pharmacyWorkspaceRepository.findDrugsForImport.mockResolvedValue([existingDrugRecord()]);
      pharmacyWorkspaceRepository.txFindInventoryMapByDrug.mockResolvedValue({
        inventory_item_id: 'item-internal-existing'});
      const file = await buildFile([buildMedicErpRow()]);
      const plan = await preview(file);

      await commit(file, {
        plan_hash: plan.plan_hash,
        decisions: [
          {
            key: plan.products[0].key,
            action: 'UPDATE',
            values: { unit_price: 6000, strength: '250 mg' }}]});

      expect(pharmacyWorkspaceRepository.txUpdateDrug).toHaveBeenCalledWith(
        tx,
        'drug-internal-existing',
        { strength: '250 mg' }
      );
    });

    it('rejects a renamed new product that duplicates a catalog drug', async () => {
      pharmacyWorkspaceRepository.findDrugsForImport.mockResolvedValue([existingDrugRecord()]);
      const file = await buildFile([buildMedicErpRow({ product_brand: 'SWAZI' })]);
      const plan = await preview(file);

      await expect(
        commit(file, {
          plan_hash: plan.plan_hash,
          confirm_review: true,
          decisions: [
            { key: plan.products[0].key, action: 'CREATE', values: { brand_name: 'Zaha' } }]})
      ).rejects.toMatchObject({
        message: 'errors.pharmacy_drug_import.duplicate_product',
        statusCode: 400});
      expect(pharmacyWorkspaceRepository.withTransaction).not.toHaveBeenCalled();
    });
  });
});
