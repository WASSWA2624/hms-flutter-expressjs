jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
}));

jest.mock('@lib/storage', () => ({
  createStorageService: jest.fn(),
  sanitizeFilename: jest.fn((value) => value),
}));

jest.mock('@lib/billing/identifiers', () => ({
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) =>
    values.find((value) => typeof value === 'string' && value.trim()) || null
  ),
}));

jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelRecordByIdentifier: jest.fn(),
}));

jest.mock('@lib/logging', () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  },
}));

const prisma = require('@prisma/client');
const { logger } = require('@lib/logging');
const { resolveIdentifierForFilter } = require('@lib/billing/identifiers');
const {
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');
const subject = require('@services/patient/patient-workspace.service');

const createPatientRecord = (overrides = {}) => ({
  id: 'patient-1',
  human_friendly_id: 'PAT0001',
  first_name: 'Jane',
  last_name: 'Doe',
  date_of_birth: '1990-01-01',
  gender: 'FEMALE',
  is_active: true,
  contacts: [],
  identifiers: [],
  guardians: [],
  tenant: null,
  facility: null,
  extension_json: {},
  created_at: '2026-03-01T00:00:00.000Z',
  updated_at: '2026-03-02T00:00:00.000Z',
  ...overrides,
});

describe('patient-workspace service', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    prisma.patient = {
      count: jest.fn(),
      findMany: jest.fn(),
    };
    prisma.visit_queue = {
      count: jest.fn(),
      findMany: jest.fn(),
    };
    prisma.admission = {
      count: jest.fn(),
      findMany: jest.fn(),
    };
    prisma.invoice = {
      count: jest.fn(),
      findMany: jest.fn(),
    };
    prisma.follow_up = {
      count: jest.fn(),
      findMany: jest.fn(),
    };
    prisma.consent = {
      findMany: jest.fn(),
    };
    prisma.appointment = {
      findMany: jest.fn(),
    };
    prisma.encounter = {
      findMany: jest.fn(),
    };
    prisma.patient_document = {
      findMany: jest.fn(),
    };
    prisma.referral = {
      findMany: jest.fn(),
    };
    prisma.payment = {
      findMany: jest.fn(),
    };
    prisma.phi_access_log = {
      findFirst: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
    };

    prisma.patient.count
      .mockResolvedValueOnce(5)
      .mockResolvedValueOnce(4);
    prisma.visit_queue.count.mockResolvedValue(1);
    prisma.admission.count.mockResolvedValue(0);
    prisma.invoice.count.mockRejectedValue(new Error('Invoice aggregate failed'));
    prisma.follow_up.count.mockResolvedValue(2);

    prisma.visit_queue.findMany.mockResolvedValue([]);
    prisma.admission.findMany.mockResolvedValue([]);
    prisma.invoice.findMany.mockRejectedValue(new Error('Invoice list failed'));
    prisma.follow_up.findMany.mockResolvedValue([]);
    prisma.consent.findMany.mockResolvedValue([]);
    prisma.appointment.findMany.mockResolvedValue([]);
    prisma.encounter.findMany.mockResolvedValue([]);
    prisma.patient_document.findMany.mockResolvedValue([]);
    prisma.referral.findMany.mockResolvedValue([]);
    prisma.payment.findMany.mockResolvedValue([]);
    prisma.phi_access_log.findFirst.mockResolvedValue(null);
    prisma.phi_access_log.findMany.mockResolvedValue([]);
    prisma.phi_access_log.create.mockResolvedValue({ id: 'phi-log-1' });
    resolveIdentifierForFilter.mockImplementation(async ({ value }) => value);
    resolveModelRecordByIdentifier.mockResolvedValue(
      createPatientRecord({
        tenant_id: 'TEN0001',
        facility_id: 'FAC0001',
      })
    );

    prisma.patient.findMany.mockImplementation(async (args = {}) => {
      if (args?.where?.documents?.none) {
        return [
          createPatientRecord({
            id: 'patient-2',
            human_friendly_id: 'PAT0002',
            first_name: 'Missing',
            last_name: 'Docs',
          }),
        ];
      }

      if (args?.take === 6) {
        return [createPatientRecord()];
      }

      return [];
    });
  });

  it('returns partial overview data when a non-critical section query fails', async () => {
    const result = await subject.getPatientWorkspaceOverview({
      tenant_id: 'TEN0001',
      facility_id: 'FAC0001',
    });

    expect(result.metrics).toEqual(
      expect.objectContaining({
        total_patients: 5,
        active_patients: 4,
        waiting_queue: 1,
        active_admissions: 0,
        unpaid_invoices: 0,
        due_follow_ups: 2,
      })
    );
    expect(result.recent_patients).toHaveLength(1);
    expect(result.missing_documents).toHaveLength(1);
    expect(result.unpaid_invoices).toEqual([]);
    expect(result.duplicate_queue).toEqual([]);
    expect(prisma.visit_queue.count).toHaveBeenCalledWith({
      where: expect.objectContaining({
        patient: { deleted_at: null },
      }),
    });
    expect(prisma.visit_queue.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          patient: { deleted_at: null },
        }),
      })
    );
    expect(logger.error).toHaveBeenCalledWith(
      'Patient workspace overview section failed',
      expect.objectContaining({
        section: 'metrics.unpaid_invoices',
        tenant_id: 'TEN0001',
        facility_id: 'FAC0001',
      })
    );
  });

  it('returns patient workspace data when phi access logging cannot be written', async () => {
    prisma.phi_access_log.create.mockRejectedValue(new Error('Foreign key constraint violated on user_id'));

    const result = await subject.getPatientWorkspace(
      'PAT0001',
      {
        tenant_id: 'TEN0001',
        facility_id: 'FAC0001',
      },
      {
        user_id: 'legacy-user-id',
        ip_address: '127.0.0.1',
      }
    );

    expect(result).toEqual(
      expect.objectContaining({
        patient: expect.objectContaining({
          human_friendly_id: 'PAT0001',
        }),
        snapshot: expect.any(Object),
        timeline: expect.any(Array),
      })
    );
    expect(logger.warn).toHaveBeenCalledWith(
      'Patient PHI access log skipped',
      expect.objectContaining({
        patient_id: 'patient-1',
        user_id: 'legacy-user-id',
      })
    );
  });

  it('returns tenant and facility reference data for global users without tenant scope', async () => {
    prisma.tenant = {
      findMany: jest.fn().mockResolvedValue([
        {
          id: 'tenant-1',
          human_friendly_id: 'TEN0001',
          name: 'DemoCare',
        },
      ]),
    };
    prisma.facility = {
      findMany: jest.fn().mockResolvedValue([
        {
          id: 'facility-1',
          human_friendly_id: 'FAC0001',
          name: 'DemoCare General Hospital',
          tenant_id: 'tenant-1',
        },
      ]),
    };
    prisma.ward = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.room = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.bed = { findMany: jest.fn().mockResolvedValue([]) };

    const result = await subject.getPatientWorkspaceReferenceData(
      {},
      {
        user: {
          roles: ['SUPER_ADMIN'],
        },
      }
    );

    expect(prisma.tenant.findMany).toHaveBeenCalled();
    expect(result.tenants).toEqual([
      expect.objectContaining({
        human_friendly_id: 'TEN0001',
        label: 'DemoCare',
      }),
    ]);
    expect(result.facilities).toEqual([
      expect.objectContaining({
        human_friendly_id: 'FAC0001',
        label: 'DemoCare General Hospital',
        tenant_id: 'TEN0001',
      }),
    ]);
  });

  it('resolves bed ward and room links to public identifiers', async () => {
    prisma.tenant = { findMany: jest.fn().mockResolvedValue([]) };
    prisma.facility = {
      findMany: jest.fn().mockResolvedValue([
        {
          id: 'facility-uuid-1',
          human_friendly_id: 'FAC0001',
          name: 'DemoCare General Hospital',
          tenant_id: 'tenant-uuid-1',
        },
      ]),
    };
    prisma.ward = {
      findMany: jest.fn().mockResolvedValue([
        {
          id: 'ward-uuid-1',
          human_friendly_id: 'WRD0001',
          facility_id: 'facility-uuid-1',
          name: 'Medical ward',
          ward_type: 'GENERAL',
        },
      ]),
    };
    prisma.room = {
      findMany: jest.fn().mockResolvedValue([
        {
          id: 'room-uuid-1',
          human_friendly_id: 'ROM0001',
          facility_id: 'facility-uuid-1',
          ward_id: 'ward-uuid-1',
          name: 'Room 101',
          floor: '1',
        },
      ]),
    };
    prisma.bed = {
      findMany: jest.fn().mockResolvedValue([
        {
          id: 'bed-uuid-1',
          human_friendly_id: 'BED0001',
          facility_id: 'facility-uuid-1',
          ward_id: 'ward-uuid-1',
          room_id: 'room-uuid-1',
          label: 'Bed A',
          status: 'AVAILABLE',
        },
      ]),
    };

    const result = await subject.getPatientWorkspaceReferenceData(
      {},
      {
        user: {
          roles: ['DOCTOR'],
          facility_id: 'facility-uuid-1',
        },
      },
    );

    expect(result.beds).toEqual([
      expect.objectContaining({
        human_friendly_id: 'BED0001',
        facility_id: 'FAC0001',
        ward_id: 'WRD0001',
        room_id: 'ROM0001',
      }),
    ]);
    expect(result.rooms[0]).toEqual(
      expect.objectContaining({
        ward_id: 'WRD0001',
        facility_id: 'FAC0001',
      }),
    );
    expect(result.wards[0]).toEqual(
      expect.objectContaining({
        facility_id: 'FAC0001',
      }),
    );
  });
});
