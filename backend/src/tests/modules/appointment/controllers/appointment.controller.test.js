/**
 * Appointment controller tests
 *
 * @module tests/modules/appointment/controllers
 * @description Tests for appointment controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

const appointmentController = require('@controllers/appointment/appointment.controller');
const appointmentService = require('@services/appointment/appointment.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

// Mock dependencies
jest.mock('@services/appointment/appointment.service');
jest.mock('@lib/response');

describe('Appointment Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'requester-id' },
      ip: '127.0.0.1'
    };

    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis()
    };
  });

  describe('listAppointments', () => {
    const mockResult = {
      appointments: [
        { 
          id: '1', 
          patient_id: '550e8400-e29b-41d4-a716-446655440000',
          status: 'SCHEDULED' 
        },
        { 
          id: '2', 
          patient_id: '550e8400-e29b-41d4-a716-446655440001',
          status: 'CONFIRMED' 
        }
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

    it('should list appointments with default pagination', async () => {
      appointmentService.listAppointments.mockResolvedValue(mockResult);

      await appointmentController.listAppointments(req, res);

      expect(appointmentService.listAppointments).toHaveBeenCalledWith(
        expect.any(Object),
        DEFAULT_PAGE,
        DEFAULT_PAGE_LIMIT,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.appointment.list.success',
        mockResult.appointments,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      req.query = {
        tenant_id: '550e8400-e29b-41d4-a716-446655440000',
        facility_id: '550e8400-e29b-41d4-a716-446655440001',
        patient_id: '550e8400-e29b-41d4-a716-446655440002',
        provider_user_id: '550e8400-e29b-41d4-a716-446655440003',
        status: 'SCHEDULED',
        search: 'checkup',
        page: '2',
        limit: '10',
        sort_by: 'scheduled_start',
        order: 'asc'
      };
      appointmentService.listAppointments.mockResolvedValue(mockResult);

      await appointmentController.listAppointments(req, res);

      expect(appointmentService.listAppointments).toHaveBeenCalledWith(
        {
          tenant_id: '550e8400-e29b-41d4-a716-446655440000',
          facility_id: '550e8400-e29b-41d4-a716-446655440001',
          patient_id: '550e8400-e29b-41d4-a716-446655440002',
          provider_user_id: '550e8400-e29b-41d4-a716-446655440003',
          status: 'SCHEDULED',
          search: 'checkup'
        },
        2,
        10,
        'scheduled_start',
        'asc',
        'requester-id',
        '127.0.0.1'
      );
    });

    it('should handle missing user in request', async () => {
      req.user = undefined;
      appointmentService.listAppointments.mockResolvedValue(mockResult);

      await appointmentController.listAppointments(req, res);

      expect(appointmentService.listAppointments).toHaveBeenCalledWith(
        expect.any(Object),
        expect.any(Number),
        expect.any(Number),
        undefined,
        'asc',
        undefined,
        '127.0.0.1'
      );
    });

    it('should handle service errors', async () => {
      const error = new Error('Service error');
      appointmentService.listAppointments.mockRejectedValue(error);

      await expect(appointmentController.listAppointments(req, res)).rejects.toThrow(error);
    });
  });

  describe('getAppointmentById', () => {
    const appointmentId = '550e8400-e29b-41d4-a716-446655440000';
    const mockAppointment = {
      id: appointmentId,
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'SCHEDULED'
    };

    it('should get appointment by ID', async () => {
      req.params = { id: appointmentId };
      appointmentService.getAppointmentById.mockResolvedValue(mockAppointment);

      await appointmentController.getAppointmentById(req, res);

      expect(appointmentService.getAppointmentById).toHaveBeenCalledWith(
        appointmentId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.appointment.get.success',
        mockAppointment
      );
    });

    it('should handle service errors', async () => {
      req.params = { id: appointmentId };
      const error = new Error('Service error');
      appointmentService.getAppointmentById.mockRejectedValue(error);

      await expect(appointmentController.getAppointmentById(req, res)).rejects.toThrow(error);
    });
  });

  describe('createAppointment', () => {
    const createData = {
      tenant_id: '550e8400-e29b-41d4-a716-446655440000',
      patient_id: '550e8400-e29b-41d4-a716-446655440001',
      status: 'SCHEDULED',
      scheduled_start: '2026-01-20T09:00:00.000Z',
      scheduled_end: '2026-01-20T10:00:00.000Z'
    };

    const mockCreated = {
      id: '550e8400-e29b-41d4-a716-446655440002',
      ...createData
    };

    it('should create appointment', async () => {
      req.body = createData;
      appointmentService.createAppointment.mockResolvedValue(mockCreated);

      await appointmentController.createAppointment(req, res);

      expect(appointmentService.createAppointment).toHaveBeenCalledWith(
        createData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.appointment.create.success',
        mockCreated
      );
    });

    it('should handle service errors', async () => {
      req.body = createData;
      const error = new Error('Service error');
      appointmentService.createAppointment.mockRejectedValue(error);

      await expect(appointmentController.createAppointment(req, res)).rejects.toThrow(error);
    });
  });

  describe('updateAppointment', () => {
    const appointmentId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { status: 'CONFIRMED' };
    const mockUpdated = {
      id: appointmentId,
      status: 'CONFIRMED'
    };

    it('should update appointment', async () => {
      req.params = { id: appointmentId };
      req.body = updateData;
      appointmentService.updateAppointment.mockResolvedValue(mockUpdated);

      await appointmentController.updateAppointment(req, res);

      expect(appointmentService.updateAppointment).toHaveBeenCalledWith(
        appointmentId,
        updateData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.appointment.update.success',
        mockUpdated
      );
    });

    it('should handle service errors', async () => {
      req.params = { id: appointmentId };
      req.body = updateData;
      const error = new Error('Service error');
      appointmentService.updateAppointment.mockRejectedValue(error);

      await expect(appointmentController.updateAppointment(req, res)).rejects.toThrow(error);
    });
  });

  describe('deleteAppointment', () => {
    const appointmentId = '550e8400-e29b-41d4-a716-446655440000';

    it('should delete appointment', async () => {
      req.params = { id: appointmentId };
      appointmentService.deleteAppointment.mockResolvedValue();

      await appointmentController.deleteAppointment(req, res);

      expect(appointmentService.deleteAppointment).toHaveBeenCalledWith(
        appointmentId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });

    it('should handle service errors', async () => {
      req.params = { id: appointmentId };
      const error = new Error('Service error');
      appointmentService.deleteAppointment.mockRejectedValue(error);

      await expect(appointmentController.deleteAppointment(req, res)).rejects.toThrow(error);
    });
  });

  describe('cancelAppointment', () => {
    const appointmentId = '550e8400-e29b-41d4-a716-446655440000';
    const cancelData = { reason: 'Patient request' };
    const mockCancelled = {
      id: appointmentId,
      status: 'CANCELLED',
      reason: 'Cancellation reason: Patient request'
    };

    it('should cancel appointment with reason', async () => {
      req.params = { id: appointmentId };
      req.body = cancelData;
      appointmentService.cancelAppointment.mockResolvedValue(mockCancelled);

      await appointmentController.cancelAppointment(req, res);

      expect(appointmentService.cancelAppointment).toHaveBeenCalledWith(
        appointmentId,
        'Patient request',
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.appointment.cancel.success',
        mockCancelled
      );
    });

    it('should cancel appointment without reason', async () => {
      req.params = { id: appointmentId };
      req.body = {};
      const mockCancelledNoReason = { id: appointmentId, status: 'CANCELLED' };
      appointmentService.cancelAppointment.mockResolvedValue(mockCancelledNoReason);

      await appointmentController.cancelAppointment(req, res);

      expect(appointmentService.cancelAppointment).toHaveBeenCalledWith(
        appointmentId,
        undefined,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.appointment.cancel.success',
        mockCancelledNoReason
      );
    });

    it('should handle service errors', async () => {
      req.params = { id: appointmentId };
      req.body = cancelData;
      const error = new Error('Service error');
      appointmentService.cancelAppointment.mockRejectedValue(error);

      await expect(appointmentController.cancelAppointment(req, res)).rejects.toThrow(error);
    });
  });
});
