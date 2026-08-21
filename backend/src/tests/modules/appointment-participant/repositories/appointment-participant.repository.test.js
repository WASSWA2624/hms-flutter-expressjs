/**
 * Appointment participant repository tests
 *
 * @module tests/modules/appointment-participant/repositories
 * @description Tests for appointment participant repository
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const appointmentParticipantRepository = require('@repositories/appointment-participant/appointment-participant.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  appointment_participant: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Appointment Participant Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const participantId = '550e8400-e29b-41d4-a716-446655440000';
    const mockParticipant = {
      id: participantId,
      appointment_id: '550e8400-e29b-41d4-a716-446655440001',
      participant_user_id: '550e8400-e29b-41d4-a716-446655440002',
      role: 'Provider'
    };

    it('should find participant by ID', async () => {
      prisma.appointment_participant.findFirst.mockResolvedValue(mockParticipant);

      const result = await appointmentParticipantRepository.findById(participantId);

      expect(result).toEqual(mockParticipant);
      expect(prisma.appointment_participant.findFirst).toHaveBeenCalledWith({
        where: { id: participantId, deleted_at: null },
        include: {}
      });
    });

    it('should return null if participant not found', async () => {
      prisma.appointment_participant.findFirst.mockResolvedValue(null);

      const result = await appointmentParticipantRepository.findById(participantId);

      expect(result).toBeNull();
    });

    it('should filter out soft-deleted participants', async () => {
      prisma.appointment_participant.findFirst.mockResolvedValue(null);

      await appointmentParticipantRepository.findById(participantId);

      expect(prisma.appointment_participant.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { appointment: true };
      prisma.appointment_participant.findFirst.mockResolvedValue(mockParticipant);

      await appointmentParticipantRepository.findById(participantId, include);

      expect(prisma.appointment_participant.findFirst).toHaveBeenCalledWith({
        where: { id: participantId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.appointment_participant.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentParticipantRepository.findById(participantId)).rejects.toThrow(HttpError);
      await expect(appointmentParticipantRepository.findById(participantId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('findMany', () => {
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

    it('should find many participants with default params', async () => {
      prisma.appointment_participant.findMany.mockResolvedValue(mockParticipants);

      const result = await appointmentParticipantRepository.findMany();

      expect(result).toEqual(mockParticipants);
      expect(prisma.appointment_participant.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      const filters = { appointment_id: '550e8400-e29b-41d4-a716-446655440001' };
      prisma.appointment_participant.findMany.mockResolvedValue(mockParticipants);

      await appointmentParticipantRepository.findMany(filters);

      expect(prisma.appointment_participant.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, ...filters }
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.appointment_participant.findMany.mockResolvedValue(mockParticipants);

      await appointmentParticipantRepository.findMany({}, 20, 10);

      expect(prisma.appointment_participant.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 20,
          take: 10
        })
      );
    });

    it('should apply custom ordering', async () => {
      const orderBy = { role: 'asc' };
      prisma.appointment_participant.findMany.mockResolvedValue(mockParticipants);

      await appointmentParticipantRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.appointment_participant.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          orderBy
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.appointment_participant.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentParticipantRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count participants with filters', async () => {
      prisma.appointment_participant.count.mockResolvedValue(5);

      const filters = { appointment_id: '550e8400-e29b-41d4-a716-446655440000' };
      const result = await appointmentParticipantRepository.count(filters);

      expect(result).toBe(5);
      expect(prisma.appointment_participant.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.appointment_participant.count.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentParticipantRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    const createData = {
      appointment_id: '550e8400-e29b-41d4-a716-446655440001',
      participant_user_id: '550e8400-e29b-41d4-a716-446655440002',
      role: 'Provider'
    };

    it('should create participant', async () => {
      const mockCreated = { id: '550e8400-e29b-41d4-a716-446655440000', ...createData };
      prisma.appointment_participant.create.mockResolvedValue(mockCreated);

      const result = await appointmentParticipantRepository.create(createData);

      expect(result).toEqual(mockCreated);
      expect(prisma.appointment_participant.create).toHaveBeenCalledWith({ data: createData });
    });

    it('should handle unique constraint violation', async () => {
      const error = {
        code: 'P2002',
        meta: { target: ['field_name'] }
      };
      prisma.appointment_participant.create.mockRejectedValue(error);

      await expect(appointmentParticipantRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(appointmentParticipantRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should handle foreign key constraint violation', async () => {
      const error = {
        code: 'P2003',
        meta: { field_name: 'appointment_id' }
      };
      prisma.appointment_participant.create.mockRejectedValue(error);

      await expect(appointmentParticipantRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(appointmentParticipantRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should handle generic database error', async () => {
      prisma.appointment_participant.create.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentParticipantRepository.create(createData)).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    const participantId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { role: 'Lead Provider' };

    it('should update participant', async () => {
      const mockUpdated = { id: participantId, ...updateData };
      prisma.appointment_participant.update.mockResolvedValue(mockUpdated);

      const result = await appointmentParticipantRepository.update(participantId, updateData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.appointment_participant.update).toHaveBeenCalledWith({
        where: { id: participantId },
        data: updateData
      });
    });

    it('should handle participant not found', async () => {
      const error = { code: 'P2025' };
      prisma.appointment_participant.update.mockRejectedValue(error);

      await expect(appointmentParticipantRepository.update(participantId, updateData)).rejects.toThrow(HttpError);
      await expect(appointmentParticipantRepository.update(participantId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.appointment_participant.not_found',
        statusCode: 404
      });
    });

    it('should handle generic database error', async () => {
      prisma.appointment_participant.update.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentParticipantRepository.update(participantId, updateData)).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    const participantId = '550e8400-e29b-41d4-a716-446655440000';

    it('should soft delete participant', async () => {
      const mockDeleted = { id: participantId, deleted_at: new Date() };
      prisma.appointment_participant.update.mockResolvedValue(mockDeleted);

      const result = await appointmentParticipantRepository.softDelete(participantId);

      expect(result).toEqual(mockDeleted);
      expect(prisma.appointment_participant.update).toHaveBeenCalledWith({
        where: { id: participantId },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should handle participant not found', async () => {
      const error = { code: 'P2025' };
      prisma.appointment_participant.update.mockRejectedValue(error);

      await expect(appointmentParticipantRepository.softDelete(participantId)).rejects.toThrow(HttpError);
      await expect(appointmentParticipantRepository.softDelete(participantId)).rejects.toMatchObject({
        messageKey: 'errors.appointment_participant.not_found',
        statusCode: 404
      });
    });

    it('should handle generic database error', async () => {
      prisma.appointment_participant.update.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentParticipantRepository.softDelete(participantId)).rejects.toThrow(HttpError);
    });
  });
});
