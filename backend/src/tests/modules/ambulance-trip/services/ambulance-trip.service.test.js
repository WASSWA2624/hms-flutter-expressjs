/**
 * Ambulance Trip service tests
 *
 * @module tests/modules/ambulance-trip/services
 * Per testing.mdc: Mock repository calls
 */

const { HttpError } = require('@lib/errors');

jest.mock('@repositories/ambulance-trip/ambulance-trip.repository');
jest.mock('@lib/audit');

const ambulanceTripRepository = require('@repositories/ambulance-trip/ambulance-trip.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listAmbulanceTrips,
  getAmbulanceTripById,
  createAmbulanceTrip,
  updateAmbulanceTrip,
  deleteAmbulanceTrip
} = require('@services/ambulance-trip/ambulance-trip.service');

describe('Ambulance Trip Service', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  describe('listAmbulanceTrips', () => {
    it('should list trips with pagination', async () => {
      const mockTrips = [
        { id: 'trip-1', ambulance_id: 'ambulance-1' }
      ];
      ambulanceTripRepository.findMany.mockResolvedValue(mockTrips);
      ambulanceTripRepository.count.mockResolvedValue(1);

      const result = await listAmbulanceTrips({}, 1, 20);

      expect(result.trips).toEqual([expect.objectContaining(mockTrips[0])]);
      expect(result.trips[0]).toEqual(expect.objectContaining({ display_id: 'trip-1' }));
      expect(result.pagination.total).toBe(1);
    });
  });

  describe('getAmbulanceTripById', () => {
    it('should get trip by ID', async () => {
      const mockTrip = { id: 'trip-123' };
      ambulanceTripRepository.findById.mockResolvedValue(mockTrip);

      const result = await getAmbulanceTripById('trip-123');

      expect(result).toEqual(expect.objectContaining(mockTrip));
      expect(result).toEqual(expect.objectContaining({ display_id: 'trip-123' }));
    });

    it('should throw HttpError if trip not found', async () => {
      ambulanceTripRepository.findById.mockResolvedValue(null);

      await expect(getAmbulanceTripById('trip-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createAmbulanceTrip', () => {
    it('should create trip and audit log', async () => {
      const mockTrip = {
        id: 'trip-123',
        ambulance_id: 'ambulance-123',
        emergency_case_id: 'case-123'
      };
      ambulanceTripRepository.findMany.mockResolvedValue([]);
      ambulanceTripRepository.create.mockResolvedValue(mockTrip);
      createAuditLog.mockResolvedValue();

      const result = await createAmbulanceTrip({
        ambulance_id: 'ambulance-123',
        emergency_case_id: 'case-123'
      }, {});

      expect(result).toEqual(expect.objectContaining(mockTrip));
      expect(result).toEqual(expect.objectContaining({ display_id: 'trip-123' }));
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateAmbulanceTrip', () => {
    it('should update trip and create audit log', async () => {
      const beforeTrip = { id: 'trip-123', started_at: null };
      const updatedTrip = { id: 'trip-123', started_at: new Date('2026-01-19T10:00:00Z') };

      ambulanceTripRepository.findById.mockResolvedValue(beforeTrip);
      ambulanceTripRepository.findMany.mockResolvedValue([]);
      ambulanceTripRepository.update.mockResolvedValue(updatedTrip);
      createAuditLog.mockResolvedValue();

      const result = await updateAmbulanceTrip('trip-123', { started_at: '2026-01-19T10:00:00Z' }, {});

      expect(result).toEqual(expect.objectContaining(updatedTrip));
      expect(result).toEqual(expect.objectContaining({ display_id: 'trip-123' }));
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('deleteAmbulanceTrip', () => {
    it('should soft delete trip and create audit log', async () => {
      const mockTrip = { id: 'trip-123' };

      ambulanceTripRepository.findById.mockResolvedValue(mockTrip);
      ambulanceTripRepository.softDelete.mockResolvedValue();
      createAuditLog.mockResolvedValue();

      await deleteAmbulanceTrip('trip-123', {});

      expect(ambulanceTripRepository.softDelete).toHaveBeenCalledWith('trip-123');
      expect(createAuditLog).toHaveBeenCalled();
    });
  });
});
