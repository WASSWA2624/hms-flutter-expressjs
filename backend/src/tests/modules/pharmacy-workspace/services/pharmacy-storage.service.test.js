jest.mock('@repositories/pharmacy-workspace/pharmacy-storage.repository');
jest.mock('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined)}));

const { HttpError } = require('@lib/errors');
const pharmacyStorageRepository = require('@repositories/pharmacy-workspace/pharmacy-storage.repository');
const pharmacyWorkspaceRepository = require('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
const { createAuditLog } = require('@lib/audit');
const pharmacyStorageService = require('@services/pharmacy-workspace/pharmacy-storage.service');

const user = {
  id: 'actor-1',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  roles: ['PHARMACIST']};

describe('pharmacy-storage.service delete operations', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    pharmacyWorkspaceRepository.withTransaction.mockImplementation((cb) => cb({}));
  });

  describe('deletePharmacyStorageRoom', () => {
    it('soft-deletes the room and cascades its shelves', async () => {
      pharmacyStorageRepository.findStorageRoomById.mockResolvedValue({
        id: 'room-internal-1',
        human_friendly_id: 'ROOM-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        shelves: []});

      const result = await pharmacyStorageService.deletePharmacyStorageRoom(
        'ROOM-1',
        user.id,
        '127.0.0.1',
        user
      );

      expect(pharmacyStorageRepository.txSoftDeleteShelvesForRoom).toHaveBeenCalledWith(
        expect.anything(),
        'room-internal-1'
      );
      expect(pharmacyStorageRepository.txSoftDeleteStorageRoom).toHaveBeenCalledWith(
        expect.anything(),
        'room-internal-1'
      );
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'DELETE', entity: 'pharmacy_storage_room' })
      );
      expect(result).toEqual({ id: 'ROOM-1', deleted: true });
    });

    it('throws when the room does not exist', async () => {
      pharmacyStorageRepository.findStorageRoomById.mockResolvedValue(null);

      await expect(
        pharmacyStorageService.deletePharmacyStorageRoom('missing', user.id, '127.0.0.1', user)
      ).rejects.toBeInstanceOf(HttpError);
      expect(pharmacyStorageRepository.txSoftDeleteStorageRoom).not.toHaveBeenCalled();
    });

    it('throws when the room belongs to another tenant', async () => {
      pharmacyStorageRepository.findStorageRoomById.mockResolvedValue({
        id: 'room-internal-2',
        tenant_id: 'tenant-other',
        facility_id: 'facility-1',
        shelves: []});

      await expect(
        pharmacyStorageService.deletePharmacyStorageRoom('ROOM-2', user.id, '127.0.0.1', user)
      ).rejects.toBeInstanceOf(HttpError);
      expect(pharmacyStorageRepository.txSoftDeleteStorageRoom).not.toHaveBeenCalled();
    });
  });

  describe('deletePharmacyStorageShelf', () => {
    it('soft-deletes the shelf', async () => {
      pharmacyStorageRepository.findStorageShelfById.mockResolvedValue({
        id: 'shelf-internal-1',
        human_friendly_id: 'SHELF-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        storage_room: { id: 'room-internal-1' }});

      const result = await pharmacyStorageService.deletePharmacyStorageShelf(
        'SHELF-1',
        user.id,
        '127.0.0.1',
        user
      );

      expect(pharmacyStorageRepository.txSoftDeleteStorageShelf).toHaveBeenCalledWith(
        expect.anything(),
        'shelf-internal-1'
      );
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({ action: 'DELETE', entity: 'pharmacy_storage_shelf' })
      );
      expect(result).toEqual({ id: 'SHELF-1', deleted: true });
    });

    it('throws when the shelf does not exist', async () => {
      pharmacyStorageRepository.findStorageShelfById.mockResolvedValue(null);

      await expect(
        pharmacyStorageService.deletePharmacyStorageShelf('missing', user.id, '127.0.0.1', user)
      ).rejects.toBeInstanceOf(HttpError);
      expect(pharmacyStorageRepository.txSoftDeleteStorageShelf).not.toHaveBeenCalled();
    });
  });
});

describe('pharmacy-storage.service room uniqueness and lifecycle', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    pharmacyWorkspaceRepository.withTransaction.mockImplementation((cb) => cb({}));
  });

  describe('createPharmacyStorageRoom', () => {
    it('auto-assigns a unique code from HFID when code is omitted', async () => {
      pharmacyStorageRepository.findManyStorageRooms.mockResolvedValue([]);
      pharmacyStorageRepository.txCreateStorageRoom.mockResolvedValue({
        id: 'room-uuid-1',
        human_friendly_id: 'PSR-1001',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        name: 'Main store',
        code: null,
        is_active: true});
      pharmacyStorageRepository.txUpdateStorageRoom.mockResolvedValue({
        id: 'room-uuid-1',
        human_friendly_id: 'PSR-1001',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        name: 'Main store',
        code: 'PSR-1001',
        is_active: true});

      const result = await pharmacyStorageService.createPharmacyStorageRoom(
        {
          name: 'Main store',
          facility_id: 'facility-1',
          confirm_similar: true},
        user.id,
        '127.0.0.1',
        user
      );

      expect(pharmacyStorageRepository.txCreateStorageRoom).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ name: 'Main store', code: null })
      );
      expect(pharmacyStorageRepository.txUpdateStorageRoom).toHaveBeenCalledWith(
        expect.anything(),
        'room-uuid-1',
        { code: 'PSR-1001' }
      );
      expect(result.code).toBe('PSR-1001');
    });

    it('rejects duplicate supplied codes', async () => {
      pharmacyStorageRepository.findManyStorageRooms.mockResolvedValue([]);
      pharmacyStorageRepository.findStorageRoomByCode.mockResolvedValue({
        id: 'existing-room',
        code: 'MAIN'});

      await expect(
        pharmacyStorageService.createPharmacyStorageRoom(
          {
            name: 'Another store',
            code: 'MAIN',
            facility_id: 'facility-1',
            confirm_similar: true},
          user.id,
          '127.0.0.1',
          user
        )
      ).rejects.toBeInstanceOf(HttpError);
      expect(pharmacyStorageRepository.txCreateStorageRoom).not.toHaveBeenCalled();
    });
  });

  describe('checkPharmacyStorageRoomSimilarity', () => {
    it('returns exact name conflict for duplicate names', async () => {
      pharmacyStorageRepository.findManyStorageRooms.mockResolvedValue([
        {
          id: 'room-1',
          human_friendly_id: 'PSR-1',
          name: 'Main store',
          code: 'MAIN',
          is_active: true}]);

      const result = await pharmacyStorageService.checkPharmacyStorageRoomSimilarity(
        { name: 'Main store', facility_id: 'facility-1' },
        user
      );

      expect(result.exact_name_conflict).toBe(true);
      expect(result.matches.length).toBeGreaterThan(0);
    });
  });

  describe('restorePharmacyStorageRoom', () => {
    it('restores a soft-deleted room and its shelves', async () => {
      pharmacyStorageRepository.findStorageRoomById
        .mockResolvedValueOnce({
          id: 'room-internal-1',
          human_friendly_id: 'ROOM-1',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          deleted_at: new Date('2026-01-01T00:00:00.000Z'),
          shelves: []})
        .mockResolvedValueOnce({
          id: 'room-internal-1',
          human_friendly_id: 'ROOM-1',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          deleted_at: null,
          name: 'Main store',
          code: 'MAIN',
          is_active: true,
          shelves: []});
      pharmacyStorageRepository.txRestoreShelvesForRoom.mockResolvedValue({ count: 1 });
      pharmacyStorageRepository.txRestoreStorageRoom.mockResolvedValue({
        id: 'room-internal-1',
        human_friendly_id: 'ROOM-1',
        deleted_at: null});

      const result = await pharmacyStorageService.restorePharmacyStorageRoom(
        'ROOM-1',
        user.id,
        '127.0.0.1',
        user
      );

      expect(pharmacyStorageRepository.txRestoreShelvesForRoom).toHaveBeenCalled();
      expect(pharmacyStorageRepository.txRestoreStorageRoom).toHaveBeenCalledWith(
        expect.anything(),
        'room-internal-1'
      );
      expect(result.id).toBe('ROOM-1');
    });

    it('rejects restore when room is not soft-deleted', async () => {
      pharmacyStorageRepository.findStorageRoomById.mockResolvedValue({
        id: 'room-internal-1',
        human_friendly_id: 'ROOM-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        deleted_at: null,
        shelves: []});

      await expect(
        pharmacyStorageService.restorePharmacyStorageRoom(
          'ROOM-1',
          user.id,
          '127.0.0.1',
          user
        )
      ).rejects.toBeInstanceOf(HttpError);
    });
  });

  describe('permanentDeletePharmacyStorageRoom', () => {
    it('hard-deletes after soft-delete and clears batch FKs', async () => {
      pharmacyStorageRepository.findStorageRoomById.mockResolvedValue({
        id: 'room-internal-1',
        human_friendly_id: 'ROOM-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        deleted_at: new Date('2026-01-01T00:00:00.000Z'),
        shelves: [{ id: 'shelf-1' }]});
      pharmacyStorageRepository.txClearBatchStorageForRoom.mockResolvedValue({ count: 2 });
      pharmacyStorageRepository.txHardDeleteShelvesForRoom.mockResolvedValue({ count: 1 });
      pharmacyStorageRepository.txHardDeleteStorageRoom.mockResolvedValue({
        id: 'room-internal-1'});

      const result = await pharmacyStorageService.permanentDeletePharmacyStorageRoom(
        'ROOM-1',
        user.id,
        '127.0.0.1',
        user
      );

      expect(pharmacyStorageRepository.txClearBatchStorageForRoom).toHaveBeenCalledWith(
        expect.anything(),
        'room-internal-1'
      );
      expect(pharmacyStorageRepository.txHardDeleteShelvesForRoom).toHaveBeenCalledWith(
        expect.anything(),
        'room-internal-1'
      );
      expect(pharmacyStorageRepository.txHardDeleteStorageRoom).toHaveBeenCalledWith(
        expect.anything(),
        'room-internal-1'
      );
      expect(result).toEqual({ id: 'ROOM-1', permanently_deleted: true });
    });

    it('rejects permanent delete when room is not soft-deleted', async () => {
      pharmacyStorageRepository.findStorageRoomById.mockResolvedValue({
        id: 'room-internal-1',
        human_friendly_id: 'ROOM-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        deleted_at: null,
        shelves: []});

      await expect(
        pharmacyStorageService.permanentDeletePharmacyStorageRoom(
          'ROOM-1',
          user.id,
          '127.0.0.1',
          user
        )
      ).rejects.toBeInstanceOf(HttpError);
      expect(pharmacyStorageRepository.txHardDeleteStorageRoom).not.toHaveBeenCalled();
    });
  });
});

describe('pharmacy-storage.service shelf similarity and create', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    pharmacyWorkspaceRepository.withTransaction.mockImplementation((cb) => cb({}));
  });

  it('checks shelf similarity only within the room', async () => {
    pharmacyStorageRepository.findStorageRoomById.mockResolvedValue({
      id: 'room-internal-1',
      human_friendly_id: 'ROOM-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1'});
    pharmacyStorageRepository.findManyStorageShelves.mockResolvedValue([
      {
        id: 'shelf-1',
        human_friendly_id: 'SHELF-1',
        storage_room_id: 'room-internal-1',
        shelf_code: 'A1',
        label: 'Antibiotics'},
      {
        id: 'shelf-2',
        human_friendly_id: 'SHELF-2',
        storage_room_id: 'room-internal-1',
        shelf_code: 'B2',
        label: 'Bandages'}]);

    const result = await pharmacyStorageService.checkPharmacyStorageShelfSimilarity(
      'ROOM-1',
      { label: 'Antibiotic', shelf_code: 'A2' },
      user
    );

    expect(pharmacyStorageRepository.findManyStorageShelves).toHaveBeenCalledWith(
      'room-internal-1',
      expect.any(Object),
      0,
      expect.any(Number)
    );
    expect(result.matches.length).toBeGreaterThan(0);
    expect(result.exact_label_conflict).toBe(false);
  });

  it('creates a shelf with blank code using generated friendly id', async () => {
    pharmacyStorageRepository.findStorageRoomById.mockResolvedValue({
      id: 'room-internal-1',
      human_friendly_id: 'ROOM-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1'});
    pharmacyStorageRepository.findManyStorageShelves.mockResolvedValue([]);
    pharmacyStorageRepository.txCreateStorageShelf.mockResolvedValue({
      id: 'shelf-internal-1',
      human_friendly_id: 'PSS-1001',
      storage_room_id: 'room-internal-1',
      shelf_code: 'TMP-abc',
      label: 'Vaccines',
      is_active: true,
      tenant_id: 'tenant-1',
      facility_id: 'facility-1'});
    pharmacyStorageRepository.txUpdateStorageShelf.mockResolvedValue({
      id: 'shelf-internal-1',
      human_friendly_id: 'PSS-1001',
      storage_room_id: 'room-internal-1',
      shelf_code: 'PSS-1001',
      label: 'Vaccines',
      is_active: true,
      tenant_id: 'tenant-1',
      facility_id: 'facility-1'});

    const created = await pharmacyStorageService.createPharmacyStorageShelf(
      'ROOM-1',
      { label: 'Vaccines', confirm_similar: true },
      user.id,
      '127.0.0.1',
      user
    );

    expect(pharmacyStorageRepository.txCreateStorageShelf).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        label: 'Vaccines',
        shelf_code: expect.stringMatching(/^TMP-/),
        storage_room_id: 'room-internal-1'})
    );
    expect(pharmacyStorageRepository.txUpdateStorageShelf).toHaveBeenCalledWith(
      expect.anything(),
      'shelf-internal-1',
      expect.objectContaining({ shelf_code: 'PSS-1001' })
    );
    expect(created.shelf_code).toBe('PSS-1001');
  });

  it('rejects similar shelves without confirm_similar', async () => {
    pharmacyStorageRepository.findStorageRoomById.mockResolvedValue({
      id: 'room-internal-1',
      human_friendly_id: 'ROOM-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1'});
    pharmacyStorageRepository.findManyStorageShelves.mockResolvedValue([
      {
        id: 'shelf-1',
        human_friendly_id: 'SHELF-1',
        storage_room_id: 'room-internal-1',
        shelf_code: 'A1',
        label: 'Antibiotics'}]);

    await expect(
      pharmacyStorageService.createPharmacyStorageShelf(
        'ROOM-1',
        { label: 'Antibiotic', shelf_code: 'A9' },
        user.id,
        '127.0.0.1',
        user
      )
    ).rejects.toMatchObject({
      message: 'errors.pharmacy_storage_shelf.similar_exists'});
  });

  it('excludes self when checking uniqueness on update', async () => {
    pharmacyStorageRepository.findStorageShelfById.mockResolvedValue({
      id: 'shelf-1',
      human_friendly_id: 'SHELF-1',
      storage_room_id: 'room-internal-1',
      shelf_code: 'A1',
      label: 'Antibiotics',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      storage_room: {
        id: 'room-internal-1',
        human_friendly_id: 'ROOM-1'}});
    pharmacyStorageRepository.findManyStorageShelves.mockResolvedValue([
      {
        id: 'shelf-1',
        human_friendly_id: 'SHELF-1',
        storage_room_id: 'room-internal-1',
        shelf_code: 'A1',
        label: 'Antibiotics'}]);
    pharmacyStorageRepository.findStorageShelfByCode.mockResolvedValue(null);
    pharmacyStorageRepository.txUpdateStorageShelf.mockResolvedValue({
      id: 'shelf-1',
      human_friendly_id: 'SHELF-1',
      storage_room_id: 'room-internal-1',
      shelf_code: 'A1',
      label: 'Antibiotics Updated',
      is_active: true,
      tenant_id: 'tenant-1',
      facility_id: 'facility-1'});

    const updated = await pharmacyStorageService.updatePharmacyStorageShelf(
      'SHELF-1',
      { label: 'Antibiotics Updated', confirm_similar: true },
      user.id,
      '127.0.0.1',
      user
    );

    expect(updated.label).toBe('Antibiotics Updated');
  });
});
