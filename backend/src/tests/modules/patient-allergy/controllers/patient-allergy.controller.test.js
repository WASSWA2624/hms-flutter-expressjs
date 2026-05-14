/**
 * Patient Allergy controller tests
 *
 * @module tests/modules/patient-allergy/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/patient-allergy/patient-allergy.service');
jest.mock('@lib/response');

const patientAllergyService = require('@services/patient-allergy/patient-allergy.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { HttpError } = require('@lib/errors');
const {
  listPatientAllergies,
  getPatientAllergyById,
  createPatientAllergy,
  updatePatientAllergy,
  deletePatientAllergy
} = require('@controllers/patient-allergy/patient-allergy.controller');

describe('Patient Allergy Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123'
      },
      ip: '192.168.1.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listPatientAllergies', () => {
    it('should list patient allergies with default pagination', async () => {
      const mockResult = {
        items: [
          { id: 'allergy-1', patient_id: 'patient-123', allergen: 'Penicillin' },
          { id: 'allergy-2', patient_id: 'patient-123', allergen: 'Peanuts' }
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
      patientAllergyService.listPatientAllergies.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listPatientAllergies(req, res);

      expect(patientAllergyService.listPatientAllergies).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.patient_allergy.list.success',
        mockResult.items,
        mockResult.pagination
      );
    });

    it('should list patient allergies with filters', async () => {
      const mockResult = {
        items: [{ id: 'allergy-1', patient_id: 'patient-123', severity: 'SEVERE' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      patientAllergyService.listPatientAllergies.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = { patient_id: 'patient-123', severity: 'SEVERE' };

      await listPatientAllergies(req, res);

      expect(patientAllergyService.listPatientAllergies).toHaveBeenCalledWith(
        { patient_id: 'patient-123', severity: 'SEVERE' },
        1,
        20,
        'created_at',
        'desc'
      );
    });

    it('should handle custom sort parameters', async () => {
      const mockResult = { items: [], pagination: {} };
      patientAllergyService.listPatientAllergies.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = { sort_by: 'allergen', order: 'asc' };

      await listPatientAllergies(req, res);

      expect(patientAllergyService.listPatientAllergies).toHaveBeenCalledWith(
        {},
        1,
        20,
        'allergen',
        'asc'
      );
    });
  });

  describe('getPatientAllergyById', () => {
    it('should get patient allergy by ID', async () => {
      const mockAllergy = { id: 'allergy-123', allergen: 'Penicillin' };
      patientAllergyService.getPatientAllergyById.mockResolvedValue(mockAllergy);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'allergy-123' };

      await getPatientAllergyById(req, res);

      expect(patientAllergyService.getPatientAllergyById).toHaveBeenCalledWith('allergy-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.patient_allergy.get.success',
        mockAllergy
      );
    });

    it('should throw HttpError when patient allergy not found', async () => {
      patientAllergyService.getPatientAllergyById.mockResolvedValue(null);

      req.params = { id: 'allergy-123' };

      await expect(getPatientAllergyById(req, res))
        .rejects
        .toThrow();
    });
  });

  describe('createPatientAllergy', () => {
    it('should create new patient allergy', async () => {
      const newAllergy = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        allergen: 'Penicillin',
        severity: 'MODERATE'
      };
      const mockCreated = { id: 'allergy-123', ...newAllergy };
      patientAllergyService.createPatientAllergy.mockResolvedValue(mockCreated);
      sendSuccess.mockImplementation(() => {});

      req.body = newAllergy;

      await createPatientAllergy(req, res);

      expect(patientAllergyService.createPatientAllergy).toHaveBeenCalledWith(
        newAllergy,
        {
          user_id: 'user-123',
          ip: '192.168.1.1'
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.patient_allergy.create.success',
        mockCreated
      );
    });

    it('should pass audit context from request', async () => {
      const newAllergy = { allergen: 'Peanuts', severity: 'SEVERE' };
      const mockCreated = { id: 'allergy-456', ...newAllergy };
      patientAllergyService.createPatientAllergy.mockResolvedValue(mockCreated);
      sendSuccess.mockImplementation(() => {});

      req.body = newAllergy;
      req.user = { id: 'user-456' };
      req.ip = '10.0.0.1';

      await createPatientAllergy(req, res);

      expect(patientAllergyService.createPatientAllergy).toHaveBeenCalledWith(
        newAllergy,
        {
          user_id: 'user-456',
          ip: '10.0.0.1'
        }
      );
    });
  });

  describe('updatePatientAllergy', () => {
    it('should update patient allergy', async () => {
      const updateData = { severity: 'SEVERE', notes: 'Updated' };
      const mockUpdated = { id: 'allergy-123', severity: 'SEVERE', notes: 'Updated' };
      patientAllergyService.updatePatientAllergy.mockResolvedValue(mockUpdated);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'allergy-123' };
      req.body = updateData;

      await updatePatientAllergy(req, res);

      expect(patientAllergyService.updatePatientAllergy).toHaveBeenCalledWith(
        'allergy-123',
        updateData,
        {
          user_id: 'user-123',
          ip: '192.168.1.1'
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.patient_allergy.update.success',
        mockUpdated
      );
    });
  });

  describe('deletePatientAllergy', () => {
    it('should delete patient allergy and return 204', async () => {
      patientAllergyService.deletePatientAllergy.mockResolvedValue({});

      req.params = { id: 'allergy-123' };

      await deletePatientAllergy(req, res);

      expect(patientAllergyService.deletePatientAllergy).toHaveBeenCalledWith(
        'allergy-123',
        {
          user_id: 'user-123',
          ip: '192.168.1.1'
        }
      );
      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });
  });
});
