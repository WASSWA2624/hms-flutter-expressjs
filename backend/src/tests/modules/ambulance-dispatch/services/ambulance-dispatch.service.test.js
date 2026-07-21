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

const rawDispatch = (overrides = {}) => ({
  id: '123e4567-e89b-12d3-a456-426614174000',
  human_friendly_id: 'ADS000001',
  ambulance_id: '123e4567-e89b-12d3-a456-426614174001',
  emergency_case_id: '123e4567-e89b-12d3-a456-426614174002',
  ambulance: {
    human_friendly_id: 'AMB000001',
    identifier: 'Ambulance 1'},
  emergency_case: {
    human_friendly_id: 'EME000001',
    patient: {
      human_friendly_id: 'PAT000001',
      first_name: 'Jane',
      last_name: 'Doe'}},
  status: 'DISPATCHED',
  ...overrides});

describe('Ambulance Dispatch Service', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  describe('listAmbulanceDispatches', () => {
    it('should list dispatches with pagination', async () => {
      const mockDispatches = [rawDispatch()];
      ambulanceDispatchRepository.findMany.mockResolvedValue(mockDispatches);
      ambulanceDispatchRepository.count.mockResolvedValue(1);

      const result = await listAmbulanceDispatches({}, 1, 20);

      expect(result.dispatches[0]).toEqual(expect.objectContaining({
        human_friendly_id: 'ADS000001',
        display_id: 'ADS000001',
        ambulance_id: 'AMB000001',
        emergency_case_id: 'EME000001',
        patient_display_id: 'PAT000001'}));
      expect(result.dispatches[0]).not.toHaveProperty('id');
      expect(result.dispatches[0]).not.toHaveProperty('ambulance');
      expect(result.dispatches[0]).not.toHaveProperty('emergency_case');
      expect(result.pagination.total).toBe(1);
    });
  });

  describe('getAmbulanceDispatchById', () => {
    it('should get dispatch by ID', async () => {
      const mockDispatch = rawDispatch();
      ambulanceDispatchRepository.findById.mockResolvedValue(mockDispatch);

      const result = await getAmbulanceDispatchById('ADS000001');

      expect(result).toEqual(expect.objectContaining({
        human_friendly_id: 'ADS000001',
        display_id: 'ADS000001'}));
      expect(result).not.toHaveProperty('id');
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
      const mockDispatch = rawDispatch();
      ambulanceDispatchRepository.create.mockResolvedValue(mockDispatch);
      createAuditLog.mockResolvedValue();

      const result = await createAmbulanceDispatch({
        ambulance_id: 'ambulance-123',
        emergency_case_id: 'case-123',
        status: 'DISPATCHED'
      }, {});

      expect(result).toEqual(expect.objectContaining({
        human_friendly_id: 'ADS000001',
        ambulance_id: 'AMB000001',
        emergency_case_id: 'EME000001'}));
      expect(result).not.toHaveProperty('id');
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('updateAmbulanceDispatch', () => {
    it('should update dispatch and create audit log', async () => {
      const beforeDispatch = rawDispatch();
      const updatedDispatch = rawDispatch({ status: 'EN_ROUTE' });

      ambulanceDispatchRepository.findById.mockResolvedValue(beforeDispatch);
      ambulanceDispatchRepository.update.mockResolvedValue(updatedDispatch);
      createAuditLog.mockResolvedValue();

      const result = await updateAmbulanceDispatch('ADS000001', { status: 'EN_ROUTE' }, {});

      expect(result).toEqual(expect.objectContaining({
        human_friendly_id: 'ADS000001',
        display_id: 'ADS000001',
        status: 'EN_ROUTE'}));
      expect(result).not.toHaveProperty('id');
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
