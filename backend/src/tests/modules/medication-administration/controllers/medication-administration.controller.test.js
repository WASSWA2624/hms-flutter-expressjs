/**
 * Medication administration controller tests
 *
 * @module tests/modules/medication-administration/controllers
 * Per testing.mdc: Mock all service dependencies
 */

jest.mock('@services/medication-administration/medication-administration.service');
jest.mock('@lib/response');

const medicationAdministrationService = require('@services/medication-administration/medication-administration.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const medicationAdministrationController = require('@controllers/medication-administration/medication-administration.controller');

describe('Medication Administration Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123' },
      ip: '127.0.0.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };
  });

  describe('listMedicationAdministrations', () => {
    it('should list successfully', async () => {
      const mockResult = {
        medicationAdministrations: [{ id: 'med-1' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      medicationAdministrationService.listMedicationAdministrations.mockResolvedValue(mockResult);

      req.query = { page: '1', limit: '20' };

      await medicationAdministrationController.listMedicationAdministrations(req, res);

      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('getMedicationAdministrationById', () => {
    it('should get by ID successfully', async () => {
      const mockRecord = { id: 'med-123', dose: '500mg' };
      medicationAdministrationService.getMedicationAdministrationById.mockResolvedValue(mockRecord);

      req.params = { id: 'med-123' };

      await medicationAdministrationController.getMedicationAdministrationById(req, res);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('createMedicationAdministration', () => {
    it('should create successfully', async () => {
      const mockRecord = { id: 'med-123' };
      medicationAdministrationService.createMedicationAdministration.mockResolvedValue(mockRecord);

      req.body = { admission_id: 'admission-123', dose: '500mg', route: 'ORAL' };

      await medicationAdministrationController.createMedicationAdministration(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.medication_administration.create.success',
        mockRecord
      );
    });
  });

  describe('updateMedicationAdministration', () => {
    it('should update successfully', async () => {
      const mockRecord = { id: 'med-123', dose: '1000mg' };
      medicationAdministrationService.updateMedicationAdministration.mockResolvedValue(mockRecord);

      req.params = { id: 'med-123' };
      req.body = { dose: '1000mg' };

      await medicationAdministrationController.updateMedicationAdministration(req, res);

      expect(sendSuccess).toHaveBeenCalled();
    });
  });

  describe('deleteMedicationAdministration', () => {
    it('should delete successfully', async () => {
      medicationAdministrationService.deleteMedicationAdministration.mockResolvedValue();

      req.params = { id: 'med-123' };

      await medicationAdministrationController.deleteMedicationAdministration(req, res);

      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
