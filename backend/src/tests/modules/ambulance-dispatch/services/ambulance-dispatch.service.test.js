/**
 * Ambulance Dispatch service tests
 *
 * @module tests/modules/ambulance-dispatch/services
 * Per testing.mdc: Mock repository calls
 */

const { HttpError } = require('@lib/errors');

jest.mock('@repositories/ambulance-dispatch/ambulance-dispatch.repository');
jest.mock('@lib/audit');

const ambulanceDispatchRepository = require('@repositories/ambulance-dispatch/ambulance-dispatch.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listAmbulanceDispatches,
  getAmbulanceDispatchById,
  createAmbulanceDispatch,
  updateAmbulanceDispatch,
  deleteAmbulanceDispatch
} = require('@services/ambulance-dispatch/ambulance-dispatch.service');

describe('Ambulance Dispatch Service', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  describe('listAmbulanceDispatches', () => {
    it('should list dispatches with pagination', async () => {
      const mockDispatches = [
        { id: 'dispatch-1', ambulance_id: 'ambulance-1', status: 'DISPATCHED' }
      ];
      ambulanceDispatchRepository.findMany.mockResolvedValue(mockDispatches);
      ambulanceDispatchRepository.count.mockResolvedValue(1);

      const result = await listAmbulanceDispatches({}, 1, 20);

      expect(result.dispatches).toEqual([expect.objectContaining(mockDispatches[0])]);
      expect(result.dispatches[0]).toEqual(expect.objectContaining({ display_id: 'dispatch-1' }));
      expect(result.pagination.total).toBe(1);
    });
  });

  describe('getAmbulanceDispatchById', () => {
    it('should get dispatch by ID', async () => {
      const mockDispatch = { id: 'dispatch-123', status: 'DISPATCHED' };
      ambulanceDispatchRepository.findById.mockResolvedValue(mockDispatch);

      const result = await getAmbulanceDispatchById('dispatch-123');

      expect(result).toEqual(expect.objectContaining(mockDispatch));
      expect(result).toEqual(expect.objectContaining({ display_id: 'dispatch-123' }));
    });

    it('should throw HttpError if dispatch not found', async () => {
      ambulanceDispatchRepository.findById.mockResolvedValue(null);

      await expect(getAmbulanceDispatchById('dispatch-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createAmbulanceDispatch', () => {
    it('should create dispatch and audit log', async () => {
      const mockDispatch = {
        id: 'dispatch-123',
        ambulance_id: 'ambulance-123',
        emergency_case_id: 'case-123',
        status: 'DISPATCHED'
      };
      ambulanceDispatchRepository.create.mockResolvedValue(mockDispatch);
      createAuditLog.mockResolvedValue();

      const result = await createAmbulanceDispatch({
        ambulance_id: 'ambulance-123',
        emergency_case_id: 'case-123',
        status: 'DISPATCHED'
      }, {});

      expect(result).toEqual(expect.objectContaining(mockDispatch));
      expect(result).toEqual(expect.objectContaining({ display_id: 'dispatch-123' }));
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateAmbulanceDispatch', () => {
    it('should update dispatch and create audit log', async () => {
      const beforeDispatch = { id: 'dispatch-123', status: 'DISPATCHED' };
      const updatedDispatch = { id: 'dispatch-123', status: 'EN_ROUTE' };

      ambulanceDispatchRepository.findById.mockResolvedValue(beforeDispatch);
      ambulanceDispatchRepository.update.mockResolvedValue(updatedDispatch);
      createAuditLog.mockResolvedValue();

      const result = await updateAmbulanceDispatch('dispatch-123', { status: 'EN_ROUTE' }, {});

      expect(result).toEqual(expect.objectContaining(updatedDispatch));
      expect(result).toEqual(expect.objectContaining({ display_id: 'dispatch-123' }));
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('deleteAmbulanceDispatch', () => {
    it('should soft delete dispatch and create audit log', async () => {
      const mockDispatch = { id: 'dispatch-123', status: 'DISPATCHED' };

      ambulanceDispatchRepository.findById.mockResolvedValue(mockDispatch);
      ambulanceDispatchRepository.softDelete.mockResolvedValue();
      createAuditLog.mockResolvedValue();

      await deleteAmbulanceDispatch('dispatch-123', {});

      expect(ambulanceDispatchRepository.softDelete).toHaveBeenCalledWith('dispatch-123');
      expect(createAuditLog).toHaveBeenCalled();
    });
  });
});
