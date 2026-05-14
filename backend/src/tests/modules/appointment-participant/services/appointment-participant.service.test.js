/**
 * Appointment participant service tests
 *
 * @module tests/modules/appointment-participant/services
 * @description Tests for appointment participant service
 * Per testing.mdc: Mock repository, test business logic
 */

const appointmentParticipantService = require('@services/appointment-participant/appointment-participant.service');
const appointmentParticipantRepository = require('@repositories/appointment-participant/appointment-participant.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

// Mock dependencies
jest.mock('@repositories/appointment-participant/appointment-participant.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(),
  resolveModelRecordByIdentifier: jest.fn(),
}));

describe('Appointment Participant Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveModelIdByIdentifier.mockImplementation(async ({ identifier }) => identifier);
    resolveModelRecordByIdentifier.mockImplementation(async ({ identifier, model }) => {
      if (!identifier) return null;
      if (model === 'appointment') {
        return {
          id: identifier,
          tenant_id: 'tenant-1',
        };
      }
      return { id: identifier };
    });
  });

  describe('listAppointmentParticipants', () => {
    const mockParticipants = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        appointment_id: '550e8400-e29b-41d4-a716-446655440001',
        role: 'Provider'
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440002',
        appointment_id: '550e8400-e29b-41d4-a716-446655440003',
        role: 'Assistant'
      }
    ];

    it('should list participants with pagination', async () => {
      appointmentParticipantRepository.findMany.mockResolvedValue(mockParticipants);
      appointmentParticipantRepository.count.mockResolvedValue(2);

      const result = await appointmentParticipantService.listAppointmentParticipants({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(result).toHaveProperty('participants', mockParticipants);
      expect(result).toHaveProperty('pagination');
      expect(result.pagination).toMatchObject({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply filters correctly', async () => {
      const filters = {
        appointment_id: '550e8400-e29b-41d4-a716-446655440001',
        role: 'Provider'
      };
      appointmentParticipantRepository.findMany.mockResolvedValue(mockParticipants);
      appointmentParticipantRepository.count.mockResolvedValue(2);

      await appointmentParticipantService.listAppointmentParticipants(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(appointmentParticipantRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          appointment_id: filters.appointment_id,
          role: { contains: filters.role }
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      appointmentParticipantRepository.findMany.mockResolvedValue(mockParticipants);
      appointmentParticipantRepository.count.mockResolvedValue(42);

      const result = await appointmentParticipantService.listAppointmentParticipants({}, 2, 10, null, 'asc', 'user-id', '127.0.0.1');

      expect(result.pagination).toMatchObject({
        page: 2,
        limit: 10,
        total: 42,
        totalPages: 5,
        hasNextPage: true,
        hasPreviousPage: true
      });
    });

    it('should handle repository errors', async () => {
      appointmentParticipantRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        appointmentParticipantService.listAppointmentParticipants({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getAppointmentParticipantById', () => {
    const participantId = '550e8400-e29b-41d4-a716-446655440000';
    const mockParticipant = {
      id: participantId,
      appointment_id: '550e8400-e29b-41d4-a716-446655440001',
      role: 'Provider'
    };

    it('should get participant by ID', async () => {
      appointmentParticipantRepository.findById.mockResolvedValue(mockParticipant);

      const result = await appointmentParticipantService.getAppointmentParticipantById(participantId, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockParticipant);
      expect(appointmentParticipantRepository.findById).toHaveBeenCalledWith(
        participantId,
        expect.any(Object)
      );
    });

    it('should throw error if participant not found', async () => {
      appointmentParticipantRepository.findById.mockResolvedValue(null);

      await expect(
        appointmentParticipantService.getAppointmentParticipantById(participantId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        appointmentParticipantService.getAppointmentParticipantById(participantId, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.appointment_participant.not_found',
        statusCode: 404
      });
    });
  });

  describe('createAppointmentParticipant', () => {
    const createData = {
      appointment_id: '550e8400-e29b-41d4-a716-446655440001',
      participant_user_id: '550e8400-e29b-41d4-a716-446655440002',
      role: 'Provider'
    };

    const mockCreated = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData
    };

    it('should create participant', async () => {
      appointmentParticipantRepository.create.mockResolvedValue(mockCreated);
      appointmentParticipantRepository.findById.mockResolvedValue(mockCreated);

      const result = await appointmentParticipantService.createAppointmentParticipant(createData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockCreated);
      expect(appointmentParticipantRepository.create).toHaveBeenCalledWith(createData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'CREATE',
        entity: 'appointment_participant',
        entity_id: mockCreated.id,
        diff: { after: mockCreated },
        ip_address: '127.0.0.1'
      });
    });

    it('should not throw if audit log fails', async () => {
      appointmentParticipantRepository.create.mockResolvedValue(mockCreated);
      createAuditLog.mockRejectedValue(new Error('Audit Error'));

      const result = await appointmentParticipantService.createAppointmentParticipant(createData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockCreated);
    });
  });

  describe('updateAppointmentParticipant', () => {
    const participantId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { role: 'Lead Provider' };
    const mockBefore = {
      id: participantId,
      role: 'Provider'
    };
    const mockAfter = {
      id: participantId,
      role: 'Lead Provider'
    };

    it('should update participant', async () => {
      appointmentParticipantRepository.findById
        .mockResolvedValueOnce(mockBefore)
        .mockResolvedValueOnce(mockAfter);
      appointmentParticipantRepository.update.mockResolvedValue(mockAfter);

      const result = await appointmentParticipantService.updateAppointmentParticipant(participantId, updateData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockAfter);
      expect(appointmentParticipantRepository.findById).toHaveBeenNthCalledWith(
        1,
        participantId,
        expect.any(Object)
      );
      expect(appointmentParticipantRepository.findById).toHaveBeenNthCalledWith(
        2,
        participantId,
        expect.any(Object)
      );
      expect(appointmentParticipantRepository.update).toHaveBeenCalledWith(participantId, updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'UPDATE',
        entity: 'appointment_participant',
        entity_id: participantId,
        diff: { before: mockBefore, after: mockAfter },
        ip_address: '127.0.0.1'
      });
    });

    it('should throw error if participant not found', async () => {
      appointmentParticipantRepository.findById.mockResolvedValue(null);

      await expect(
        appointmentParticipantService.updateAppointmentParticipant(participantId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteAppointmentParticipant', () => {
    const participantId = '550e8400-e29b-41d4-a716-446655440000';
    const mockBefore = {
      id: participantId,
      role: 'Provider'
    };

    it('should soft delete participant', async () => {
      appointmentParticipantRepository.findById.mockResolvedValue(mockBefore);
      appointmentParticipantRepository.softDelete.mockResolvedValue({});

      await appointmentParticipantService.deleteAppointmentParticipant(participantId, 'user-id', '127.0.0.1');

      expect(appointmentParticipantRepository.findById).toHaveBeenCalledWith(
        participantId,
        expect.any(Object)
      );
      expect(appointmentParticipantRepository.softDelete).toHaveBeenCalledWith(participantId);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'DELETE',
        entity: 'appointment_participant',
        entity_id: participantId,
        diff: { before: mockBefore },
        ip_address: '127.0.0.1'
      });
    });

    it('should throw error if participant not found', async () => {
      appointmentParticipantRepository.findById.mockResolvedValue(null);

      await expect(
        appointmentParticipantService.deleteAppointmentParticipant(participantId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });
});
