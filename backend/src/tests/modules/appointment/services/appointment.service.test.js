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
  resolveProviderAvailability,
} = require('@lib/scheduling/provider-availability');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier} = require('@lib/identifiers/resolve-entity-id');

// Mock dependencies
jest.mock('@repositories/appointment/appointment.repository');
jest.mock('@lib/audit');
jest.mock('@services/opd-flow/opd-flow.service', () => ({
  startOpdFlow: jest.fn()}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(),
  resolveModelRecordByIdentifier: jest.fn()}));
// The roster lookup reads other modules' tables; the service's own contract
// is what it does with the answer, so the answer is stubbed here.
jest.mock('@lib/scheduling/provider-availability', () => ({
  resolveProviderAvailability: jest.fn(),
  UNAVAILABLE_REASONS: {
    ON_LEAVE: 'ON_LEAVE',
    BLOCKED_SLOT: 'BLOCKED_SLOT',
    OFF_SCHEDULE: 'OFF_SCHEDULE'}}));

/**
 * Service results run through withAppointmentProjection, which always states
 * the subject type. Fixtures stay minimal and are projected at the assertion.
 */
const projected = (appointment) => ({
  ...appointment,
  subject_type: appointment.subject_type || 'PATIENT'});

describe('Appointment Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    resolveProviderAvailability.mockResolvedValue({ available: true });
    opdFlowService.startOpdFlow.mockResolvedValue({ encounter: { id: 'enc-1' } });
    createAuditLog.mockResolvedValue({});
    resolveModelIdByIdentifier.mockImplementation(async ({ identifier }) => identifier);
    resolveModelRecordByIdentifier.mockImplementation(async ({ identifier, model }) => {
      if (!identifier) return null;
      if (model === 'appointment') {
        return {
          id: identifier,
          tenant_id: 'tenant-1'};
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

      expect(result).toHaveProperty('appointments', mockAppointments.map(projected));
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

      expect(result).toEqual(projected(mockAppointment));
      expect(appointmentRepository.findById).toHaveBeenCalledWith(appointmentId, expect.any(Object));
    });

    it('should surface the phone contact rather than the primary contact', async () => {
      // Reception rings this number to confirm the booking, so an email
      // nominated as the patient's primary contact must not land in it.
      appointmentRepository.findById.mockResolvedValue({
        ...mockAppointment,
        patient: {
          contacts: [
            { contact_type: 'EMAIL', value: 'patient@example.com', is_primary: true },
            { contact_type: 'PHONE', value: '+256700000001', is_primary: false }],
          identifiers: []}});

      const result = await appointmentService.getAppointmentById(appointmentId, 'user-id', '127.0.0.1');

      expect(result.patient_primary_phone).toBe('+256700000001');
    });

    it('should fall back to the visitor phone when there is no patient', async () => {
      appointmentRepository.findById.mockResolvedValue({
        ...mockAppointment,
        patient_id: null,
        subject_type: 'VISITOR',
        visitor_name: 'Jordan Visitor',
        visitor_phone: '+256700000002'});

      const result = await appointmentService.getAppointmentById(appointmentId, 'user-id', '127.0.0.1');

      expect(result.patient_primary_phone).toBe('+256700000002');
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

      expect(result).toEqual(projected(mockCreated));
      // The service stamps the subject type before persisting so a row is
      // never stored without one.
      expect(appointmentRepository.create).toHaveBeenCalledWith(projected(createData));
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'CREATE',
        entity: 'appointment',
        entity_id: mockCreated.id,
        diff: { after: projected(mockCreated) },
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

      expect(result).toEqual(projected(mockCreated));
    });

    it('should reject a booking that overlaps another appointment for the same patient', async () => {
      appointmentRepository.findOverlappingForPatient.mockResolvedValue({
        id: 'existing-appointment',
        human_friendly_id: 'APT000099',
      });

      await expect(
        appointmentService.createAppointment(createData, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        message: 'errors.appointment.patient_conflict',
        statusCode: 409,
      });
      expect(appointmentRepository.create).not.toHaveBeenCalled();
    });

    it('should not check patient availability for a visitor appointment', async () => {
      const visitorData = {
        ...createData,
        patient_id: null,
        subject_type: 'VISITOR',
        visitor_name: 'Jordan Visitor',
        provider_user_id: 'provider-1',
      };
      appointmentRepository.create.mockResolvedValue({ ...mockCreated, ...visitorData });
      appointmentRepository.findById.mockResolvedValue({ ...mockCreated, ...visitorData });

      await appointmentService.createAppointment(visitorData, 'user-id', '127.0.0.1');

      expect(appointmentRepository.findOverlappingForPatient).not.toHaveBeenCalled();
    });

    describe('staff availability', () => {
      const staffedData = { ...createData, provider_user_id: 'provider-1' };

      beforeEach(() => {
        // jest.clearAllMocks() keeps implementations, so the clash mocks are
        // re-armed rather than inheriting a conflict from a prior case.
        appointmentRepository.findOverlappingForProvider.mockResolvedValue(null);
        appointmentRepository.findOverlappingForPatient.mockResolvedValue(null);
        appointmentRepository.findOverlappingVisitorAppointments.mockResolvedValue([]);
      });

      it('refuses a booking outside the rostered hours', async () => {
        resolveProviderAvailability.mockResolvedValue({
          available: false,
          reason: 'OFF_SCHEDULE',
          detail: { timezone: 'Africa/Kampala' }});

        await expect(
          appointmentService.createAppointment(staffedData, 'user-id', '127.0.0.1')
        ).rejects.toMatchObject({
          messageKey: 'errors.appointment.host_off_schedule',
          statusCode: 409});
        expect(appointmentRepository.create).not.toHaveBeenCalled();
      });

      it('names leave and blocked slots separately from off-roster', async () => {
        resolveProviderAvailability.mockResolvedValue({
          available: false,
          reason: 'ON_LEAVE',
          detail: { leave_id: 'LEV000001' }});
        await expect(
          appointmentService.createAppointment(staffedData, 'user-id', '127.0.0.1')
        ).rejects.toMatchObject({
          messageKey: 'errors.appointment.host_on_leave'});

        resolveProviderAvailability.mockResolvedValue({
          available: false,
          reason: 'BLOCKED_SLOT',
          detail: { slot_id: 'SLT000001' }});
        await expect(
          appointmentService.createAppointment(staffedData, 'user-id', '127.0.0.1')
        ).rejects.toMatchObject({
          messageKey: 'errors.appointment.host_slot_blocked'});
      });

      it('checks the roster for the facility the booking is at', async () => {
        appointmentRepository.create.mockResolvedValue(mockCreated);
        appointmentRepository.findById.mockResolvedValue(mockCreated);

        await appointmentService.createAppointment(
          { ...staffedData, facility_id: 'facility-1' },
          'user-id',
          '127.0.0.1'
        );

        expect(resolveProviderAvailability).toHaveBeenCalledWith(
          expect.objectContaining({
            providerUserId: 'provider-1',
            facilityId: 'facility-1',
            tenantId: staffedData.tenant_id})
        );
      });

      it('skips the roster lookup when no staff member is assigned', async () => {
        appointmentRepository.create.mockResolvedValue(mockCreated);
        appointmentRepository.findById.mockResolvedValue(mockCreated);

        await appointmentService.createAppointment(createData, 'user-id', '127.0.0.1');

        expect(resolveProviderAvailability).not.toHaveBeenCalled();
      });

      it('applies to a visitor meeting host as well', async () => {
        resolveProviderAvailability.mockResolvedValue({
          available: false,
          reason: 'OFF_SCHEDULE'});

        await expect(
          appointmentService.createAppointment(
            {
              ...createData,
              patient_id: null,
              subject_type: 'VISITOR',
              visitor_name: 'Jordan Visitor',
              provider_user_id: 'provider-1'},
            'user-id',
            '127.0.0.1'
          )
        ).rejects.toMatchObject({
          messageKey: 'errors.appointment.host_off_schedule',
          statusCode: 409});
      });
    });

    describe('visitor double-booking', () => {
      const visitorData = {
        ...createData,
        patient_id: null,
        subject_type: 'VISITOR',
        visitor_name: 'Jordan Visitor',
        visitor_phone: '+256 700 000 001',
        provider_user_id: 'provider-1',
      };

      beforeEach(() => {
        // jest.clearAllMocks() keeps implementations, so the overlap mocks are
        // re-armed here rather than inheriting a conflict from a prior case.
        appointmentRepository.findOverlappingForProvider.mockResolvedValue(null);
        appointmentRepository.findOverlappingForPatient.mockResolvedValue(null);
        appointmentRepository.findOverlappingVisitorAppointments.mockResolvedValue([]);
        appointmentRepository.create.mockResolvedValue({ ...mockCreated, ...visitorData });
        appointmentRepository.findById.mockResolvedValue({ ...mockCreated, ...visitorData });
      });

      it('rejects the same visitor phone written in another format', async () => {
        appointmentRepository.findOverlappingVisitorAppointments.mockResolvedValue([
          {
            id: 'existing-meeting',
            human_friendly_id: 'APT000077',
            visitor_name: 'J. Visitor',
            visitor_phone: '0700000001'}]);

        await expect(
          appointmentService.createAppointment(visitorData, 'user-id', '127.0.0.1')
        ).rejects.toMatchObject({
          message: 'errors.appointment.visitor_conflict',
          statusCode: 409});
        expect(appointmentRepository.create).not.toHaveBeenCalled();
      });

      it('allows a different visitor in the same window', async () => {
        appointmentRepository.findOverlappingVisitorAppointments.mockResolvedValue([
          {
            id: 'other-meeting',
            human_friendly_id: 'APT000078',
            visitor_name: 'Someone Else',
            visitor_phone: '+256700000999'}]);

        await expect(
          appointmentService.createAppointment(visitorData, 'user-id', '127.0.0.1')
        ).resolves.toBeDefined();
        expect(appointmentRepository.create).toHaveBeenCalled();
      });

      it('falls back to the visitor name when neither booking has a phone', async () => {
        appointmentRepository.findOverlappingVisitorAppointments.mockResolvedValue([
          {
            id: 'existing-meeting',
            human_friendly_id: 'APT000079',
            visitor_name: '  jordan   VISITOR ',
            visitor_phone: null}]);

        await expect(
          appointmentService.createAppointment(
            { ...visitorData, visitor_phone: null },
            'user-id',
            '127.0.0.1'
          )
        ).rejects.toMatchObject({
          message: 'errors.appointment.visitor_conflict',
          statusCode: 409});
      });

      it('lets the phone override a matching name', async () => {
        // Two different people can share a name; a number they each gave is
        // the stronger signal, so it decides when both bookings carry one.
        appointmentRepository.findOverlappingVisitorAppointments.mockResolvedValue([
          {
            id: 'other-meeting',
            human_friendly_id: 'APT000080',
            visitor_name: 'Jordan Visitor',
            visitor_phone: '+256700000999'}]);

        await expect(
          appointmentService.createAppointment(visitorData, 'user-id', '127.0.0.1')
        ).resolves.toBeDefined();
      });

      it('does not run the check for a clinical appointment', async () => {
        appointmentRepository.create.mockResolvedValue(mockCreated);
        appointmentRepository.findById.mockResolvedValue(mockCreated);

        await appointmentService.createAppointment(createData, 'user-id', '127.0.0.1');

        expect(
          appointmentRepository.findOverlappingVisitorAppointments
        ).not.toHaveBeenCalled();
      });

      it('rejects a visitor edit that clashes without moving the window', async () => {
        const meetingId = '550e8400-e29b-41d4-a716-4466554400aa';
        const before = {
          id: meetingId,
          tenant_id: 'tenant-1',
          subject_type: 'VISITOR',
          visitor_name: 'Jordan Visitor',
          visitor_phone: '+256700000001',
          status: 'SCHEDULED',
          scheduled_start: '2026-07-20T08:00:00.000Z',
          scheduled_end: '2026-07-20T08:30:00.000Z'};
        appointmentRepository.findById.mockResolvedValue(before);
        appointmentRepository.findOverlappingVisitorAppointments.mockResolvedValue([
          {
            id: 'existing-meeting',
            human_friendly_id: 'APT000081',
            visitor_name: 'Someone Else',
            visitor_phone: '+256700000555'}]);

        // Repointing the booking at a different person is as much a clash as
        // moving it into an occupied slot, even with the times untouched.
        await expect(
          appointmentService.updateAppointment(
            meetingId,
            { visitor_phone: '0700000555' },
            'user-id',
            '127.0.0.1'
          )
        ).rejects.toMatchObject({
          message: 'errors.appointment.visitor_conflict',
          statusCode: 409});
        expect(appointmentRepository.update).not.toHaveBeenCalled();
      });
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

      expect(result).toEqual(projected(mockAfter));
      expect(appointmentRepository.findById).toHaveBeenNthCalledWith(1, appointmentId, expect.any(Object));
      expect(appointmentRepository.findById).toHaveBeenNthCalledWith(2, appointmentId, expect.any(Object));
      expect(appointmentRepository.update).toHaveBeenCalledWith(appointmentId, updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'UPDATE',
        entity: 'appointment',
        entity_id: appointmentId,
        diff: { before: projected(mockBefore), after: projected(mockAfter) },
        ip_address: '127.0.0.1'
      });
      expect(opdFlowService.startOpdFlow).not.toHaveBeenCalled();
    });

    it('should audit schedule changes as RESCHEDULE', async () => {
      const before = {
        id: appointmentId,
        status: 'SCHEDULED',
        scheduled_start: '2026-07-20T08:00:00.000Z',
        scheduled_end: '2026-07-20T08:30:00.000Z'};
      const after = {
        ...before,
        scheduled_start: '2026-07-21T10:00:00.000Z',
        scheduled_end: '2026-07-21T10:30:00.000Z'};
      const scheduleUpdate = {
        scheduled_start: after.scheduled_start,
        scheduled_end: after.scheduled_end,
        status: 'SCHEDULED'};

      appointmentRepository.findById
        .mockResolvedValueOnce(before)
        .mockResolvedValueOnce(after);
      appointmentRepository.update.mockResolvedValue(after);

      const result = await appointmentService.updateAppointment(
        appointmentId,
        scheduleUpdate,
        'user-id',
        '127.0.0.1'
      );

      expect(result).toEqual(projected(after));
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-id',
        action: 'RESCHEDULE',
        entity: 'appointment',
        entity_id: appointmentId,
        diff: { before: projected(before), after: projected(after) },
        ip_address: '127.0.0.1'});
    });

    it('should reject rescheduling into a slot that overlaps another appointment for the same patient', async () => {
      const before = {
        id: appointmentId,
        patient_id: 'patient-1',
        tenant_id: 'tenant-1',
        status: 'SCHEDULED',
        scheduled_start: '2026-07-20T08:00:00.000Z',
        scheduled_end: '2026-07-20T08:30:00.000Z'};
      appointmentRepository.findById.mockResolvedValueOnce(before);
      appointmentRepository.findOverlappingForPatient.mockResolvedValue({
        id: 'other-appointment',
        human_friendly_id: 'APT000042',
      });

      await expect(
        appointmentService.updateAppointment(
          appointmentId,
          {
            scheduled_start: '2026-07-21T10:00:00.000Z',
            scheduled_end: '2026-07-21T10:30:00.000Z'},
          'user-id',
          '127.0.0.1'
        )
      ).rejects.toMatchObject({
        message: 'errors.appointment.patient_conflict',
        statusCode: 409,
      });
      expect(appointmentRepository.findOverlappingForPatient).toHaveBeenCalledWith(
        expect.objectContaining({
          patientId: 'patient-1',
          excludeAppointmentId: appointmentId,
          tenantId: 'tenant-1',
        })
      );
      expect(appointmentRepository.update).not.toHaveBeenCalled();
    });

    it('should re-check the roster when the window moves', async () => {
      const before = {
        id: appointmentId,
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        provider_user_id: 'provider-1',
        status: 'SCHEDULED',
        scheduled_start: '2026-07-20T08:00:00.000Z',
        scheduled_end: '2026-07-20T08:30:00.000Z'};
      appointmentRepository.findById.mockResolvedValue(before);
      resolveProviderAvailability.mockResolvedValue({
        available: false,
        reason: 'OFF_SCHEDULE'});

      await expect(
        appointmentService.updateAppointment(
          appointmentId,
          {
            scheduled_start: '2026-07-21T22:00:00.000Z',
            scheduled_end: '2026-07-21T22:30:00.000Z'},
          'user-id',
          '127.0.0.1'
        )
      ).rejects.toMatchObject({
        messageKey: 'errors.appointment.host_off_schedule',
        statusCode: 409});
      expect(appointmentRepository.update).not.toHaveBeenCalled();
    });

    it('should not check patient availability when the schedule is untouched', async () => {
      appointmentRepository.findById
        .mockResolvedValueOnce(mockBefore)
        .mockResolvedValueOnce(mockAfter);
      appointmentRepository.update.mockResolvedValue(mockAfter);

      await appointmentService.updateAppointment(appointmentId, updateData, 'user-id', '127.0.0.1');

      expect(appointmentRepository.findOverlappingForPatient).not.toHaveBeenCalled();
    });

    it('should auto-start OPD flow when status transitions to IN_PROGRESS', async () => {
      const inProgressBefore = {
        id: appointmentId,
        status: 'CONFIRMED',
        patient_id: 'patient-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1'};
      const inProgressAfter = {
        ...inProgressBefore,
        status: 'IN_PROGRESS'};

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

      expect(result).toEqual(projected(inProgressAfter));
      expect(opdFlowService.startOpdFlow).toHaveBeenCalledWith(
        expect.objectContaining({
          appointment_id: appointmentId,
          arrival_mode: 'ONLINE_APPOINTMENT',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1'}),
        expect.objectContaining({
          user_id: 'user-id',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          ip_address: '127.0.0.1'})
      );
    });

    it('should not auto-start OPD flow when appointment was already IN_PROGRESS', async () => {
      const inProgressBefore = {
        id: appointmentId,
        status: 'IN_PROGRESS',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1'};
      const inProgressAfter = {
        ...inProgressBefore,
        reason: 'Updated note'};

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
        patient_id: 'patient-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1'};
      const inProgressAfter = {
        ...inProgressBefore,
        status: 'IN_PROGRESS'};

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
      ).resolves.toEqual(projected(inProgressAfter));
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
        diff: { before: projected(mockBefore) },
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

      expect(result).toEqual(projected(mockAfter));
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
        diff: { before: projected(mockBefore), after: projected(mockAfter) },
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

      expect(result).toEqual(projected(mockAfterNoReason));
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

    it('should refuse to cancel an appointment that already closed', async () => {
      // A visit that happened must not be rewritten as a cancellation.
      appointmentRepository.findById.mockResolvedValue({
        ...mockBefore,
        status: 'COMPLETED'});

      await expect(
        appointmentService.cancelAppointment(appointmentId, null, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.appointment.cannot_cancel_closed',
        statusCode: 400});
      expect(appointmentRepository.update).not.toHaveBeenCalled();
    });

    it('should refuse to cancel an appointment already marked NO_SHOW', async () => {
      appointmentRepository.findById.mockResolvedValue({
        ...mockBefore,
        status: 'NO_SHOW'});

      await expect(
        appointmentService.cancelAppointment(appointmentId, null, 'user-id', '127.0.0.1')
      ).rejects.toMatchObject({
        messageKey: 'errors.appointment.cannot_cancel_closed',
        statusCode: 400});
      expect(appointmentRepository.update).not.toHaveBeenCalled();
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
