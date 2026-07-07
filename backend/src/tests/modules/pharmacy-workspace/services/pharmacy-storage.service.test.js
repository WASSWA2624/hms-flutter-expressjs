jest.mock('@repositories/pharmacy-workspace/pharmacy-storage.repository');
jest.mock('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue(undefined),
}));

const { HttpError } = require('@lib/errors');
const pharmacyStorageRepository = require('@repositories/pharmacy-workspace/pharmacy-storage.repository');
const pharmacyWorkspaceRepository = require('@repositories/pharmacy-workspace/pharmacy-workspace.repository');
const { createAuditLog } = require('@lib/audit');
const pharmacyStorageService = require('@services/pharmacy-workspace/pharmacy-storage.service');

const user = {
  id: 'actor-1',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  roles: ['PHARMACIST'],
};

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
        shelves: [],
      });

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
        shelves: [],
      });

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
        storage_room: { id: 'room-internal-1' },
      });

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
