/**
 * Appointment service tests
 *
 * @module tests/modules/appointment/services
 * @description Tests for appointment service
 * Per testing.mdc: Mock repository, test business logic
 */

const appointmentService = require('@services/appointment/appointment.service');
const appointmentRepository = require('@repositories/appointment/appointment.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const opdFlowService = require('@services/opd-flow/opd-flow.service');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

// Mock dependencies
jest.mock('@repositories/appointment/appointment.repository');
jest.mock('@lib/audit');
jest.mock('@services/opd-flow/opd-flow.service', () => ({
  startOpdFlow: jest.fn(),
}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(),
  resolveModelRecordByIdentifier: jest.fn(),
}));

describe('Appointment Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    opdFlowService.startOpdFlow.mockResolvedValue({ encounter: { id: 'enc-1' } });
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

  describe('listAppointments', () => {
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

    it('should list appointments with pagination', async () => {
      appointmentRepository.findMany.mockResolvedValue(mockAppointments);
      appointmentRepository.count.mockResolvedValue(2);

      const result = await appointmentService.listAppointments({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(result).toHaveProperty('appointments', mockAppointments);
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
        tenant_id: '550e8400-e29b-41d4-a716-446655440001',
        status: 'SCHEDULED'
      };
      appointmentRepository.findMany.mockResolvedValue(mockAppointments);
      appointmentRepository.count.mockResolvedValue(2);

      await appointmentService.listAppointments(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(appointmentRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: filters.tenant_id,
          status: filters.status
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object),
        expect.any(Object)
      );
    });

    it('should apply search filter', async () => {
      const filters = { search: 'checkup' };
      appointmentRepository.findMany.mockResolvedValue(mockAppointments);
      appointmentRepository.count.mockResolvedValue(2);

      await appointmentService.listAppointments(filters, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(appointmentRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            expect.objectContaining({
              reason: { contains: 'checkup' }
            })
          ])
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object),
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      appointmentRepository.findMany.mockResolvedValue(mockAppointments);
      appointmentRepository.count.mockResolvedValue(42);

      const result = await appointmentService.listAppointments({}, 2, 10, null, 'asc', 'user-id', '127.0.0.1');

      expect(result.pagination).toMatchObject({
        page: 2,
        limit: 10,
        total: 42,
        totalPages: 5,
        hasNextPage: true,
        hasPreviousPage: true
      });
      expect(appointmentRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        10, // skip: (2-1) * 10
        10,
        expect.any(Object),
        expect.any(Object)
      );
    });

    it('should apply custom sorting', async () => {
      appointmentRepository.findMany.mockResolvedValue(mockAppointments);
      appointmentRepository.count.mockResolvedValue(2);

      await appointmentService.listAppointments({}, 1, 20, 'scheduled_start', 'asc', 'user-id', '127.0.0.1');

      expect(appointmentRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        { scheduled_start: 'asc' },
        expect.any(Object)
      );
    });

    it('should use default sorting when sortBy not provided', async () => {
      appointmentRepository.findMany.mockResolvedValue(mockAppointments);
      appointmentRepository.count.mockResolvedValue(2);

      await appointmentService.listAppointments({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1');

      expect(appointmentRepository.findMany).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        { created_at: 'asc' },
        expect.any(Object)
      );
    });

    it('should handle repository errors', async () => {
      appointmentRepository.findMany.mockRejectedValue(new Error('DB Error'));

      await expect(
        appointmentService.listAppointments({}, 1, 20, null, 'asc', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('getAppointmentById', () => {
    const appointmentId = '550e8400-e29b-41d4-a716-446655440000';
    const mockAppointment = {
      id: appointmentId,
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'SCHEDULED'
    };

    it('should get appointment by ID', async () => {
      appointmentRepository.findById.mockResolvedValue(mockAppointment);

      const result = await appointmentService.getAppointmentById(appointmentId, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockAppointment);
      expect(appointmentRepository.findById).toHaveBeenCalledWith(appointmentId, expect.any(Object));
    });

    it('should throw error if appointment not found', async () => {
      appointmentRepository.findById.mockResolvedValue(null);

      await expect(
        appointmentService.getAppointmentById(appointmentId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        appointmentService.getAppointmentById(appointmentId, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.appointment.not_found',
        statusCode: 404
      });
    });

    it('should handle repository errors', async () => {
      appointmentRepository.findById.mockRejectedValue(new Error('DB Error'));

      await expect(
        appointmentService.getAppointmentById(appointmentId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('createAppointment', () => {
    const createData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440001',
      patient_id: '550e8400-e29b-41d4-a716-446655440002',
      status: 'SCHEDULED',
      scheduled_start: new Date('2026-01-20T09:00:00.000Z'),
      scheduled_end: new Date('2026-01-20T10:00:00.000Z')
    };

    const mockCreated = {
      id: '550e8400-e29b-41d4-a716-446655440000',
      ...createData
    };

    it('should create appointment', async () => {
      appointmentRepository.create.mockResolvedValue(mockCreated);
      appointmentRepository.findById.mockResolvedValue(mockCreated);

      const result = await appointmentService.createAppointment(createData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockCreated);
      expect(appointmentRepository.create).toHaveBeenCalledWith(createData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'CREATE',
        entity: 'appointment',
        entity_id: mockCreated.id,
        diff: { after: mockCreated },
        ip_address: '127.0.0.1'
      });
    });

    it('should handle repository errors', async () => {
      appointmentRepository.create.mockRejectedValue(new Error('DB Error'));

      await expect(
        appointmentService.createAppointment(createData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });

    it('should not throw if audit log fails', async () => {
      appointmentRepository.create.mockResolvedValue(mockCreated);
      createAuditLog.mockRejectedValue(new Error('Audit Error'));

      const result = await appointmentService.createAppointment(createData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockCreated);
    });
  });

  describe('updateAppointment', () => {
    const appointmentId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { status: 'CONFIRMED' };
    const mockBefore = {
      id: appointmentId,
      status: 'SCHEDULED'
    };
      const mockAfter = {
        id: appointmentId,
        status: 'CONFIRMED'
      };

    it('should update appointment', async () => {
      appointmentRepository.findById
        .mockResolvedValueOnce(mockBefore)
        .mockResolvedValueOnce(mockAfter);
      appointmentRepository.update.mockResolvedValue(mockAfter);

      const result = await appointmentService.updateAppointment(appointmentId, updateData, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockAfter);
      expect(appointmentRepository.findById).toHaveBeenNthCalledWith(1, appointmentId, expect.any(Object));
      expect(appointmentRepository.findById).toHaveBeenNthCalledWith(2, appointmentId, expect.any(Object));
      expect(appointmentRepository.update).toHaveBeenCalledWith(appointmentId, updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'UPDATE',
        entity: 'appointment',
        entity_id: appointmentId,
        diff: { before: mockBefore, after: mockAfter },
        ip_address: '127.0.0.1'
      });
      expect(opdFlowService.startOpdFlow).not.toHaveBeenCalled();
    });

    it('should auto-start OPD flow when status transitions to IN_PROGRESS', async () => {
      const inProgressBefore = {
        id: appointmentId,
        status: 'CONFIRMED',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
      };
      const inProgressAfter = {
        ...inProgressBefore,
        status: 'IN_PROGRESS',
      };

      appointmentRepository.findById
        .mockResolvedValueOnce(inProgressBefore)
        .mockResolvedValueOnce(inProgressAfter);
      appointmentRepository.update.mockResolvedValue(inProgressAfter);

      const result = await appointmentService.updateAppointment(
        appointmentId,
        { status: 'IN_PROGRESS' },
        'user-id',
        '127.0.0.1'
      );

      expect(result).toEqual(inProgressAfter);
      expect(opdFlowService.startOpdFlow).toHaveBeenCalledWith(
        expect.objectContaining({
          appointment_id: appointmentId,
          arrival_mode: 'ONLINE_APPOINTMENT',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
        }),
        expect.objectContaining({
          user_id: 'user-id',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          ip_address: '127.0.0.1',
        })
      );
    });

    it('should not auto-start OPD flow when appointment was already IN_PROGRESS', async () => {
      const inProgressBefore = {
        id: appointmentId,
        status: 'IN_PROGRESS',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
      };
      const inProgressAfter = {
        ...inProgressBefore,
        reason: 'Updated note',
      };

      appointmentRepository.findById
        .mockResolvedValueOnce(inProgressBefore)
        .mockResolvedValueOnce(inProgressAfter);
      appointmentRepository.update.mockResolvedValue(inProgressAfter);

      await appointmentService.updateAppointment(
        appointmentId,
        { reason: 'Updated note' },
        'user-id',
        '127.0.0.1'
      );

      expect(opdFlowService.startOpdFlow).not.toHaveBeenCalled();
    });

    it('should keep appointment update successful when auto-start OPD fails', async () => {
      const inProgressBefore = {
        id: appointmentId,
        status: 'CONFIRMED',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
      };
      const inProgressAfter = {
        ...inProgressBefore,
        status: 'IN_PROGRESS',
      };

      appointmentRepository.findById
        .mockResolvedValueOnce(inProgressBefore)
        .mockResolvedValueOnce(inProgressAfter);
      appointmentRepository.update.mockResolvedValue(inProgressAfter);
      opdFlowService.startOpdFlow.mockRejectedValue(new Error('Auto-start failed'));

      await expect(
        appointmentService.updateAppointment(
          appointmentId,
          { status: 'IN_PROGRESS' },
          'user-id',
          '127.0.0.1'
        )
      ).resolves.toEqual(inProgressAfter);
    });

    it('should throw error if appointment not found', async () => {
      appointmentRepository.findById.mockResolvedValue(null);

      await expect(
        appointmentService.updateAppointment(appointmentId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        appointmentService.updateAppointment(appointmentId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.appointment.not_found',
        statusCode: 404
      });
    });

    it('should handle repository errors', async () => {
      appointmentRepository.findById.mockResolvedValue(mockBefore);
      appointmentRepository.update.mockRejectedValue(new Error('DB Error'));

      await expect(
        appointmentService.updateAppointment(appointmentId, updateData, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteAppointment', () => {
    const appointmentId = '550e8400-e29b-41d4-a716-446655440000';
    const mockBefore = {
      id: appointmentId,
      status: 'SCHEDULED'
    };

    it('should soft delete appointment', async () => {
      appointmentRepository.findById.mockResolvedValue(mockBefore);
      appointmentRepository.softDelete.mockResolvedValue({});

      await appointmentService.deleteAppointment(appointmentId, 'user-id', '127.0.0.1');

      expect(appointmentRepository.findById).toHaveBeenCalledWith(appointmentId, expect.any(Object));
      expect(appointmentRepository.softDelete).toHaveBeenCalledWith(appointmentId);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'DELETE',
        entity: 'appointment',
        entity_id: appointmentId,
        diff: { before: mockBefore },
        ip_address: '127.0.0.1'
      });
    });

    it('should throw error if appointment not found', async () => {
      appointmentRepository.findById.mockResolvedValue(null);

      await expect(
        appointmentService.deleteAppointment(appointmentId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        appointmentService.deleteAppointment(appointmentId, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.appointment.not_found',
        statusCode: 404
      });
    });

    it('should handle repository errors', async () => {
      appointmentRepository.findById.mockResolvedValue(mockBefore);
      appointmentRepository.softDelete.mockRejectedValue(new Error('DB Error'));

      await expect(
        appointmentService.deleteAppointment(appointmentId, 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });

  describe('cancelAppointment', () => {
    const appointmentId = '550e8400-e29b-41d4-a716-446655440000';
    const mockBefore = {
      id: appointmentId,
      status: 'SCHEDULED',
      reason: 'General checkup'
    };
    const mockAfter = {
      id: appointmentId,
      status: 'CANCELLED',
      reason: 'General checkup\nCancellation reason: Patient request'
    };

    it('should cancel appointment with reason', async () => {
      appointmentRepository.findById
        .mockResolvedValueOnce(mockBefore)
        .mockResolvedValueOnce(mockAfter);
      appointmentRepository.update.mockResolvedValue(mockAfter);

      const result = await appointmentService.cancelAppointment(appointmentId, 'Patient request', 'user-id', '127.0.0.1');

      expect(result).toEqual(mockAfter);
      expect(appointmentRepository.findById).toHaveBeenNthCalledWith(1, appointmentId, expect.any(Object));
      expect(appointmentRepository.findById).toHaveBeenNthCalledWith(2, appointmentId, expect.any(Object));
      expect(appointmentRepository.update).toHaveBeenCalledWith(appointmentId, {
        status: 'CANCELLED',
        reason: 'General checkup\nCancellation reason: Patient request'
      });
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'CANCEL',
        entity: 'appointment',
        entity_id: appointmentId,
        diff: { before: mockBefore, after: mockAfter },
        ip_address: '127.0.0.1'
      });
    });

    it('should cancel appointment without reason', async () => {
      const mockAfterNoReason = { ...mockBefore, status: 'CANCELLED' };
      appointmentRepository.findById
        .mockResolvedValueOnce(mockBefore)
        .mockResolvedValueOnce(mockAfterNoReason);
      appointmentRepository.update.mockResolvedValue(mockAfterNoReason);

      const result = await appointmentService.cancelAppointment(appointmentId, null, 'user-id', '127.0.0.1');

      expect(result).toEqual(mockAfterNoReason);
      expect(appointmentRepository.update).toHaveBeenCalledWith(appointmentId, {
        status: 'CANCELLED'
      });
    });

    it('should throw error if appointment not found', async () => {
      appointmentRepository.findById.mockResolvedValue(null);

      await expect(
        appointmentService.cancelAppointment(appointmentId, 'reason', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        appointmentService.cancelAppointment(appointmentId, 'reason', 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.appointment.not_found',
        statusCode: 404
      });
    });

    it('should throw error if appointment already cancelled', async () => {
      const mockCancelled = { ...mockBefore, status: 'CANCELLED' };
      appointmentRepository.findById.mockResolvedValue(mockCancelled);

      await expect(
        appointmentService.cancelAppointment(appointmentId, 'reason', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
      await expect(
        appointmentService.cancelAppointment(appointmentId, 'reason', 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.appointment.already_cancelled',
        statusCode: 400
      });
    });

    it('should handle repository errors', async () => {
      appointmentRepository.findById.mockResolvedValue(mockBefore);
      appointmentRepository.update.mockRejectedValue(new Error('DB Error'));

      await expect(
        appointmentService.cancelAppointment(appointmentId, 'reason', 'user-id', '127.0.0.1')
      ).rejects.toThrow(HttpError);
    });
  });
});
