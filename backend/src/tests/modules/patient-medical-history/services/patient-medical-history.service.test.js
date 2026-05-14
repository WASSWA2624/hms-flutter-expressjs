/**
 * Patient Medical History service tests
 *
 * @module tests/modules/patient-medical-history/services
 * Per testing.mdc: Mock all external dependencies
 */

// Mock dependencies
jest.mock('@repositories/patient-medical-history/patient-medical-history.repository');
jest.mock('@lib/audit');

const patientMedicalHistoryRepository = require('@repositories/patient-medical-history/patient-medical-history.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listPatientMedicalHistories,
  getPatientMedicalHistoryById,
  createPatientMedicalHistory,
  updatePatientMedicalHistory,
  deletePatientMedicalHistory
} = require('@services/patient-medical-history/patient-medical-history.service');

describe('Patient Medical History Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listPatientMedicalHistories', () => {
    it('should list patient medical histories with default pagination', async () => {
      const mockHistories = [
        { id: 'history-1', patient_id: 'patient-123', condition: 'Hypertension' },
        { id: 'history-2', patient_id: 'patient-123', condition: 'Diabetes' }
      ];
      patientMedicalHistoryRepository.findMany.mockResolvedValue(mockHistories);
      patientMedicalHistoryRepository.count.mockResolvedValue(10);

      const result = await listPatientMedicalHistories({}, 1, 20);

      expect(result.items).toEqual(mockHistories);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should filter by patient_id', async () => {
      const mockHistories = [{ id: 'history-1', patient_id: 'patient-123' }];
      patientMedicalHistoryRepository.findMany.mockResolvedValue(mockHistories);
      patientMedicalHistoryRepository.count.mockResolvedValue(1);

      await listPatientMedicalHistories({ patient_id: 'patient-123' }, 1, 20);

      expect(patientMedicalHistoryRepository.findMany).toHaveBeenCalledWith(
        { patient_id: 'patient-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by condition', async () => {
      const mockHistories = [{ id: 'history-1', condition: 'Hypertension' }];
      patientMedicalHistoryRepository.findMany.mockResolvedValue(mockHistories);
      patientMedicalHistoryRepository.count.mockResolvedValue(1);

      await listPatientMedicalHistories({ condition: 'Hyper' }, 1, 20);

      expect(patientMedicalHistoryRepository.findMany).toHaveBeenCalledWith(
        { condition: { contains: 'Hyper', mode: 'insensitive' } },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle search query', async () => {
      const mockHistories = [{ id: 'history-1', condition: 'Diabetes' }];
      patientMedicalHistoryRepository.findMany.mockResolvedValue(mockHistories);
      patientMedicalHistoryRepository.count.mockResolvedValue(1);

      await listPatientMedicalHistories({ search: 'test' }, 1, 20);

      expect(patientMedicalHistoryRepository.findMany).toHaveBeenCalledWith(
        {
          OR: [
            { condition: { contains: 'test', mode: 'insensitive' } },
            { notes: { contains: 'test', mode: 'insensitive' } }
          ]
        },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should calculate pagination correctly', async () => {
      const mockHistories = [];
      patientMedicalHistoryRepository.findMany.mockResolvedValue(mockHistories);
      patientMedicalHistoryRepository.count.mockResolvedValue(45);

      const result = await listPatientMedicalHistories({}, 2, 20);

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 45,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true
      });
    });
  });

  describe('getPatientMedicalHistoryById', () => {
    it('should get patient medical history by ID', async () => {
      const mockHistory = { id: 'history-123', condition: 'Hypertension' };
      patientMedicalHistoryRepository.findById.mockResolvedValue(mockHistory);

      const result = await getPatientMedicalHistoryById('history-123');

      expect(result).toEqual(mockHistory);
      expect(patientMedicalHistoryRepository.findById).toHaveBeenCalledWith('history-123');
    });

    it('should return null if patient medical history not found', async () => {
      patientMedicalHistoryRepository.findById.mockResolvedValue(null);

      const result = await getPatientMedicalHistoryById('history-123');

      expect(result).toBeNull();
    });
  });

  describe('createPatientMedicalHistory', () => {
    it('should create new patient medical history', async () => {
      const newHistory = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        condition: 'Hypertension',
        diagnosis_date: new Date('2024-01-15')
      };
      const mockCreated = { id: 'history-123', ...newHistory };
      patientMedicalHistoryRepository.create.mockResolvedValue(mockCreated);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      const result = await createPatientMedicalHistory(newHistory, auditContext);

      expect(result).toEqual(mockCreated);
      expect(patientMedicalHistoryRepository.create).toHaveBeenCalledWith(newHistory);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'CREATE',
        entity: 'patient_medical_history',
        entity_id: 'history-123',
        diff: { after: mockCreated },
        ip: '127.0.0.1'
      });
    });

    it('should create audit log after creation', async () => {
      const newHistory = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        condition: 'Diabetes'
      };
      const mockCreated = { id: 'history-456', ...newHistory };
      patientMedicalHistoryRepository.create.mockResolvedValue(mockCreated);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-456', ip: '192.168.1.1' };
      await createPatientMedicalHistory(newHistory, auditContext);

      expect(createAuditLog).toHaveBeenCalledTimes(1);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'CREATE',
          entity: 'patient_medical_history',
          entity_id: 'history-456'
        })
      );
    });
  });

  describe('updatePatientMedicalHistory', () => {
    it('should update patient medical history', async () => {
      const updateData = { condition: 'Diabetes Type 2', notes: 'Updated' };
      const mockBefore = { id: 'history-123', condition: 'Diabetes' };
      const mockUpdated = { id: 'history-123', condition: 'Diabetes Type 2', notes: 'Updated' };
      patientMedicalHistoryRepository.findById.mockResolvedValue(mockBefore);
      patientMedicalHistoryRepository.update.mockResolvedValue(mockUpdated);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      const result = await updatePatientMedicalHistory('history-123', updateData, auditContext);

      expect(result).toEqual(mockUpdated);
      expect(patientMedicalHistoryRepository.update).toHaveBeenCalledWith('history-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'UPDATE',
        entity: 'patient_medical_history',
        entity_id: 'history-123',
        diff: { before: mockBefore, after: mockUpdated },
        ip: '127.0.0.1'
      });
    });

    it('should fetch before state for audit', async () => {
      const updateData = { condition: 'Updated Condition' };
      const mockBefore = { id: 'history-123', condition: 'Old Condition' };
      const mockUpdated = { id: 'history-123', condition: 'Updated Condition' };
      patientMedicalHistoryRepository.findById.mockResolvedValue(mockBefore);
      patientMedicalHistoryRepository.update.mockResolvedValue(mockUpdated);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      await updatePatientMedicalHistory('history-123', updateData, auditContext);

      expect(patientMedicalHistoryRepository.findById).toHaveBeenCalledWith('history-123');
    });
  });

  describe('deletePatientMedicalHistory', () => {
    it('should soft delete patient medical history', async () => {
      const mockBefore = { id: 'history-123', condition: 'Hypertension', deleted_at: null };
      const mockDeleted = { id: 'history-123', condition: 'Hypertension', deleted_at: new Date() };
      patientMedicalHistoryRepository.findById.mockResolvedValue(mockBefore);
      patientMedicalHistoryRepository.softDelete.mockResolvedValue(mockDeleted);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      const result = await deletePatientMedicalHistory('history-123', auditContext);

      expect(result).toEqual(mockDeleted);
      expect(patientMedicalHistoryRepository.softDelete).toHaveBeenCalledWith('history-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'DELETE',
        entity: 'patient_medical_history',
        entity_id: 'history-123',
        diff: { before: mockBefore, after: mockDeleted },
        ip: '127.0.0.1'
      });
    });

    it('should fetch before state for audit', async () => {
      const mockBefore = { id: 'history-123', condition: 'Diabetes' };
      const mockDeleted = { id: 'history-123', deleted_at: new Date() };
      patientMedicalHistoryRepository.findById.mockResolvedValue(mockBefore);
      patientMedicalHistoryRepository.softDelete.mockResolvedValue(mockDeleted);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      await deletePatientMedicalHistory('history-123', auditContext);

      expect(patientMedicalHistoryRepository.findById).toHaveBeenCalledWith('history-123');
    });
  });
});
