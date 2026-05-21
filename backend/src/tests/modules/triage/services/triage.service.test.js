jest.mock('@services/opd-flow/opd-flow.service', () => ({
  getOpdFlowById: jest.fn(),
  recordVitals: jest.fn(),
  assignDoctor: jest.fn(),
  correctStage: jest.fn()
}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn()
}));

const prisma = require('@prisma/client');
const opdFlowService = require('@services/opd-flow/opd-flow.service');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const triageService = require('@services/triage/triage.service');

const baseEncounter = () => ({
  id: 'encounter-1',
  human_friendly_id: 'ENC-1',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  patient_id: 'patient-1',
  provider_user_id: null,
  encounter_type: 'OPD',
  status: 'OPEN',
  started_at: new Date('2026-01-19T08:00:00.000Z'),
  extension_json: {
    opd_flow: {
      stage: 'WAITING_VITALS',
      next_step: 'Record vital signs and triage urgency.',
      visit_queue_id: 'queue-1',
      appointment_id: 'appointment-1',
      timeline: []
    }
  },
  patient: {
    id: 'patient-1',
    deleted_at: null
  }
});

const configurePrisma = () => {
  prisma.$transaction = jest.fn(async (callback) => {
    if (typeof callback === 'function') {
      return callback(prisma);
    }
    return Promise.resolve(callback);
  });
  prisma.tenant = { findFirst: jest.fn() };
  prisma.facility = { findFirst: jest.fn() };
  prisma.patient = { findFirst: jest.fn() };
  prisma.user = { findFirst: jest.fn() };
  prisma.department = { findFirst: jest.fn() };
  prisma.encounter = {
    findMany: jest.fn(),
    count: jest.fn(),
    findFirst: jest.fn(),
    update: jest.fn()
  };
  prisma.visit_queue = {
    findMany: jest.fn(),
    updateMany: jest.fn()
  };
  prisma.appointment = {
    findMany: jest.fn(),
    updateMany: jest.fn()
  };
  prisma.emergency_case = {
    findMany: jest.fn(),
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  };
  prisma.triage_assessment = {
    findMany: jest.fn(),
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  };
  prisma.lab_order = { create: jest.fn() };
  prisma.radiology_order = { create: jest.fn() };
  prisma.referral = { create: jest.fn() };
  prisma.admission = { create: jest.fn() };
  prisma.theatre_case = { create: jest.fn() };
};

describe('Triage Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    configurePrisma();
    createAuditLog.mockResolvedValue({});
  });

  describe('listTriageQueue', () => {
    it('builds scoped queue filters, tokenized search, and urgency filtering', async () => {
      const encounter = baseEncounter();
      encounter.extension_json.opd_flow.triage_level = 'LEVEL_2';
      prisma.tenant.findFirst.mockResolvedValue({ id: 'tenant-1' });
      prisma.facility.findFirst.mockResolvedValue({ id: 'facility-1', tenant_id: 'tenant-1' });
      prisma.encounter.findMany.mockResolvedValue([encounter]);
      prisma.encounter.count.mockResolvedValue(1);
      prisma.visit_queue.findMany.mockResolvedValue([{ id: 'queue-1', status: 'WAITING' }]);
      prisma.appointment.findMany.mockResolvedValue([{ id: 'appointment-1', status: 'CHECKED_IN' }]);
      prisma.emergency_case.findMany.mockResolvedValue([]);
      prisma.triage_assessment.findMany.mockResolvedValue([]);

      const result = await triageService.listTriageQueue(
        {
          tenant_id: 'TEN-1',
          facility_id: 'FAC-1',
          search: 'jane doe',
          triage_level: 'URGENT'
        },
        1,
        10,
        'created_at',
        'desc'
      );

      expect(result.items).toHaveLength(1);
      expect(prisma.encounter.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            tenant_id: 'tenant-1',
            facility_id: 'facility-1',
            deleted_at: null,
            status: 'OPEN',
            AND: expect.any(Array)
          }),
          skip: 0,
          take: 10,
          orderBy: { created_at: 'desc' },
          include: expect.any(Object)
        })
      );
      const where = prisma.encounter.findMany.mock.calls[0][0].where;
      const serialized = JSON.stringify(where);
      expect(serialized).toContain('WAITING_VITALS');
      expect(serialized).toContain('WAITING_DOCTOR_ASSIGNMENT');
      expect(serialized).toContain('JANE');
      expect(serialized).toContain('DOE');
    });

    it('returns an empty page when scoped patient lookup fails', async () => {
      prisma.patient.findFirst.mockResolvedValue(null);

      const result = await triageService.listTriageQueue({ patient_id: 'PAT-404' }, 2, 10);

      expect(result).toEqual({
        items: [],
        pagination: {
          page: 2,
          limit: 10,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: true
        }
      });
      expect(prisma.encounter.findMany).not.toHaveBeenCalled();
    });
  });

  describe('clinical action delegation', () => {
    it('records vitals only after encounter scope is verified', async () => {
      const encounter = baseEncounter();
      const payload = { vitals: [{ vital_type: 'HEART_RATE', value: '92' }] };
      const context = { user_id: 'nurse-1', tenant_id: 'tenant-1', facility_id: 'facility-1' };
      prisma.encounter.findFirst.mockResolvedValue(encounter);
      opdFlowService.recordVitals.mockResolvedValue({ flow: { stage: 'WAITING_DOCTOR_ASSIGNMENT' } });

      const result = await triageService.recordVitals('ENC-1', payload, context);

      expect(result.flow.stage).toBe('WAITING_DOCTOR_ASSIGNMENT');
      expect(opdFlowService.recordVitals).toHaveBeenCalledWith('ENC-1', payload, context);
    });

    it('blocks clinical actions across tenant boundaries', async () => {
      const encounter = baseEncounter();
      prisma.encounter.findFirst.mockResolvedValue(encounter);

      await expect(
        triageService.recordVitals('ENC-1', { vitals: [] }, { tenant_id: 'other-tenant' })
      ).rejects.toThrow(HttpError);
      expect(opdFlowService.recordVitals).not.toHaveBeenCalled();
    });
  });

  describe('routeFromTriage', () => {
    it('routes to lab once, updates queue/appointment state, and audits the transition', async () => {
      const encounter = baseEncounter();
      const snapshot = { encounter: { id: 'encounter-1', tenant_id: 'tenant-1', facility_id: 'facility-1' } };
      prisma.encounter.findFirst.mockResolvedValue(encounter);
      prisma.lab_order.create.mockResolvedValue({ id: 'lab-order-1' });
      prisma.visit_queue.updateMany.mockResolvedValue({ count: 1 });
      prisma.appointment.updateMany.mockResolvedValue({ count: 1 });
      prisma.encounter.update.mockImplementation(async ({ data }) => ({
        ...encounter,
        ...data
      }));
      opdFlowService.getOpdFlowById.mockResolvedValue(snapshot);

      const result = await triageService.routeFromTriage(
        'ENC-1',
        { route_to: 'LAB', notes: 'Send CBC' },
        {
          user_id: 'nurse-1',
          tenant_id: 'tenant-1',
          facility_id: 'facility-1',
          ip_address: '127.0.0.1'
        }
      );

      expect(result).toBe(snapshot);
      expect(prisma.lab_order.create).toHaveBeenCalledTimes(1);
      expect(prisma.visit_queue.updateMany).toHaveBeenCalledWith({
        where: { id: 'queue-1', deleted_at: null },
        data: { status: 'COMPLETED' }
      });
      expect(prisma.appointment.updateMany).toHaveBeenCalledWith({
        where: { id: 'appointment-1', deleted_at: null },
        data: { status: 'COMPLETED' }
      });
      expect(prisma.encounter.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'encounter-1' },
          data: expect.objectContaining({
            extension_json: expect.objectContaining({
              opd_flow: expect.objectContaining({
                stage: 'LAB_REQUESTED',
                lab_order_ids: ['lab-order-1'],
                route_history: [
                  expect.objectContaining({
                    route_to: 'LAB',
                    notes: 'Send CBC'
                  })
                ]
              })
            })
          })
        })
      );
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'UPDATE',
          entity: 'triage_flow',
          entity_id: 'encounter-1',
          tenant_id: 'tenant-1',
          user_id: 'nurse-1'
        })
      );
    });
  });
});
