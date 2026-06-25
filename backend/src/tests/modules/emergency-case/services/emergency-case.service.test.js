/**
 * Emergency case service tests
 *
 * @module tests/modules/emergency-case/services
 * @description Tests for emergency case service business logic
 */

const emergencyCaseService = require('../../../../modules/emergency-case/services/emergency-case.service');
const emergencyCaseRepository = require('../../../../modules/emergency-case/repositories/emergency-case.repository');
const emergencyResponseRepository = require('@modules/emergency-response/repositories/emergency-response.repository');
const opdFlowService = require('@services/opd-flow/opd-flow.service');
const ipdFlowService = require('@services/ipd-flow/ipd-flow.service');
const encounterService = require('@services/encounter/encounter.service');
const theatreFlowService = require('@services/theatre-flow/theatre-flow.service');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('../../../../modules/emergency-case/repositories/emergency-case.repository');
jest.mock('@modules/emergency-response/repositories/emergency-response.repository', () => ({
  create: jest.fn()
}));
jest.mock('@services/opd-flow/opd-flow.service', () => ({
  startOpdFlow: jest.fn()
}));
jest.mock('@services/ipd-flow/ipd-flow.service', () => ({
  startIpdFlow: jest.fn(),
  startIcuStay: jest.fn()
}));
jest.mock('@services/encounter/encounter.service', () => ({
  createEncounter: jest.fn()
}));
jest.mock('@services/theatre-flow/theatre-flow.service', () => ({
  startTheatreFlow: jest.fn()
}));
jest.mock('@lib/audit');

describe('Emergency Case Service', () => {
  const mockUser = { id: 'user-id', tenant_id: 'tenant-id' };

  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listEmergencyCases', () => {
    it('should list emergency cases with pagination', async () => {
      const mockCases = [
        { id: '1', severity: 'HIGH', status: 'PENDING' },
        { id: '2', severity: 'CRITICAL', status: 'IN_PROGRESS' }
      ];

      emergencyCaseRepository.findMany.mockResolvedValue(mockCases);
      emergencyCaseRepository.count.mockResolvedValue(2);

      const result = await emergencyCaseService.listEmergencyCases({}, 1, 10, 'created_at', 'desc');

      expect(result.items).toEqual([
        expect.objectContaining(mockCases[0]),
        expect.objectContaining(mockCases[1]),
      ]);
      expect(result.items[0]).toEqual(expect.objectContaining({ display_id: '1' }));
      expect(result.total).toBe(2);
      expect(result.page).toBe(1);
      expect(result.limit).toBe(10);
      expect(result.totalPages).toBe(1);
    });

    it('should apply filters correctly', async () => {
      const filters = {
        tenant_id: 'tenant-id',
        severity: 'HIGH'
      };

      emergencyCaseRepository.findMany.mockResolvedValue([]);
      emergencyCaseRepository.count.mockResolvedValue(0);

      await emergencyCaseService.listEmergencyCases(filters, 1, 20);

      expect(emergencyCaseRepository.findMany).toHaveBeenCalledWith(
        filters,
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should calculate pagination correctly', async () => {
      emergencyCaseRepository.findMany.mockResolvedValue([]);
      emergencyCaseRepository.count.mockResolvedValue(25);

      const result = await emergencyCaseService.listEmergencyCases({}, 2, 10);

      expect(result.totalPages).toBe(3);
      expect(emergencyCaseRepository.findMany).toHaveBeenCalledWith({}, 10, 10, { created_at: 'desc' });
    });
  });

  describe('getEmergencyCaseById', () => {
    it('should return emergency case by id', async () => {
      const mockCase = { id: 'test-id', severity: 'HIGH', status: 'PENDING' };

      emergencyCaseRepository.findById.mockResolvedValue(mockCase);

      const result = await emergencyCaseService.getEmergencyCaseById('test-id');

      expect(result).toEqual(expect.objectContaining(mockCase));
      expect(result).toEqual(expect.objectContaining({ display_id: 'test-id' }));
      expect(emergencyCaseRepository.findById).toHaveBeenCalledWith('test-id');
    });

    it('should throw HttpError if emergency case not found', async () => {
      emergencyCaseRepository.findById.mockResolvedValue(null);

      await expect(
        emergencyCaseService.getEmergencyCaseById('non-existent')
      ).rejects.toThrow(HttpError);
      
      await expect(
        emergencyCaseService.getEmergencyCaseById('non-existent')
      ).rejects.toMatchObject({
        messageKey: 'errors.emergency_case.not_found',
        statusCode: 404
      });
    });
  });

  describe('createEmergencyCase', () => {
    it('should create emergency case and audit log', async () => {
      const caseData = {
        tenant_id: 'tenant-id',
        patient_id: 'patient-id',
        severity: 'HIGH',
        status: 'PENDING'
      };
      const mockCreatedCase = {
        id: 'new-id',
        ...caseData,
        status: 'OPEN'
      };
      const expectedCreatePayload = {
        tenant_id: 'tenant-id',
        patient_id: 'patient-id',
        severity: 'HIGH',
        status: 'OPEN'
      };

      emergencyCaseRepository.create.mockResolvedValue(mockCreatedCase);

      const result = await emergencyCaseService.createEmergencyCase(caseData, mockUser);

      expect(result).toEqual(expect.objectContaining(mockCreatedCase));
      expect(result).toEqual(expect.objectContaining({ display_id: 'new-id' }));
      expect(emergencyCaseRepository.create).toHaveBeenCalledWith(expectedCreatePayload);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'CREATE',
        resource: 'emergency_case',
        resource_id: mockCreatedCase.id,
        user_id: mockUser.id,
        tenant_id: caseData.tenant_id,
        details: { data: expectedCreatePayload }
      });
    });

    it('should throw error if create fails', async () => {
      emergencyCaseRepository.create.mockRejectedValue(new Error('DB Error'));

      await expect(
        emergencyCaseService.createEmergencyCase({}, mockUser)
      ).rejects.toThrow();
    });
  });

  describe('updateEmergencyCase', () => {
    it('should update emergency case and audit log', async () => {
      const existingCase = {
        id: 'test-id',
        tenant_id: 'tenant-id',
        severity: 'HIGH',
        status: 'PENDING'
      };
      const updateData = { status: 'IN_PROGRESS' };
      const expectedUpdatePayload = { status: 'OPEN' };
      const updatedCase = { ...existingCase, ...expectedUpdatePayload };

      emergencyCaseRepository.findById.mockResolvedValue(existingCase);
      emergencyCaseRepository.update.mockResolvedValue(updatedCase);

      const result = await emergencyCaseService.updateEmergencyCase('test-id', updateData, mockUser);

      expect(result).toEqual(expect.objectContaining(updatedCase));
      expect(result).toEqual(expect.objectContaining({ display_id: 'test-id' }));
      expect(emergencyCaseRepository.findById).toHaveBeenCalledWith('test-id');
      expect(emergencyCaseRepository.update).toHaveBeenCalledWith('test-id', expectedUpdatePayload);
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'UPDATE',
        resource: 'emergency_case',
        resource_id: 'test-id',
        user_id: mockUser.id,
        tenant_id: existingCase.tenant_id,
        details: { before: existingCase, after: expectedUpdatePayload }
      });
    });

    it('should throw HttpError if emergency case not found', async () => {
      emergencyCaseRepository.findById.mockResolvedValue(null);

      await expect(
        emergencyCaseService.updateEmergencyCase('non-existent', {}, mockUser)
      ).rejects.toThrow(HttpError);
      
      await expect(
        emergencyCaseService.updateEmergencyCase('non-existent', {}, mockUser)
      ).rejects.toMatchObject({
        messageKey: 'errors.emergency_case.not_found',
        statusCode: 404
      });
    });

  });

  describe('handoffEmergencyCase', () => {
    it('should start OPD work, record response, close case, and audit handoff', async () => {
      const existingCase = {
        id: 'case-id',
        tenant_id: 'tenant-id',
        facility_id: 'facility-id',
        patient_id: 'patient-id',
        severity: 'CRITICAL',
        status: 'OPEN'
      };
      const updatedCase = { ...existingCase, status: 'CLOSED' };

      emergencyCaseRepository.findById.mockResolvedValue(existingCase);
      opdFlowService.startOpdFlow.mockResolvedValue({
        encounter: { id: 'ENC000001' },
        flow: { emergency_case_id: 'EME000001' }
      });
      emergencyResponseRepository.create.mockResolvedValue({ id: 'response-id' });
      emergencyCaseRepository.update.mockResolvedValue(updatedCase);

      const result = await emergencyCaseService.handoffEmergencyCase(
        'case-id',
        { destination: 'OPD', notes: 'Accepted by OPD.', close_case: true },
        mockUser
      );

      expect(opdFlowService.startOpdFlow).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: existingCase.tenant_id,
          facility_id: existingCase.facility_id,
          patient_id: existingCase.patient_id,
          arrival_mode: 'EMERGENCY',
          emergency_case_id: existingCase.id,
          initial_stage: 'WAITING_VITALS',
          require_consultation_payment: false,
          create_consultation_invoice: false,
          reuse_open_encounter: true,
          notes: 'Handoff to OPD.\nAccepted by OPD.'
        }),
        expect.objectContaining({
          tenant_id: existingCase.tenant_id,
          facility_id: existingCase.facility_id,
          user_id: mockUser.id
        })
      );
      expect(emergencyResponseRepository.create).toHaveBeenCalledWith({
        emergency_case_id: existingCase.id,
        response_at: expect.any(Date),
        notes: 'Handoff to OPD.\nAccepted by OPD.'
      });
      expect(emergencyCaseRepository.update).toHaveBeenCalledWith(
        existingCase.id,
        expect.objectContaining({
          status: 'CLOSED',
          extension_json: expect.objectContaining({
            handoff: expect.objectContaining({
              destination: 'OPD',
              route: 'opd',
              terminal: false,
              close_case: true,
              receiving_display_id: 'ENC000001',
              encounter_display_id: 'ENC000001',
              stage: 'WAITING_VITALS',
              billing_deferred: false
            })
          })
        })
      );
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'HANDOFF',
          resource: 'emergency_case',
          resource_id: existingCase.id,
          user_id: mockUser.id,
          tenant_id: existingCase.tenant_id,
          details: expect.objectContaining({
            destination: 'OPD',
            close_case: true,
            receiving_work: true,
            receiving_display_id: 'ENC000001',
            billing_deferred: false,
            notes: 'Accepted by OPD.'
          })
        })
      );
      expect(result).toEqual(expect.objectContaining(updatedCase));
    });

    it('should start ICU work through IPD admission before ICU stay', async () => {
      const existingCase = {
        id: 'case-id',
        tenant_id: 'tenant-id',
        facility_id: 'facility-id',
        patient_id: 'patient-id',
        severity: 'CRITICAL',
        status: 'OPEN'
      };
      const updatedCase = { ...existingCase, status: 'CLOSED' };

      emergencyCaseRepository.findById.mockResolvedValue(existingCase);
      ipdFlowService.startIpdFlow.mockResolvedValue({
        id: 'ADM000001',
        admission: { id: 'ADM000001' }
      });
      ipdFlowService.startIcuStay.mockResolvedValue({
        id: 'ADM000001',
        flow: { stage: 'ICU' }
      });
      emergencyResponseRepository.create.mockResolvedValue({ id: 'response-id' });
      emergencyCaseRepository.update.mockResolvedValue(updatedCase);

      await emergencyCaseService.handoffEmergencyCase(
        'case-id',
        { destination: 'ICU', close_case: true },
        mockUser
      );

      expect(ipdFlowService.startIpdFlow).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: existingCase.tenant_id,
          facility_id: existingCase.facility_id,
          patient_id: existingCase.patient_id
        }),
        expect.objectContaining({ user_id: mockUser.id })
      );
      expect(ipdFlowService.startIcuStay).toHaveBeenCalledWith(
        'ADM000001',
        expect.objectContaining({ started_at: expect.any(String) }),
        expect.objectContaining({ user_id: mockUser.id })
      );
      expect(emergencyCaseRepository.update).toHaveBeenCalledWith(
        existingCase.id,
        expect.objectContaining({
          status: 'CLOSED',
          extension_json: expect.objectContaining({
            handoff: expect.objectContaining({
              destination: 'ICU',
              route: 'icu',
              receiving_display_id: 'ADM000001',
              admission_display_id: 'ADM000001',
              stage: 'ICU',
              billing_deferred: true
            })
          })
        })
      );
    });

    it('should start theater work through a theatre encounter', async () => {
      const existingCase = {
        id: 'case-id',
        tenant_id: 'tenant-id',
        facility_id: 'facility-id',
        patient_id: 'patient-id',
        severity: 'HIGH',
        status: 'OPEN'
      };
      const updatedCase = { ...existingCase, status: 'CLOSED' };

      emergencyCaseRepository.findById.mockResolvedValue(existingCase);
      encounterService.createEncounter.mockResolvedValue({ id: 'ENC000001' });
      theatreFlowService.startTheatreFlow.mockResolvedValue({ id: 'THR000001' });
      emergencyResponseRepository.create.mockResolvedValue({ id: 'response-id' });
      emergencyCaseRepository.update.mockResolvedValue(updatedCase);

      await emergencyCaseService.handoffEmergencyCase(
        'case-id',
        { destination: 'THEATER', notes: 'Needs urgent theatre.' },
        mockUser
      );

      expect(encounterService.createEncounter).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: existingCase.tenant_id,
          facility_id: existingCase.facility_id,
          patient_id: existingCase.patient_id,
          encounter_type: 'THEATRE',
          status: 'OPEN'
        }),
        mockUser.id,
        undefined
      );
      expect(theatreFlowService.startTheatreFlow).toHaveBeenCalledWith(
        expect.objectContaining({
          encounter_id: 'ENC000001',
          status: 'SCHEDULED',
          workflow_stage: 'PRE_OP',
          stage_notes: 'Handoff to THEATER.\nNeeds urgent theatre.'
        }),
        expect.objectContaining({ user_id: mockUser.id })
      );
      expect(emergencyCaseRepository.update).toHaveBeenCalledWith(
        existingCase.id,
        expect.objectContaining({
          status: 'CLOSED',
          extension_json: expect.objectContaining({
            handoff: expect.objectContaining({
              destination: 'THEATER',
              route: 'theater',
              receiving_display_id: 'THR000001',
              encounter_display_id: 'ENC000001',
              stage: 'PRE_OP',
              billing_deferred: false
            })
          })
        })
      );
    });

    it('should persist a referral snapshot without starting a downstream workflow and surface handoff on the returned case', async () => {
      const existingCase = {
        id: 'case-id',
        tenant_id: 'tenant-id',
        facility_id: 'facility-id',
        patient_id: 'patient-id',
        severity: 'MEDIUM',
        status: 'OPEN'
      };

      emergencyCaseRepository.findById.mockResolvedValue(existingCase);
      emergencyResponseRepository.create.mockResolvedValue({ id: 'response-id' });
      emergencyCaseRepository.update.mockImplementation(async (id, data) => ({
        ...existingCase,
        ...data
      }));

      const result = await emergencyCaseService.handoffEmergencyCase(
        'case-id',
        { destination: 'REFERRAL', notes: 'Referred to district hospital.', close_case: true },
        mockUser
      );

      expect(opdFlowService.startOpdFlow).not.toHaveBeenCalled();
      expect(ipdFlowService.startIpdFlow).not.toHaveBeenCalled();
      expect(emergencyCaseRepository.update).toHaveBeenCalledWith(
        existingCase.id,
        expect.objectContaining({
          status: 'CLOSED',
          extension_json: expect.objectContaining({
            handoff: expect.objectContaining({
              destination: 'REFERRAL',
              route: null,
              terminal: true,
              receiving_display_id: null,
              billing_deferred: false,
              notes: 'Referred to district hospital.'
            })
          })
        })
      );
      expect(result.handoff).toEqual(
        expect.objectContaining({ destination: 'REFERRAL', terminal: true })
      );
    });

    it('should persist the handoff snapshot without closing the case when close_case is false', async () => {
      const existingCase = {
        id: 'case-id',
        tenant_id: 'tenant-id',
        facility_id: 'facility-id',
        patient_id: 'patient-id',
        severity: 'HIGH',
        status: 'OPEN'
      };

      emergencyCaseRepository.findById.mockResolvedValue(existingCase);
      opdFlowService.startOpdFlow.mockResolvedValue({ encounter: { id: 'ENC000009' }, flow: {} });
      emergencyResponseRepository.create.mockResolvedValue({ id: 'response-id' });
      emergencyCaseRepository.update.mockImplementation(async (id, data) => ({
        ...existingCase,
        ...data
      }));

      await emergencyCaseService.handoffEmergencyCase(
        'case-id',
        { destination: 'OPD', close_case: false },
        mockUser
      );

      const updateCall = emergencyCaseRepository.update.mock.calls[0][1];
      expect(updateCall).not.toHaveProperty('status');
      expect(updateCall.extension_json.handoff).toEqual(
        expect.objectContaining({ destination: 'OPD', close_case: false })
      );
    });

    it('should throw HttpError if emergency case is not found', async () => {
      emergencyCaseRepository.findById.mockResolvedValue(null);

      await expect(
        emergencyCaseService.handoffEmergencyCase(
          'missing-case',
          { destination: 'OPD' },
          mockUser
        )
      ).rejects.toThrow(HttpError);
    });
  });

  describe('deleteEmergencyCase', () => {
    it('should soft delete emergency case and audit log', async () => {
      const existingCase = {
        id: 'test-id',
        tenant_id: 'tenant-id',
        severity: 'HIGH',
        status: 'PENDING'
      };
      const deletedCase = { ...existingCase, deleted_at: new Date() };

      emergencyCaseRepository.findById.mockResolvedValue(existingCase);
      emergencyCaseRepository.softDelete.mockResolvedValue(deletedCase);

      const result = await emergencyCaseService.deleteEmergencyCase('test-id', mockUser);

      expect(result).toEqual(expect.objectContaining(deletedCase));
      expect(result).toEqual(expect.objectContaining({ display_id: 'test-id' }));
      expect(emergencyCaseRepository.findById).toHaveBeenCalledWith('test-id');
      expect(emergencyCaseRepository.softDelete).toHaveBeenCalledWith('test-id');
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'DELETE',
        resource: 'emergency_case',
        resource_id: 'test-id',
        user_id: mockUser.id,
        tenant_id: existingCase.tenant_id,
        details: { data: existingCase }
      });
    });

    it('should throw HttpError if emergency case not found', async () => {
      emergencyCaseRepository.findById.mockResolvedValue(null);

      await expect(
        emergencyCaseService.deleteEmergencyCase('non-existent', mockUser)
      ).rejects.toThrow(HttpError);
      
      await expect(
        emergencyCaseService.deleteEmergencyCase('non-existent', mockUser)
      ).rejects.toMatchObject({
        messageKey: 'errors.emergency_case.not_found',
        statusCode: 404
      });
    });

  });
});
