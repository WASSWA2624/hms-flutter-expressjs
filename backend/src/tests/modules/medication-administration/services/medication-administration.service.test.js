/**
 * Medication administration service tests
 *
 * @module tests/modules/medication-administration/services
 * Per testing.mdc: Mock all repository and external dependencies
 */

const { HttpError } = require('@lib/errors');

jest.mock('@repositories/medication-administration/medication-administration.repository');
jest.mock('@lib/audit');

const medicationAdministrationRepository = require('@repositories/medication-administration/medication-administration.repository');
const { createAuditLog } = require('@lib/audit');
const medicationAdministrationService = require('@services/medication-administration/medication-administration.service');

describe('Medication Administration Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockReturnValue(Promise.resolve());
  });

  describe('listMedicationAdministrations', () => {
    it('should list with pagination', async () => {
      const mockRecords = [{ id: 'med-1' }, { id: 'med-2' }];
      medicationAdministrationRepository.findMany.mockResolvedValue(mockRecords);
      medicationAdministrationRepository.count.mockResolvedValue(10);

      const result = await medicationAdministrationService.listMedicationAdministrations(
        {},
        1,
        20,
        'created_at',
        'desc',
        'user-123',
        '127.0.0.1'
      );

      expect(result.medicationAdministrations).toEqual(mockRecords);
      expect(result.pagination.total).toBe(10);
    });
  });

  describe('getMedicationAdministrationById', () => {
    it('should get by ID', async () => {
      const mockRecord = { id: 'med-123', dose: '500mg' };
      medicationAdministrationRepository.findById.mockResolvedValue(mockRecord);

      const result = await medicationAdministrationService.getMedicationAdministrationById(
        'med-123',
        'user-123',
        '127.0.0.1'
      );

      expect(result).toEqual(mockRecord);
    });

    it('should throw HttpError if not found', async () => {
      medicationAdministrationRepository.findById.mockResolvedValue(null);

      await expect(
        medicationAdministrationService.getMedicationAdministrationById('med-123', 'user-123', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createMedicationAdministration', () => {
    it('should create and audit log', async () => {
      const mockData = { admission_id: 'admission-123', dose: '500mg', route: 'ORAL' };
      const mockRecord = { id: 'med-123', ...mockData };
      medicationAdministrationRepository.create.mockResolvedValue(mockRecord);

      const result = await medicationAdministrationService.createMedicationAdministration(
        mockData,
        'user-123',
        '127.0.0.1'
      );

      expect(result).toEqual(mockRecord);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'CREATE',
          entity: 'medication_administration'
        })
      );
    });
  });

  describe('updateMedicationAdministration', () => {
    it('should update and audit log', async () => {
      const mockBefore = { id: 'med-123', dose: '500mg' };
      const mockAfter = { id: 'med-123', dose: '1000mg' };
      medicationAdministrationRepository.findById.mockResolvedValue(mockBefore);
      medicationAdministrationRepository.update.mockResolvedValue(mockAfter);

      const result = await medicationAdministrationService.updateMedicationAdministration(
        'med-123',
        { dose: '1000mg' },
        'user-123',
        '127.0.0.1'
      );

      expect(result).toEqual(mockAfter);
      expect(createAuditLog).toHaveBeenCalled();
    });
  });

  describe('deleteMedicationAdministration', () => {
    it('should delete and audit log', async () => {
      const mockRecord = { id: 'med-123', dose: '500mg' };
      medicationAdministrationRepository.findById.mockResolvedValue(mockRecord);
      medicationAdministrationRepository.softDelete.mockResolvedValue(mockRecord);

      await medicationAdministrationService.deleteMedicationAdministration('med-123', 'user-123', '127.0.0.1');

      expect(medicationAdministrationRepository.softDelete).toHaveBeenCalled();
      expect(createAuditLog).toHaveBeenCalled();
    });
  });
});
