/**
 * Patient Medical History controller tests
 *
 * @module tests/modules/patient-medical-history/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/patient-medical-history/patient-medical-history.service');
jest.mock('@lib/response');

const patientMedicalHistoryService = require('@services/patient-medical-history/patient-medical-history.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { HttpError } = require('@lib/errors');
const {
  listPatientMedicalHistories,
  getPatientMedicalHistoryById,
  createPatientMedicalHistory,
  updatePatientMedicalHistory,
  deletePatientMedicalHistory
} = require('@controllers/patient-medical-history/patient-medical-history.controller');

describe('Patient Medical History Controller', () => {
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

  describe('listPatientMedicalHistories', () => {
    it('should list patient medical histories with default pagination', async () => {
      const mockResult = {
        items: [
          { id: 'history-1', patient_id: 'patient-123', condition: 'Hypertension' },
          { id: 'history-2', patient_id: 'patient-123', condition: 'Diabetes' }
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
      patientMedicalHistoryService.listPatientMedicalHistories.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listPatientMedicalHistories(req, res);

      expect(patientMedicalHistoryService.listPatientMedicalHistories).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.patient_medical_history.list.success',
        mockResult.items,
        mockResult.pagination
      );
    });

    it('should list patient medical histories with filters', async () => {
      const mockResult = {
        items: [{ id: 'history-1', patient_id: 'patient-123', condition: 'Diabetes' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      patientMedicalHistoryService.listPatientMedicalHistories.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = { patient_id: 'patient-123', condition: 'Diabetes' };

      await listPatientMedicalHistories(req, res);

      expect(patientMedicalHistoryService.listPatientMedicalHistories).toHaveBeenCalledWith(
        { patient_id: 'patient-123', condition: 'Diabetes' },
        1,
        20,
        'created_at',
        'desc'
      );
    });

    it('should handle custom sort parameters', async () => {
      const mockResult = { items: [], pagination: {} };
      patientMedicalHistoryService.listPatientMedicalHistories.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = { sort_by: 'diagnosis_date', order: 'desc' };

      await listPatientMedicalHistories(req, res);

      expect(patientMedicalHistoryService.listPatientMedicalHistories).toHaveBeenCalledWith(
        {},
        1,
        20,
        'diagnosis_date',
        'desc'
      );
    });
  });

  describe('getPatientMedicalHistoryById', () => {
    it('should get patient medical history by ID', async () => {
      const mockHistory = { id: 'history-123', condition: 'Hypertension' };
      patientMedicalHistoryService.getPatientMedicalHistoryById.mockResolvedValue(mockHistory);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'history-123' };

      await getPatientMedicalHistoryById(req, res);

      expect(patientMedicalHistoryService.getPatientMedicalHistoryById).toHaveBeenCalledWith('history-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.patient_medical_history.get.success',
        mockHistory
      );
    });

    it('should throw HttpError when patient medical history not found', async () => {
      patientMedicalHistoryService.getPatientMedicalHistoryById.mockResolvedValue(null);

      req.params = { id: 'history-123' };

      await expect(getPatientMedicalHistoryById(req, res))
        .rejects
        .toThrow();
    });
  });

  describe('createPatientMedicalHistory', () => {
    it('should create new patient medical history', async () => {
      const newHistory = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        condition: 'Hypertension',
        diagnosis_date: '2024-01-15'
      };
      const mockCreated = { id: 'history-123', ...newHistory };
      patientMedicalHistoryService.createPatientMedicalHistory.mockResolvedValue(mockCreated);
      sendSuccess.mockImplementation(() => {});

      req.body = newHistory;

      await createPatientMedicalHistory(req, res);

      expect(patientMedicalHistoryService.createPatientMedicalHistory).toHaveBeenCalledWith(
        newHistory,
        {
          user_id: 'user-123',
          ip: '192.168.1.1'
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.patient_medical_history.create.success',
        mockCreated
      );
    });

    it('should pass audit context from request', async () => {
      const newHistory = { condition: 'Diabetes' };
      const mockCreated = { id: 'history-456', ...newHistory };
      patientMedicalHistoryService.createPatientMedicalHistory.mockResolvedValue(mockCreated);
      sendSuccess.mockImplementation(() => {});

      req.body = newHistory;
      req.user = { id: 'user-456' };
      req.ip = '10.0.0.1';

      await createPatientMedicalHistory(req, res);

      expect(patientMedicalHistoryService.createPatientMedicalHistory).toHaveBeenCalledWith(
        newHistory,
        {
          user_id: 'user-456',
          ip: '10.0.0.1'
        }
      );
    });
  });

  describe('updatePatientMedicalHistory', () => {
    it('should update patient medical history', async () => {
      const updateData = { condition: 'Diabetes Type 2', notes: 'Updated' };
      const mockUpdated = { id: 'history-123', condition: 'Diabetes Type 2', notes: 'Updated' };
      patientMedicalHistoryService.updatePatientMedicalHistory.mockResolvedValue(mockUpdated);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'history-123' };
      req.body = updateData;

      await updatePatientMedicalHistory(req, res);

      expect(patientMedicalHistoryService.updatePatientMedicalHistory).toHaveBeenCalledWith(
        'history-123',
        updateData,
        {
          user_id: 'user-123',
          ip: '192.168.1.1'
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.patient_medical_history.update.success',
        mockUpdated
      );
    });
  });

  describe('deletePatientMedicalHistory', () => {
    it('should delete patient medical history and return 204', async () => {
      patientMedicalHistoryService.deletePatientMedicalHistory.mockResolvedValue({});

      req.params = { id: 'history-123' };

      await deletePatientMedicalHistory(req, res);

      expect(patientMedicalHistoryService.deletePatientMedicalHistory).toHaveBeenCalledWith(
        'history-123',
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
