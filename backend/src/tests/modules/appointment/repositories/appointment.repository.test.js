/**
 * Appointment repository tests
 *
 * @module tests/modules/appointment/repositories
 * @description Tests for appointment repository
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const appointmentRepository = require('@repositories/appointment/appointment.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  appointment: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Appointment Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    const appointmentId = '550e8400-e29b-41d4-a716-446655440000';
    const mockAppointment = {
      id: appointmentId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'SCHEDULED',
      scheduled_start: new Date('2026-01-20T09:00:00.000Z'),
      scheduled_end: new Date('2026-01-20T10:00:00.000Z')
    };

    it('should find appointment by ID', async () => {
      prisma.appointment.findFirst.mockResolvedValue(mockAppointment);

      const result = await appointmentRepository.findById(appointmentId);

      expect(result).toEqual(mockAppointment);
      expect(prisma.appointment.findFirst).toHaveBeenCalledWith({
        where: { id: appointmentId, deleted_at: null },
        include: {}
      });
    });

    it('should return null if appointment not found', async () => {
      prisma.appointment.findFirst.mockResolvedValue(null);

      const result = await appointmentRepository.findById(appointmentId);

      expect(result).toBeNull();
    });

    it('should filter out soft-deleted appointments', async () => {
      prisma.appointment.findFirst.mockResolvedValue(null);

      await appointmentRepository.findById(appointmentId);

      expect(prisma.appointment.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ deleted_at: null })
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { participants: true };
      prisma.appointment.findFirst.mockResolvedValue(mockAppointment);

      await appointmentRepository.findById(appointmentId, include);

      expect(prisma.appointment.findFirst).toHaveBeenCalledWith({
        where: { id: appointmentId, deleted_at: null },
        include
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.appointment.findFirst.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentRepository.findById(appointmentId)).rejects.toThrow(HttpError);
      await expect(appointmentRepository.findById(appointmentId)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('findMany', () => {
    const mockAppointments = [
      {
        id: '550e8400-e29b-41d4-a716-446655440000',
        tenant_id: '550e8400-e29b-41d4-a716-446655440001',
        patient_id: '550e8400-e29b-41d4-a716-446655440002',
        status: 'SCHEDULED',
        scheduled_start: new Date('2026-01-20T09:00:00.000Z'),
        scheduled_end: new Date('2026-01-20T10:00:00.000Z')
      },
      {
        id: '550e8400-e29b-41d4-a716-446655440003',
        tenant_id: '550e8400-e29b-41d4-a716-446655440001',
        patient_id: '550e8400-e29b-41d4-a716-446655440004',
        status: 'CONFIRMED',
        scheduled_start: new Date('2026-01-21T10:00:00.000Z'),
        scheduled_end: new Date('2026-01-21T11:00:00.000Z')
      }
    ];

    it('should find many appointments with default params', async () => {
      prisma.appointment.findMany.mockResolvedValue(mockAppointments);

      const result = await appointmentRepository.findMany();

      expect(result).toEqual(mockAppointments);
      expect(prisma.appointment.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      const filters = { tenant_id: '550e8400-e29b-41d4-a716-446655440001', status: 'SCHEDULED' };
      prisma.appointment.findMany.mockResolvedValue(mockAppointments);

      await appointmentRepository.findMany(filters);

      expect(prisma.appointment.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { deleted_at: null, ...filters }
        })
      );
    });

    it('should apply pagination', async () => {
      prisma.appointment.findMany.mockResolvedValue(mockAppointments);

      await appointmentRepository.findMany({}, 20, 10);

      expect(prisma.appointment.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          skip: 20,
          take: 10
        })
      );
    });

    it('should apply custom ordering', async () => {
      const orderBy = { scheduled_start: 'asc' };
      prisma.appointment.findMany.mockResolvedValue(mockAppointments);

      await appointmentRepository.findMany({}, 0, 20, orderBy);

      expect(prisma.appointment.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          orderBy
        })
      );
    });

    it('should accept include parameter', async () => {
      const include = { participants: true, reminders: true };
      prisma.appointment.findMany.mockResolvedValue(mockAppointments);

      await appointmentRepository.findMany({}, 0, 20, { created_at: 'desc' }, include);

      expect(prisma.appointment.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          include
        })
      );
    });

    it('should throw HttpError on database error', async () => {
      prisma.appointment.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentRepository.findMany()).rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count appointments with filters', async () => {
      prisma.appointment.count.mockResolvedValue(5);

      const filters = { status: 'SCHEDULED' };
      const result = await appointmentRepository.count(filters);

      expect(result).toBe(5);
      expect(prisma.appointment.count).toHaveBeenCalledWith({
        where: { deleted_at: null, ...filters }
      });
    });

    it('should count all appointments with no filters', async () => {
      prisma.appointment.count.mockResolvedValue(10);

      const result = await appointmentRepository.count();

      expect(result).toBe(10);
      expect(prisma.appointment.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.appointment.count.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentRepository.count()).rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    const createData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'SCHEDULED',
      scheduled_start: new Date('2026-01-20T09:00:00.000Z'),
      scheduled_end: new Date('2026-01-20T10:00:00.000Z'),
      reason: 'General checkup'
    };

    it('should create appointment', async () => {
      const mockCreated = { id: '550e8400-e29b-41d4-a716-446655440000', ...createData };
      prisma.appointment.create.mockResolvedValue(mockCreated);

      const result = await appointmentRepository.create(createData);

      expect(result).toEqual(mockCreated);
      expect(prisma.appointment.create).toHaveBeenCalledWith({ data: createData });
    });

    it('should handle unique constraint violation', async () => {
      const error = {
        code: 'P2002',
        meta: { target: ['field_name'] }
      };
      prisma.appointment.create.mockRejectedValue(error);

      await expect(appointmentRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(appointmentRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should handle foreign key constraint violation', async () => {
      const error = {
        code: 'P2003',
        meta: { field_name: 'patient_id' }
      };
      prisma.appointment.create.mockRejectedValue(error);

      await expect(appointmentRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(appointmentRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should handle generic database error', async () => {
      prisma.appointment.create.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentRepository.create(createData)).rejects.toThrow(HttpError);
      await expect(appointmentRepository.create(createData)).rejects.toMatchObject({
        messageKey: 'errors.database.unexpected',
        statusCode: 500
      });
    });
  });

  describe('update', () => {
    const appointmentId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { status: 'CONFIRMED' };

    it('should update appointment', async () => {
      const mockUpdated = { id: appointmentId, ...updateData };
      prisma.appointment.update.mockResolvedValue(mockUpdated);

      const result = await appointmentRepository.update(appointmentId, updateData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.appointment.update).toHaveBeenCalledWith({
        where: { id: appointmentId },
        data: updateData
      });
    });

    it('should handle appointment not found', async () => {
      const error = { code: 'P2025' };
      prisma.appointment.update.mockRejectedValue(error);

      await expect(appointmentRepository.update(appointmentId, updateData)).rejects.toThrow(HttpError);
      await expect(appointmentRepository.update(appointmentId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.appointment.not_found',
        statusCode: 404
      });
    });

    it('should handle unique constraint violation', async () => {
      const error = {
        code: 'P2002',
        meta: { target: ['field_name'] }
      };
      prisma.appointment.update.mockRejectedValue(error);

      await expect(appointmentRepository.update(appointmentId, updateData)).rejects.toThrow(HttpError);
      await expect(appointmentRepository.update(appointmentId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.unique_field',
        statusCode: 409
      });
    });

    it('should handle foreign key constraint violation', async () => {
      const error = {
        code: 'P2003',
        meta: { field_name: 'patient_id' }
      };
      prisma.appointment.update.mockRejectedValue(error);

      await expect(appointmentRepository.update(appointmentId, updateData)).rejects.toThrow(HttpError);
      await expect(appointmentRepository.update(appointmentId, updateData)).rejects.toMatchObject({
        messageKey: 'errors.database.foreign_key_field',
        statusCode: 400
      });
    });

    it('should handle generic database error', async () => {
      prisma.appointment.update.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentRepository.update(appointmentId, updateData)).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    const appointmentId = '550e8400-e29b-41d4-a716-446655440000';

    it('should soft delete appointment', async () => {
      const mockDeleted = { id: appointmentId, deleted_at: new Date() };
      prisma.appointment.update.mockResolvedValue(mockDeleted);

      const result = await appointmentRepository.softDelete(appointmentId);

      expect(result).toEqual(mockDeleted);
      expect(prisma.appointment.update).toHaveBeenCalledWith({
        where: { id: appointmentId },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should handle appointment not found', async () => {
      const error = { code: 'P2025' };
      prisma.appointment.update.mockRejectedValue(error);

      await expect(appointmentRepository.softDelete(appointmentId)).rejects.toThrow(HttpError);
      await expect(appointmentRepository.softDelete(appointmentId)).rejects.toMatchObject({
        messageKey: 'errors.appointment.not_found',
        statusCode: 404
      });
    });

    it('should handle generic database error', async () => {
      prisma.appointment.update.mockRejectedValue(new Error('DB Error'));

      await expect(appointmentRepository.softDelete(appointmentId)).rejects.toThrow(HttpError);
    });
  });
});
