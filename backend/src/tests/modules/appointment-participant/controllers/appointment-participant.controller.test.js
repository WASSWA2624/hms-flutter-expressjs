/**
 * Appointment participant controller tests
 *
 * @module tests/modules/appointment-participant/controllers
 * @description Tests for appointment participant controller
 * Per testing.mdc: Mock service, test HTTP handling
 */

const appointmentParticipantController = require('@controllers/appointment-participant/appointment-participant.controller');
const appointmentParticipantService = require('@services/appointment-participant/appointment-participant.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

// Mock dependencies
jest.mock('@services/appointment-participant/appointment-participant.service');
jest.mock('@lib/response');

describe('Appointment Participant Controller', () => {
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

  describe('listAppointmentParticipants', () => {
    const mockResult = {
      participants: [
        { id: '1', appointment_id: '550e8400-e29b-41d4-a716-446655440000', role: 'Provider' },
        { id: '2', appointment_id: '550e8400-e29b-41d4-a716-446655440001', role: 'Assistant' }
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

    it('should list participants with default pagination', async () => {
      appointmentParticipantService.listAppointmentParticipants.mockResolvedValue(mockResult);

      await appointmentParticipantController.listAppointmentParticipants(req, res);

      expect(appointmentParticipantService.listAppointmentParticipants).toHaveBeenCalledWith(
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
        'messages.appointment_participant.list.success',
        mockResult.participants,
        mockResult.pagination
      );
    });

    it('should apply filters from query params', async () => {
      req.query = {
        appointment_id: '550e8400-e29b-41d4-a716-446655440000',
        participant_user_id: '550e8400-e29b-41d4-a716-446655440001',
        role: 'Provider',
        page: '2',
        limit: '10'
      };
      appointmentParticipantService.listAppointmentParticipants.mockResolvedValue(mockResult);

      await appointmentParticipantController.listAppointmentParticipants(req, res);

      expect(appointmentParticipantService.listAppointmentParticipants).toHaveBeenCalledWith(
        {
          appointment_id: '550e8400-e29b-41d4-a716-446655440000',
          participant_user_id: '550e8400-e29b-41d4-a716-446655440001',
          participant_patient_id: undefined,
          role: 'Provider'
        },
        2,
        10,
        undefined,
        'asc',
        'requester-id',
        '127.0.0.1'
      );
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
      req.params = { id: participantId };
      appointmentParticipantService.getAppointmentParticipantById.mockResolvedValue(mockParticipant);

      await appointmentParticipantController.getAppointmentParticipantById(req, res);

      expect(appointmentParticipantService.getAppointmentParticipantById).toHaveBeenCalledWith(
        participantId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.appointment_participant.get.success',
        mockParticipant
      );
    });
  });

  describe('createAppointmentParticipant', () => {
    const createData = {
      appointment_id: '550e8400-e29b-41d4-a716-446655440000',
      participant_user_id: '550e8400-e29b-41d4-a716-446655440001',
      role: 'Provider'
    };

    const mockCreated = {
      id: '550e8400-e29b-41d4-a716-446655440002',
      ...createData
    };

    it('should create participant', async () => {
      req.body = createData;
      appointmentParticipantService.createAppointmentParticipant.mockResolvedValue(mockCreated);

      await appointmentParticipantController.createAppointmentParticipant(req, res);

      expect(appointmentParticipantService.createAppointmentParticipant).toHaveBeenCalledWith(
        createData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.appointment_participant.create.success',
        mockCreated
      );
    });
  });

  describe('updateAppointmentParticipant', () => {
    const participantId = '550e8400-e29b-41d4-a716-446655440000';
    const updateData = { role: 'Lead Provider' };
    const mockUpdated = {
      id: participantId,
      role: 'Lead Provider'
    };

    it('should update participant', async () => {
      req.params = { id: participantId };
      req.body = updateData;
      appointmentParticipantService.updateAppointmentParticipant.mockResolvedValue(mockUpdated);

      await appointmentParticipantController.updateAppointmentParticipant(req, res);

      expect(appointmentParticipantService.updateAppointmentParticipant).toHaveBeenCalledWith(
        participantId,
        updateData,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.appointment_participant.update.success',
        mockUpdated
      );
    });
  });

  describe('deleteAppointmentParticipant', () => {
    const participantId = '550e8400-e29b-41d4-a716-446655440000';

    it('should delete participant', async () => {
      req.params = { id: participantId };
      appointmentParticipantService.deleteAppointmentParticipant.mockResolvedValue();

      await appointmentParticipantController.deleteAppointmentParticipant(req, res);

      expect(appointmentParticipantService.deleteAppointmentParticipant).toHaveBeenCalledWith(
        participantId,
        'requester-id',
        '127.0.0.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });
  });
});
