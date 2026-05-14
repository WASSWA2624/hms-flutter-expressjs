/**
 * Patient Allergy service tests
 *
 * @module tests/modules/patient-allergy/services
 * Per testing.mdc: Mock all external dependencies
 */

// Mock dependencies
jest.mock('@repositories/patient-allergy/patient-allergy.repository');
jest.mock('@lib/audit');

const patientAllergyRepository = require('@repositories/patient-allergy/patient-allergy.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listPatientAllergies,
  getPatientAllergyById,
  createPatientAllergy,
  updatePatientAllergy,
  deletePatientAllergy
} = require('@services/patient-allergy/patient-allergy.service');

describe('Patient Allergy Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listPatientAllergies', () => {
    it('should list patient allergies with default pagination', async () => {
      const mockAllergies = [
        { id: 'allergy-1', patient_id: 'patient-123', allergen: 'Penicillin' },
        { id: 'allergy-2', patient_id: 'patient-123', allergen: 'Peanuts' }
      ];
      patientAllergyRepository.findMany.mockResolvedValue(mockAllergies);
      patientAllergyRepository.count.mockResolvedValue(10);

      const result = await listPatientAllergies({}, 1, 20);

      expect(result.items).toEqual(mockAllergies);
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
      const mockAllergies = [{ id: 'allergy-1', patient_id: 'patient-123' }];
      patientAllergyRepository.findMany.mockResolvedValue(mockAllergies);
      patientAllergyRepository.count.mockResolvedValue(1);

      await listPatientAllergies({ patient_id: 'patient-123' }, 1, 20);

      expect(patientAllergyRepository.findMany).toHaveBeenCalledWith(
        { patient_id: 'patient-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by severity', async () => {
      const mockAllergies = [{ id: 'allergy-1', severity: 'SEVERE' }];
      patientAllergyRepository.findMany.mockResolvedValue(mockAllergies);
      patientAllergyRepository.count.mockResolvedValue(1);

      await listPatientAllergies({ severity: 'SEVERE' }, 1, 20);

      expect(patientAllergyRepository.findMany).toHaveBeenCalledWith(
        { severity: 'SEVERE' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should search in allergen field', async () => {
      const mockAllergies = [{ id: 'allergy-1', allergen: 'Penicillin' }];
      patientAllergyRepository.findMany.mockResolvedValue(mockAllergies);
      patientAllergyRepository.count.mockResolvedValue(1);

      await listPatientAllergies({ allergen: 'Pen' }, 1, 20);

      expect(patientAllergyRepository.findMany).toHaveBeenCalledWith(
        { allergen: { contains: 'Pen', mode: 'insensitive' } },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle search query', async () => {
      const mockAllergies = [{ id: 'allergy-1', allergen: 'Penicillin' }];
      patientAllergyRepository.findMany.mockResolvedValue(mockAllergies);
      patientAllergyRepository.count.mockResolvedValue(1);

      await listPatientAllergies({ search: 'test' }, 1, 20);

      expect(patientAllergyRepository.findMany).toHaveBeenCalledWith(
        {
          OR: [
            { allergen: { contains: 'test', mode: 'insensitive' } },
            { reaction: { contains: 'test', mode: 'insensitive' } }
          ]
        },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should calculate pagination correctly', async () => {
      const mockAllergies = [];
      patientAllergyRepository.findMany.mockResolvedValue(mockAllergies);
      patientAllergyRepository.count.mockResolvedValue(45);

      const result = await listPatientAllergies({}, 2, 20);

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

  describe('getPatientAllergyById', () => {
    it('should get patient allergy by ID', async () => {
      const mockAllergy = { id: 'allergy-123', allergen: 'Penicillin' };
      patientAllergyRepository.findById.mockResolvedValue(mockAllergy);

      const result = await getPatientAllergyById('allergy-123');

      expect(result).toEqual(mockAllergy);
      expect(patientAllergyRepository.findById).toHaveBeenCalledWith('allergy-123');
    });

    it('should return null if patient allergy not found', async () => {
      patientAllergyRepository.findById.mockResolvedValue(null);

      const result = await getPatientAllergyById('allergy-123');

      expect(result).toBeNull();
    });
  });

  describe('createPatientAllergy', () => {
    it('should create new patient allergy', async () => {
      const newAllergy = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        allergen: 'Penicillin',
        severity: 'MODERATE',
        reaction: 'Rash'
      };
      const mockCreated = { id: 'allergy-123', ...newAllergy };
      patientAllergyRepository.create.mockResolvedValue(mockCreated);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      const result = await createPatientAllergy(newAllergy, auditContext);

      expect(result).toEqual(mockCreated);
      expect(patientAllergyRepository.create).toHaveBeenCalledWith(newAllergy);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'CREATE',
        entity: 'patient_allergy',
        entity_id: 'allergy-123',
        diff: { after: mockCreated },
        ip: '127.0.0.1'
      });
    });

    it('should create audit log after creation', async () => {
      const newAllergy = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        allergen: 'Peanuts',
        severity: 'SEVERE'
      };
      const mockCreated = { id: 'allergy-456', ...newAllergy };
      patientAllergyRepository.create.mockResolvedValue(mockCreated);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-456', ip: '192.168.1.1' };
      await createPatientAllergy(newAllergy, auditContext);

      expect(createAuditLog).toHaveBeenCalledTimes(1);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'CREATE',
          entity: 'patient_allergy',
          entity_id: 'allergy-456'
        })
      );
    });
  });

  describe('updatePatientAllergy', () => {
    it('should update patient allergy', async () => {
      const updateData = { severity: 'SEVERE', notes: 'Updated' };
      const mockBefore = { id: 'allergy-123', severity: 'MODERATE' };
      const mockUpdated = { id: 'allergy-123', severity: 'SEVERE', notes: 'Updated' };
      patientAllergyRepository.findById.mockResolvedValue(mockBefore);
      patientAllergyRepository.update.mockResolvedValue(mockUpdated);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      const result = await updatePatientAllergy('allergy-123', updateData, auditContext);

      expect(result).toEqual(mockUpdated);
      expect(patientAllergyRepository.update).toHaveBeenCalledWith('allergy-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'UPDATE',
        entity: 'patient_allergy',
        entity_id: 'allergy-123',
        diff: { before: mockBefore, after: mockUpdated },
        ip: '127.0.0.1'
      });
    });

    it('should fetch before state for audit', async () => {
      const updateData = { severity: 'MILD' };
      const mockBefore = { id: 'allergy-123', severity: 'MODERATE' };
      const mockUpdated = { id: 'allergy-123', severity: 'MILD' };
      patientAllergyRepository.findById.mockResolvedValue(mockBefore);
      patientAllergyRepository.update.mockResolvedValue(mockUpdated);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      await updatePatientAllergy('allergy-123', updateData, auditContext);

      expect(patientAllergyRepository.findById).toHaveBeenCalledWith('allergy-123');
    });
  });

  describe('deletePatientAllergy', () => {
    it('should soft delete patient allergy', async () => {
      const mockBefore = { id: 'allergy-123', allergen: 'Penicillin', deleted_at: null };
      const mockDeleted = { id: 'allergy-123', allergen: 'Penicillin', deleted_at: new Date() };
      patientAllergyRepository.findById.mockResolvedValue(mockBefore);
      patientAllergyRepository.softDelete.mockResolvedValue(mockDeleted);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      const result = await deletePatientAllergy('allergy-123', auditContext);

      expect(result).toEqual(mockDeleted);
      expect(patientAllergyRepository.softDelete).toHaveBeenCalledWith('allergy-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'DELETE',
        entity: 'patient_allergy',
        entity_id: 'allergy-123',
        diff: { before: mockBefore, after: mockDeleted },
        ip: '127.0.0.1'
      });
    });

    it('should fetch before state for audit', async () => {
      const mockBefore = { id: 'allergy-123', allergen: 'Peanuts' };
      const mockDeleted = { id: 'allergy-123', deleted_at: new Date() };
      patientAllergyRepository.findById.mockResolvedValue(mockBefore);
      patientAllergyRepository.softDelete.mockResolvedValue(mockDeleted);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      await deletePatientAllergy('allergy-123', auditContext);

      expect(patientAllergyRepository.findById).toHaveBeenCalledWith('allergy-123');
    });
  });
});
