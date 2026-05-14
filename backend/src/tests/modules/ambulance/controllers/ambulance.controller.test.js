/**
 * Ambulance controller tests
 *
 * @module tests/modules/ambulance/controllers
 * Per testing.mdc: Mock service calls
 */

// Mock dependencies
jest.mock('@services/ambulance/ambulance.service');
jest.mock('@lib/response');

const ambulanceService = require('@services/ambulance/ambulance.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listAmbulances,
  getAmbulanceById,
  createAmbulance,
  updateAmbulance,
  deleteAmbulance
} = require('@controllers/ambulance/ambulance.controller');

describe('Ambulance Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123'
      },
      ip: '127.0.0.1',
      get: jest.fn((header) => header === 'user-agent' ? 'test-agent' : undefined)
    };
    res = {};
  });

  describe('listAmbulances', () => {
    it('should list ambulances', async () => {
      const mockResult = {
        ambulances: [
          { id: 'ambulance-1', identifier: 'AMB-001' },
          { id: 'ambulance-2', identifier: 'AMB-002' }
        ],
        pagination: {
          page: 1,
          limit: 20,
          total: 2,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };

      ambulanceService.listAmbulances.mockResolvedValue(mockResult);
      sendPaginated.mockReturnValue();

      req.query = { page: 1, limit: 20 };

      await listAmbulances(req, res);

      expect(ambulanceService.listAmbulances).toHaveBeenCalledWith({}, 1, 20, undefined, undefined);
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.ambulance.list.success',
        mockResult.ambulances,
        mockResult.pagination
      );
    });

    it('should list ambulances with filters', async () => {
      const mockResult = {
        ambulances: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };

      ambulanceService.listAmbulances.mockResolvedValue(mockResult);
      sendPaginated.mockReturnValue();

      req.query = {
        tenant_id: 'tenant-123',
        status: 'AVAILABLE',
        search: 'AMB'
      };

      await listAmbulances(req, res);

      expect(ambulanceService.listAmbulances).toHaveBeenCalledWith(
        {
          tenant_id: 'tenant-123',
          status: 'AVAILABLE',
          search: 'AMB'
        },
        undefined,
        undefined,
        undefined,
        undefined
      );
    });
  });

  describe('getAmbulanceById', () => {
    it('should get ambulance by ID', async () => {
      const mockAmbulance = {
        id: 'ambulance-123',
        identifier: 'AMB-001',
        status: 'AVAILABLE'
      };

      ambulanceService.getAmbulanceById.mockResolvedValue(mockAmbulance);
      sendSuccess.mockReturnValue();

      req.params.id = 'ambulance-123';

      await getAmbulanceById(req, res);

      expect(ambulanceService.getAmbulanceById).toHaveBeenCalledWith('ambulance-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.ambulance.get.success',
        mockAmbulance
      );
    });
  });

  describe('createAmbulance', () => {
    it('should create ambulance', async () => {
      const mockAmbulance = {
        id: 'ambulance-123',
        tenant_id: 'tenant-123',
        identifier: 'AMB-001',
        status: 'AVAILABLE'
      };

      ambulanceService.createAmbulance.mockResolvedValue(mockAmbulance);
      sendSuccess.mockReturnValue();

      req.body = {
        tenant_id: 'tenant-123',
        identifier: 'AMB-001',
        status: 'AVAILABLE'
      };

      await createAmbulance(req, res);

      expect(ambulanceService.createAmbulance).toHaveBeenCalledWith(
        req.body,
        expect.objectContaining({
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '127.0.0.1',
          user_agent: 'test-agent'
        })
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.ambulance.create.success',
        mockAmbulance
      );
    });
  });

  describe('updateAmbulance', () => {
    it('should update ambulance', async () => {
      const mockAmbulance = {
        id: 'ambulance-123',
        identifier: 'AMB-UPDATED',
        status: 'DISPATCHED'
      };

      ambulanceService.updateAmbulance.mockResolvedValue(mockAmbulance);
      sendSuccess.mockReturnValue();

      req.params.id = 'ambulance-123';
      req.body = {
        identifier: 'AMB-UPDATED',
        status: 'DISPATCHED'
      };

      await updateAmbulance(req, res);

      expect(ambulanceService.updateAmbulance).toHaveBeenCalledWith(
        'ambulance-123',
        req.body,
        expect.objectContaining({
          user_id: 'user-123',
          tenant_id: 'tenant-123'
        })
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.ambulance.update.success',
        mockAmbulance
      );
    });
  });

  describe('deleteAmbulance', () => {
    it('should delete ambulance', async () => {
      ambulanceService.deleteAmbulance.mockResolvedValue();
      sendNoContent.mockReturnValue();

      req.params.id = 'ambulance-123';

      await deleteAmbulance(req, res);

      expect(ambulanceService.deleteAmbulance).toHaveBeenCalledWith(
        'ambulance-123',
        expect.objectContaining({
          user_id: 'user-123',
          tenant_id: 'tenant-123'
        })
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
