/**
 * Ambulance Dispatch controller tests
 *
 * @module tests/modules/ambulance-dispatch/controllers
 * Per testing.mdc: Mock service calls
 */

jest.mock('@services/ambulance-dispatch/ambulance-dispatch.service');
jest.mock('@lib/response');

const ambulanceDispatchService = require('@services/ambulance-dispatch/ambulance-dispatch.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listAmbulanceDispatches,
  getAmbulanceDispatchById,
  createAmbulanceDispatch,
  updateAmbulanceDispatch,
  deleteAmbulanceDispatch
} = require('@controllers/ambulance-dispatch/ambulance-dispatch.controller');

describe('Ambulance Dispatch Controller', () => {
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

  describe('listAmbulanceDispatches', () => {
    it('should list dispatches', async () => {
      const mockResult = {
        dispatches: [{ id: 'dispatch-1' }],
        pagination: { page: 1, limit: 20, total: 1, totalPages: 1, hasNextPage: false, hasPreviousPage: false }
      };

      ambulanceDispatchService.listAmbulanceDispatches.mockResolvedValue(mockResult);
      sendPaginated.mockReturnValue();

      await listAmbulanceDispatches(req, res);

      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getAmbulanceDispatchById', () => {
    it('should get dispatch by ID', async () => {
      const mockDispatch = { id: 'dispatch-123' };

      ambulanceDispatchService.getAmbulanceDispatchById.mockResolvedValue(mockDispatch);
      sendSuccess.mockReturnValue();

      req.params.id = 'dispatch-123';

      await getAmbulanceDispatchById(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(res, 200, 'messages.ambulance_dispatch.get.success', mockDispatch);
    });
  });

  describe('createAmbulanceDispatch', () => {
    it('should create dispatch', async () => {
      const mockDispatch = { id: 'dispatch-123' };

      ambulanceDispatchService.createAmbulanceDispatch.mockResolvedValue(mockDispatch);
      sendSuccess.mockReturnValue();

      await createAmbulanceDispatch(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(res, 201, 'messages.ambulance_dispatch.create.success', mockDispatch);
    });
  });

  describe('updateAmbulanceDispatch', () => {
    it('should update dispatch', async () => {
      const mockDispatch = { id: 'dispatch-123' };

      ambulanceDispatchService.updateAmbulanceDispatch.mockResolvedValue(mockDispatch);
      sendSuccess.mockReturnValue();

      req.params.id = 'dispatch-123';

      await updateAmbulanceDispatch(req, res);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteAmbulanceDispatch', () => {
    it('should delete dispatch', async () => {
      ambulanceDispatchService.deleteAmbulanceDispatch.mockResolvedValue();
      sendNoContent.mockReturnValue();

      req.params.id = 'dispatch-123';

      await deleteAmbulanceDispatch(req, res);

      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
