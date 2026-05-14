/**
 * Ambulance service tests
 *
 * @module tests/modules/ambulance/services
 * Per testing.mdc: Mock repository calls
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/ambulance/ambulance.repository');
jest.mock('@lib/audit');

const ambulanceRepository = require('@repositories/ambulance/ambulance.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listAmbulances,
  getAmbulanceById,
  createAmbulance,
  updateAmbulance,
  deleteAmbulance
} = require('@services/ambulance/ambulance.service');

describe('Ambulance Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listAmbulances', () => {
    it('should list ambulances with pagination', async () => {
      const mockAmbulances = [
        { id: 'ambulance-1', identifier: 'AMB-001', status: 'AVAILABLE' },
        { id: 'ambulance-2', identifier: 'AMB-002', status: 'DISPATCHED' }
      ];
      ambulanceRepository.findMany.mockResolvedValue(mockAmbulances);
      ambulanceRepository.count.mockResolvedValue(2);

      const result = await listAmbulances({}, 1, 20);

      expect(result.ambulances).toEqual(
        expect.arrayContaining([
          expect.objectContaining(mockAmbulances[0]),
          expect.objectContaining(mockAmbulances[1]),
        ])
      );
      expect(result.ambulances[0]).toEqual(expect.objectContaining({ display_id: 'ambulance-1' }));
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should list ambulances with filters', async () => {
      const mockAmbulances = [
        { id: 'ambulance-1', identifier: 'AMB-001', status: 'AVAILABLE' }
      ];
      ambulanceRepository.findMany.mockResolvedValue(mockAmbulances);
      ambulanceRepository.count.mockResolvedValue(1);

      const filters = {
        tenant_id: 'tenant-123',
        status: 'AVAILABLE'
      };

      const result = await listAmbulances(filters, 1, 20);

      expect(result.ambulances).toEqual([expect.objectContaining(mockAmbulances[0])]);
      expect(ambulanceRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123', status: 'AVAILABLE' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle search filter', async () => {
      const mockAmbulances = [];
      ambulanceRepository.findMany.mockResolvedValue(mockAmbulances);
      ambulanceRepository.count.mockResolvedValue(0);

      const filters = { search: 'AMB' };

      await listAmbulances(filters, 1, 20);

      expect(ambulanceRepository.findMany).toHaveBeenCalledWith(
        { search: 'AMB' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should calculate pagination metadata correctly', async () => {
      ambulanceRepository.findMany.mockResolvedValue([]);
      ambulanceRepository.count.mockResolvedValue(50);

      const result = await listAmbulances({}, 2, 20);

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 50,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true
      });
    });
  });

  describe('getAmbulanceById', () => {
    it('should get ambulance by ID', async () => {
      const mockAmbulance = {
        id: 'ambulance-123',
        identifier: 'AMB-001',
        status: 'AVAILABLE'
      };
      ambulanceRepository.findById.mockResolvedValue(mockAmbulance);

      const result = await getAmbulanceById('ambulance-123');

      expect(result).toEqual(expect.objectContaining(mockAmbulance));
      expect(result).toEqual(expect.objectContaining({ display_id: 'ambulance-123' }));
      expect(ambulanceRepository.findById).toHaveBeenCalledWith('ambulance-123');
    });

    it('should throw HttpError if ambulance not found', async () => {
      ambulanceRepository.findById.mockResolvedValue(null);

      await expect(getAmbulanceById('ambulance-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createAmbulance', () => {
    it('should create ambulance and audit log', async () => {
      const mockAmbulance = {
        id: 'ambulance-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        identifier: 'AMB-001',
        status: 'AVAILABLE'
      };
      ambulanceRepository.create.mockResolvedValue(mockAmbulance);
      createAuditLog.mockResolvedValue();

      const data = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        identifier: 'AMB-001',
        status: 'AVAILABLE'
      };

      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '127.0.0.1'
      };

      const result = await createAmbulance(data, context);

      expect(result).toEqual(expect.objectContaining(mockAmbulance));
      expect(result).toEqual(expect.objectContaining({ display_id: 'ambulance-123' }));
      expect(ambulanceRepository.create).toHaveBeenCalledWith(data);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'AMBULANCE_CREATED',
          entity: 'ambulance',
          entity_id: 'ambulance-123'
        })
      );
    });
  });

  describe('updateAmbulance', () => {
    it('should update ambulance and create audit log', async () => {
      const beforeAmbulance = {
        id: 'ambulance-123',
        identifier: 'AMB-001',
        status: 'AVAILABLE'
      };
      const updatedAmbulance = {
        id: 'ambulance-123',
        identifier: 'AMB-UPDATED',
        status: 'DISPATCHED'
      };

      ambulanceRepository.findById.mockResolvedValue(beforeAmbulance);
      ambulanceRepository.update.mockResolvedValue(updatedAmbulance);
      createAuditLog.mockResolvedValue();

      const data = {
        identifier: 'AMB-UPDATED',
        status: 'DISPATCHED'
      };

      const result = await updateAmbulance('ambulance-123', data, {});

      expect(result).toEqual(expect.objectContaining(updatedAmbulance));
      expect(result).toEqual(expect.objectContaining({ display_id: 'ambulance-123' }));
      expect(ambulanceRepository.update).toHaveBeenCalledWith('ambulance-123', data);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'AMBULANCE_UPDATED',
          entity: 'ambulance',
          entity_id: 'ambulance-123'
        })
      );
    });

    it('should throw HttpError if ambulance not found', async () => {
      ambulanceRepository.findById.mockResolvedValue(null);

      await expect(updateAmbulance('ambulance-123', {}, {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteAmbulance', () => {
    it('should soft delete ambulance and create audit log', async () => {
      const mockAmbulance = {
        id: 'ambulance-123',
        tenant_id: 'tenant-123',
        identifier: 'AMB-001',
        status: 'AVAILABLE'
      };

      ambulanceRepository.findById.mockResolvedValue(mockAmbulance);
      ambulanceRepository.softDelete.mockResolvedValue();
      createAuditLog.mockResolvedValue();

      await deleteAmbulance('ambulance-123', {});

      expect(ambulanceRepository.softDelete).toHaveBeenCalledWith('ambulance-123');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'AMBULANCE_DELETED',
          entity: 'ambulance',
          entity_id: 'ambulance-123'
        })
      );
    });

    it('should throw HttpError if ambulance not found', async () => {
      ambulanceRepository.findById.mockResolvedValue(null);

      await expect(deleteAmbulance('ambulance-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });
});
