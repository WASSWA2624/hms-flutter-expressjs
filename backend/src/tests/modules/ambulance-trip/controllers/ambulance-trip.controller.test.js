/**
 * Ambulance Trip controller tests
 *
 * @module tests/modules/ambulance-trip/controllers
 * Per testing.mdc: Mock service calls
 */

jest.mock('@services/ambulance-trip/ambulance-trip.service');
jest.mock('@lib/response');

const ambulanceTripService = require('@services/ambulance-trip/ambulance-trip.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listAmbulanceTrips,
  getAmbulanceTripById,
  createAmbulanceTrip,
  updateAmbulanceTrip,
  deleteAmbulanceTrip
} = require('@controllers/ambulance-trip/ambulance-trip.controller');

describe('Ambulance Trip Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123', tenant_id: 'tenant-123' },
      ip: '127.0.0.1',
      get: jest.fn(() => 'test-agent')
    };
    res = {};
  });

  describe('listAmbulanceTrips', () => {
    it('should list trips', async () => {
      const mockResult = {
        trips: [{ id: 'trip-1' }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };

      ambulanceTripService.listAmbulanceTrips.mockResolvedValue(mockResult);
      sendPaginated.mockReturnValue();

      await listAmbulanceTrips(req, res);

      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getAmbulanceTripById', () => {
    it('should get trip by ID', async () => {
      const mockTrip = { id: 'trip-123' };

      ambulanceTripService.getAmbulanceTripById.mockResolvedValue(mockTrip);
      sendSuccess.mockReturnValue();

      req.params.id = 'trip-123';

      await getAmbulanceTripById(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.ambulance_trip.get.success', mockTrip);
    });
  });

  describe('createAmbulanceTrip', () => {
    it('should create trip', async () => {
      const mockTrip = { id: 'trip-123' };

      ambulanceTripService.createAmbulanceTrip.mockResolvedValue(mockTrip);
      sendSuccess.mockReturnValue();

      await createAmbulanceTrip(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(res, 201, 'messages.ambulance_trip.create.success', mockTrip);
    });
  });

  describe('updateAmbulanceTrip', () => {
    it('should update trip', async () => {
      const mockTrip = { id: 'trip-123' };

      ambulanceTripService.updateAmbulanceTrip.mockResolvedValue(mockTrip);
      sendSuccess.mockReturnValue();

      req.params.id = 'trip-123';

      await updateAmbulanceTrip(req, res);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteAmbulanceTrip', () => {
    it('should delete trip', async () => {
      ambulanceTripService.deleteAmbulanceTrip.mockResolvedValue();
      sendNoContent.mockReturnValue();

      req.params.id = 'trip-123';

      await deleteAmbulanceTrip(req, res);

      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
