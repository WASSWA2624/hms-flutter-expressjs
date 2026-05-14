/**
 * Bed service tests
 *
 * @module tests/modules/bed/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/bed/bed.repository');
jest.mock('@lib/audit');

const bedRepository = require('@repositories/bed/bed.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listBeds,
  getBedById,
  createBed,
  updateBed,
  deleteBed
} = require('@services/bed/bed.service');

describe('Bed Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listBeds', () => {
    it('should list beds with default pagination', async () => {
      const mockBeds = [
        { id: 'bed-1', label: 'Bed 101', tenant_id: 'tenant-123', status: 'AVAILABLE' },
        { id: 'bed-2', label: 'Bed 102', tenant_id: 'tenant-123', status: 'OCCUPIED' }
      ];
      bedRepository.findMany.mockResolvedValue(mockBeds);
      bedRepository.count.mockResolvedValue(10);

      const result = await listBeds({}, 1, 20);

      expect(result.beds).toEqual(mockBeds);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
      expect(bedRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by tenant_id', async () => {
      const mockBeds = [{ id: 'bed-1', label: 'Bed 101', status: 'AVAILABLE' }];
      bedRepository.findMany.mockResolvedValue(mockBeds);
      bedRepository.count.mockResolvedValue(1);

      const result = await listBeds({ tenant_id: 'tenant-123' }, 1, 20);

      expect(result.beds).toEqual(mockBeds);
      expect(bedRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by facility_id', async () => {
      const mockBeds = [{ id: 'bed-1', label: 'Bed 101', status: 'AVAILABLE' }];
      bedRepository.findMany.mockResolvedValue(mockBeds);
      bedRepository.count.mockResolvedValue(1);

      const result = await listBeds({ facility_id: 'facility-123' }, 1, 20);

      expect(result.beds).toEqual(mockBeds);
      expect(bedRepository.findMany).toHaveBeenCalledWith(
        { facility_id: 'facility-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by ward_id', async () => {
      const mockBeds = [{ id: 'bed-1', label: 'Bed 101', status: 'AVAILABLE' }];
      bedRepository.findMany.mockResolvedValue(mockBeds);
      bedRepository.count.mockResolvedValue(1);

      const result = await listBeds({ ward_id: 'ward-123' }, 1, 20);

      expect(result.beds).toEqual(mockBeds);
      expect(bedRepository.findMany).toHaveBeenCalledWith(
        { ward_id: 'ward-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by room_id', async () => {
      const mockBeds = [{ id: 'bed-1', label: 'Bed 101', status: 'AVAILABLE' }];
      bedRepository.findMany.mockResolvedValue(mockBeds);
      bedRepository.count.mockResolvedValue(1);

      const result = await listBeds({ room_id: 'room-123' }, 1, 20);

      expect(result.beds).toEqual(mockBeds);
      expect(bedRepository.findMany).toHaveBeenCalledWith(
        { room_id: 'room-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by status', async () => {
      const mockBeds = [{ id: 'bed-1', label: 'Bed 101', status: 'AVAILABLE' }];
      bedRepository.findMany.mockResolvedValue(mockBeds);
      bedRepository.count.mockResolvedValue(1);

      const result = await listBeds({ status: 'AVAILABLE' }, 1, 20);

      expect(result.beds).toEqual(mockBeds);
      expect(bedRepository.findMany).toHaveBeenCalledWith(
        { status: 'AVAILABLE' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle search filter', async () => {
      const mockBeds = [{ id: 'bed-1', label: 'Bed 101', status: 'AVAILABLE' }];
      bedRepository.findMany.mockResolvedValue(mockBeds);
      bedRepository.count.mockResolvedValue(1);

      const result = await listBeds({ search: 'bed' }, 1, 20);

      expect(result.beds).toEqual(mockBeds);
      expect(bedRepository.findMany).toHaveBeenCalledWith(
        { label: { contains: 'bed', mode: 'insensitive' } },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should calculate pagination correctly', async () => {
      const mockBeds = Array(20).fill().map((_, i) => ({ 
        id: `bed-${i}`, 
        label: `Bed ${i}`,
        status: 'AVAILABLE'
      }));
      bedRepository.findMany.mockResolvedValue(mockBeds);
      bedRepository.count.mockResolvedValue(100);

      const result = await listBeds({}, 3, 20);

      expect(result.pagination).toEqual({
        page: 3,
        limit: 20,
        total: 100,
        totalPages: 5,
        hasNextPage: true,
        hasPreviousPage: true
      });
      expect(bedRepository.findMany).toHaveBeenCalledWith(
        {},
        40,
        20,
        { created_at: 'desc' }
      );
    });

    it('should support custom sort order', async () => {
      const mockBeds = [];
      bedRepository.findMany.mockResolvedValue(mockBeds);
      bedRepository.count.mockResolvedValue(0);

      await listBeds({}, 1, 20, 'label', 'asc');

      expect(bedRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { label: 'asc' }
      );
    });

    it('should return empty result when no beds found', async () => {
      bedRepository.findMany.mockResolvedValue([]);
      bedRepository.count.mockResolvedValue(0);

      const result = await listBeds({}, 1, 20);

      expect(result.beds).toEqual([]);
      expect(result.pagination.total).toBe(0);
    });
  });

  describe('getBedById', () => {
    it('should get bed by ID', async () => {
      const mockBed = {
        id: 'bed-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: 'room-123',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      bedRepository.findById.mockResolvedValue(mockBed);

      const result = await getBedById('bed-123');

      expect(result).toEqual(mockBed);
      expect(bedRepository.findById).toHaveBeenCalledWith('bed-123');
    });

    it('should throw HttpError when bed not found', async () => {
      bedRepository.findById.mockResolvedValue(null);

      await expect(getBedById('bed-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createBed', () => {
    it('should create new bed', async () => {
      const bedData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: 'room-123',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const mockBed = {
        id: 'bed-123',
        ...bedData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      bedRepository.create.mockResolvedValue(mockBed);
      createAuditLog.mockResolvedValue({});

      const result = await createBed(bedData, {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '127.0.0.1',
        user_agent: 'test-agent'
      });

      expect(result).toEqual(mockBed);
      expect(bedRepository.create).toHaveBeenCalledWith(bedData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'BED_CREATED',
        entity: 'bed',
        entity_id: 'bed-123',
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '127.0.0.1',
        user_agent: 'test-agent',
        details: {
          tenant_id: bedData.tenant_id,
          facility_id: bedData.facility_id,
          ward_id: bedData.ward_id,
          room_id: bedData.room_id,
          label: bedData.label,
          status: bedData.status
        }
      });
    });

    it('should create bed with null room_id', async () => {
      const bedData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: null,
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const mockBed = { id: 'bed-123', ...bedData };
      bedRepository.create.mockResolvedValue(mockBed);
      createAuditLog.mockResolvedValue({});

      const result = await createBed(bedData, {});

      expect(result).toEqual(mockBed);
      expect(bedRepository.create).toHaveBeenCalledWith(bedData);
    });

    it('should call createAuditLog even without context', async () => {
      const bedData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const mockBed = { id: 'bed-123', ...bedData };
      bedRepository.create.mockResolvedValue(mockBed);
      createAuditLog.mockResolvedValue({});

      await createBed(bedData);

      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateBed', () => {
    it('should update bed', async () => {
      const updateData = {
        label: 'Updated Bed',
        status: 'OCCUPIED'
      };
      const beforeBed = {
        id: 'bed-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: 'room-123',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const afterBed = {
        ...beforeBed,
        ...updateData
      };
      bedRepository.findById.mockResolvedValue(beforeBed);
      bedRepository.update.mockResolvedValue(afterBed);
      createAuditLog.mockResolvedValue({});

      const result = await updateBed('bed-123', updateData, {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '127.0.0.1',
        user_agent: 'test-agent'
      });

      expect(result).toEqual(afterBed);
      expect(bedRepository.findById).toHaveBeenCalledWith('bed-123');
      expect(bedRepository.update).toHaveBeenCalledWith('bed-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'BED_UPDATED',
        entity: 'bed',
        entity_id: 'bed-123',
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '127.0.0.1',
        user_agent: 'test-agent',
        details: {
          before: {
            facility_id: beforeBed.facility_id,
            ward_id: beforeBed.ward_id,
            room_id: beforeBed.room_id,
            label: beforeBed.label,
            status: beforeBed.status
          },
          after: {
            facility_id: afterBed.facility_id,
            ward_id: afterBed.ward_id,
            room_id: afterBed.room_id,
            label: afterBed.label,
            status: afterBed.status
          }
        }
      });
    });

    it('should throw HttpError when bed not found', async () => {
      bedRepository.findById.mockResolvedValue(null);

      await expect(updateBed('bed-123', { label: 'Updated' }, {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should handle partial updates', async () => {
      const updateData = { status: 'OCCUPIED' };
      const beforeBed = {
        id: 'bed-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: 'room-123',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      const afterBed = { ...beforeBed, status: 'OCCUPIED' };
      bedRepository.findById.mockResolvedValue(beforeBed);
      bedRepository.update.mockResolvedValue(afterBed);
      createAuditLog.mockResolvedValue({});

      const result = await updateBed('bed-123', updateData, {});

      expect(result).toEqual(afterBed);
      expect(bedRepository.update).toHaveBeenCalledWith('bed-123', updateData);
    });
  });

  describe('deleteBed', () => {
    it('should soft delete bed', async () => {
      const mockBed = {
        id: 'bed-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: 'room-123',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      bedRepository.findById.mockResolvedValue(mockBed);
      bedRepository.softDelete.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      await deleteBed('bed-123', {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '127.0.0.1',
        user_agent: 'test-agent'
      });

      expect(bedRepository.findById).toHaveBeenCalledWith('bed-123');
      expect(bedRepository.softDelete).toHaveBeenCalledWith('bed-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'BED_DELETED',
        entity: 'bed',
        entity_id: 'bed-123',
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '127.0.0.1',
        user_agent: 'test-agent',
        details: {
          tenant_id: mockBed.tenant_id,
          facility_id: mockBed.facility_id,
          ward_id: mockBed.ward_id,
          room_id: mockBed.room_id,
          label: mockBed.label,
          status: mockBed.status
        }
      });
    });

    it('should throw HttpError when bed not found', async () => {
      bedRepository.findById.mockResolvedValue(null);

      await expect(deleteBed('bed-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should call createAuditLog even without context', async () => {
      const mockBed = {
        id: 'bed-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ward_id: 'ward-123',
        room_id: 'room-123',
        label: 'Bed 101',
        status: 'AVAILABLE'
      };
      bedRepository.findById.mockResolvedValue(mockBed);
      bedRepository.softDelete.mockResolvedValue({});
      createAuditLog.mockResolvedValue({});

      await deleteBed('bed-123');

      expect(createAuditLog).toHaveBeenCalled();
    });
  });
});
