/**
 * Anesthesia record service tests
 *
 * @module tests/modules/anesthesia-record/services
 * @description Tests for anesthesia record business logic
 */

const anesthesiaRecordService = require('@services/anesthesia-record/anesthesia-record.service');
const anesthesiaRecordRepository = require('@repositories/anesthesia-record/anesthesia-record.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

jest.mock('@repositories/anesthesia-record/anesthesia-record.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(),
  resolveModelRecordByIdentifier: jest.fn(),
}));

describe('Anesthesia record Service', () => {
  const userId = 'user-123';
  const ipAddress = '127.0.0.1';
  const recordId = '550e8400-e29b-41d4-a716-446655440000';
  const theatreCaseId = '550e8400-e29b-41d4-a716-446655440001';
  const encounterId = '550e8400-e29b-41d4-a716-446655440002';
  const patientId = '550e8400-e29b-41d4-a716-446655440003';
  const anesthetistUserId = '550e8400-e29b-41d4-a716-446655440004';

  const mockAnesthesiaRecord = {
    id: recordId,
    human_friendly_id: 'ANR0001',
    theatre_case_id: theatreCaseId,
    anesthetist_user_id: anesthetistUserId,
    notes: 'Test notes',
    record_status: 'DRAFT',
    theatre_case: {
      id: theatreCaseId,
      human_friendly_id: 'TC0001',
      encounter: {
        id: encounterId,
        human_friendly_id: 'ENC0001',
        tenant_id: 'tenant-1',
        patient: {
          id: patientId,
          human_friendly_id: 'PAT0001',
          first_name: 'John',
          last_name: 'Doe',
        },
      },
    },
    anesthetist: {
      id: anesthetistUserId,
      human_friendly_id: 'USR0001',
      profile: {
        first_name: 'Jane',
        middle_name: 'Q',
        last_name: 'Public',
      },
      staff_profile: {
        human_friendly_id: 'STF0001',
      },
    },
  };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveModelIdByIdentifier.mockImplementation(async ({ identifier }) => identifier);
    resolveModelRecordByIdentifier.mockImplementation(async ({ identifier }) =>
      identifier ? { id: identifier } : null
    );
  });

  describe('listAnesthesiaRecords', () => {
    it('should list anesthesia records with pagination', async () => {
      anesthesiaRecordRepository.findMany.mockResolvedValue([mockAnesthesiaRecord]);
      anesthesiaRecordRepository.count.mockResolvedValue(1);

      const result = await anesthesiaRecordService.listAnesthesiaRecords(
        {},
        1,
        20,
        'created_at',
        'desc',
        userId,
        ipAddress
      );

      expect(result.anesthesia_records).toEqual([
        expect.objectContaining({
          id: recordId,
          display_id: 'ANR0001',
          theatre_case_display_id: 'TC0001',
          encounter_display_id: 'ENC0001',
          patient_display_id: 'PAT0001',
          patient_display_name: 'John Doe',
          anesthetist_user_display_id: 'USR0001',
          staff_profile_display_id: 'STF0001',
          anesthetist_display_name: 'Jane Q Public',
          record_status: 'DRAFT',
        }),
      ]);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false,
      });
    });

    it('should apply theatre_case_id filter', async () => {
      anesthesiaRecordRepository.findMany.mockResolvedValue([mockAnesthesiaRecord]);
      anesthesiaRecordRepository.count.mockResolvedValue(1);

      await anesthesiaRecordService.listAnesthesiaRecords(
        { theatre_case_id: theatreCaseId },
        1,
        20,
        null,
        'asc',
        userId,
        ipAddress
      );

      expect(anesthesiaRecordRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          theatre_case_id: theatreCaseId,
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should apply anesthetist_user_id filter', async () => {
      anesthesiaRecordRepository.findMany.mockResolvedValue([mockAnesthesiaRecord]);
      anesthesiaRecordRepository.count.mockResolvedValue(1);

      await anesthesiaRecordService.listAnesthesiaRecords(
        { anesthetist_user_id: anesthetistUserId },
        1,
        20,
        null,
        'asc',
        userId,
        ipAddress
      );

      expect(anesthesiaRecordRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          anesthetist_user_id: anesthetistUserId,
        }),
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle empty filters', async () => {
      anesthesiaRecordRepository.findMany.mockResolvedValue([mockAnesthesiaRecord]);
      anesthesiaRecordRepository.count.mockResolvedValue(1);

      await anesthesiaRecordService.listAnesthesiaRecords({}, 1, 20, null, 'asc', userId, ipAddress);

      expect(anesthesiaRecordRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should calculate pagination correctly', async () => {
      anesthesiaRecordRepository.findMany.mockResolvedValue([mockAnesthesiaRecord]);
      anesthesiaRecordRepository.count.mockResolvedValue(45);

      const result = await anesthesiaRecordService.listAnesthesiaRecords(
        {},
        2,
        20,
        null,
        'asc',
        userId,
        ipAddress
      );

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 45,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true,
      });
    });

    it('should throw HttpError on repository error', async () => {
      anesthesiaRecordRepository.findMany.mockRejectedValue(new Error('Database error'));

      await expect(
        anesthesiaRecordService.listAnesthesiaRecords({}, 1, 20, null, 'asc', userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getAnesthesiaRecordById', () => {
    it('should get anesthesia record by id', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce({ id: recordId });
      anesthesiaRecordRepository.findById.mockResolvedValue(mockAnesthesiaRecord);

      const result = await anesthesiaRecordService.getAnesthesiaRecordById(
        recordId,
        userId,
        ipAddress
      );

      expect(result).toEqual(
        expect.objectContaining({
          id: recordId,
          display_id: 'ANR0001',
          patient_display_name: 'John Doe',
        })
      );
      expect(anesthesiaRecordRepository.findById).toHaveBeenCalledWith(recordId);
    });

    it('should throw HttpError when anesthesia record not found', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce(null);

      await expect(
        anesthesiaRecordService.getAnesthesiaRecordById('non-existent-id', userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce({ id: 'some-id' });
      anesthesiaRecordRepository.findById.mockRejectedValue(new Error('Database error'));

      await expect(
        anesthesiaRecordService.getAnesthesiaRecordById('some-id', userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createAnesthesiaRecord', () => {
    const createData = {
      theatre_case_id: theatreCaseId,
      anesthetist_user_id: anesthetistUserId,
      notes: 'Test notes',
    };

    it('should create anesthesia record', async () => {
      anesthesiaRecordRepository.create.mockResolvedValue(mockAnesthesiaRecord);
      anesthesiaRecordRepository.findById.mockResolvedValue(mockAnesthesiaRecord);

      const result = await anesthesiaRecordService.createAnesthesiaRecord(
        createData,
        userId,
        ipAddress
      );

      expect(result).toEqual(
        expect.objectContaining({
          id: recordId,
          display_id: 'ANR0001',
          record_status: 'DRAFT',
        })
      );
      expect(anesthesiaRecordRepository.create).toHaveBeenCalledWith({
        ...createData,
        record_status: 'DRAFT',
      });
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: 'tenant-1',
        user_id: userId,
        action: 'CREATE',
        entity: 'anesthesia_record',
        entity_id: recordId,
        diff: { after: mockAnesthesiaRecord },
        ip_address: ipAddress,
      });
    });

    it('should throw HttpError on repository error', async () => {
      anesthesiaRecordRepository.create.mockRejectedValue(new Error('Database error'));

      await expect(
        anesthesiaRecordService.createAnesthesiaRecord(createData, userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should propagate HttpError from repository', async () => {
      const httpError = new HttpError('errors.database.foreign_key_field', 400);
      anesthesiaRecordRepository.create.mockRejectedValue(httpError);

      await expect(
        anesthesiaRecordService.createAnesthesiaRecord(createData, userId, ipAddress)
      ).rejects.toThrow(httpError);
    });
  });

  describe('updateAnesthesiaRecord', () => {
    it('should update anesthesia record', async () => {
      const updatedRecord = {
        ...mockAnesthesiaRecord,
        record_status: 'FINALIZED',
      };

      resolveModelRecordByIdentifier.mockResolvedValueOnce({ id: recordId });
      anesthesiaRecordRepository.findById
        .mockResolvedValueOnce(mockAnesthesiaRecord)
        .mockResolvedValueOnce(updatedRecord);
      anesthesiaRecordRepository.update.mockResolvedValue(updatedRecord);

      const result = await anesthesiaRecordService.updateAnesthesiaRecord(
        recordId,
        { record_status: 'FINALIZED' },
        userId,
        ipAddress
      );

      expect(result).toEqual(
        expect.objectContaining({
          id: recordId,
          record_status: 'FINALIZED',
        })
      );
      expect(anesthesiaRecordRepository.update).toHaveBeenCalledWith(recordId, {
        record_status: 'FINALIZED',
      });
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: 'tenant-1',
        user_id: userId,
        action: 'UPDATE',
        entity: 'anesthesia_record',
        entity_id: recordId,
        diff: {
          before: mockAnesthesiaRecord,
          after: updatedRecord,
        },
        ip_address: ipAddress,
      });
    });

    it('should throw HttpError when anesthesia record not found', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce(null);

      await expect(
        anesthesiaRecordService.updateAnesthesiaRecord(
          'non-existent-id',
          { record_status: 'FINALIZED' },
          userId,
          ipAddress
        )
      ).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce({ id: recordId });
      anesthesiaRecordRepository.findById.mockResolvedValueOnce(mockAnesthesiaRecord);
      anesthesiaRecordRepository.update.mockRejectedValue(new Error('Database error'));

      await expect(
        anesthesiaRecordService.updateAnesthesiaRecord(
          recordId,
          { record_status: 'FINALIZED' },
          userId,
          ipAddress
        )
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteAnesthesiaRecord', () => {
    it('should delete anesthesia record', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce({ id: recordId });
      anesthesiaRecordRepository.findById.mockResolvedValue(mockAnesthesiaRecord);
      anesthesiaRecordRepository.softDelete.mockResolvedValue(mockAnesthesiaRecord);

      await anesthesiaRecordService.deleteAnesthesiaRecord(recordId, userId, ipAddress);

      expect(anesthesiaRecordRepository.findById).toHaveBeenCalledWith(recordId);
      expect(anesthesiaRecordRepository.softDelete).toHaveBeenCalledWith(recordId);
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: 'tenant-1',
        user_id: userId,
        action: 'DELETE',
        entity: 'anesthesia_record',
        entity_id: recordId,
        diff: { before: mockAnesthesiaRecord },
        ip_address: ipAddress,
      });
    });

    it('should throw HttpError when anesthesia record not found', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce(null);

      await expect(
        anesthesiaRecordService.deleteAnesthesiaRecord('non-existent-id', userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      resolveModelRecordByIdentifier.mockResolvedValueOnce({ id: recordId });
      anesthesiaRecordRepository.findById.mockResolvedValueOnce(mockAnesthesiaRecord);
      anesthesiaRecordRepository.softDelete.mockRejectedValue(new Error('Database error'));

      await expect(
        anesthesiaRecordService.deleteAnesthesiaRecord(recordId, userId, ipAddress)
      ).rejects.toThrow(HttpError);
    });
  });
});
