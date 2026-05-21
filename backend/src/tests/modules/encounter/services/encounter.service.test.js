jest.mock('@repositories/encounter/encounter.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({})
}));

const subject = require('../../../../modules/encounter/services/encounter.service');
const encounterRepository = require('@repositories/encounter/encounter.repository');

describe('encounter.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('exports service methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });

  it('builds search filters for encounter and patient identifiers', async () => {
    encounterRepository.findMany.mockResolvedValue([
      {
        id: 'enc-1',
        patient: {
          id: 'patient-1',
          human_friendly_id: 'PAT-1',
          first_name: 'Ada',
          last_name: 'Lovelace',
          contacts: [
            {
              contact_type: 'EMAIL',
              value: 'ada@example.com',
              is_primary: false
            },
            {
              contact_type: 'PHONE',
              value: '+256700000001',
              is_primary: true
            }
          ]
        }
      }
    ]);
    encounterRepository.count.mockResolvedValue(0);

    const result = await subject.listEncounters(
      {
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        search: 'enc-2001'
      },
      1,
      20,
      'created_at',
      'desc',
      'user-1',
      '127.0.0.1'
    );

    expect(encounterRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        OR: expect.arrayContaining([
          { human_friendly_id: { contains: 'ENC-2001' } },
          { patient: { human_friendly_id: { contains: 'ENC-2001' } } },
          { patient: { first_name: { contains: 'enc-2001' } } },
          {
            patient: {
              contacts: {
                some: expect.objectContaining({
                  deleted_at: null,
                  contact_type: {
                    in: ['PHONE', 'EMAIL']
                  },
                  value: { contains: 'enc-2001' }
                })
              }
            }
          }
        ])
      }),
      0,
      20,
      { created_at: 'desc' },
      expect.objectContaining({
        patient: expect.objectContaining({
          select: expect.objectContaining({
            human_friendly_id: true,
            first_name: true,
            last_name: true,
            contacts: expect.objectContaining({
              where: expect.objectContaining({
                deleted_at: null,
                contact_type: {
                  in: ['PHONE', 'EMAIL']
                }
              })
            })
          })
        })
      })
    );
    expect(result.encounters).toEqual([
      expect.objectContaining({
        id: 'enc-1',
        patient: expect.objectContaining({
          phone: '+256700000001',
          email: 'ada@example.com',
          primary_phone: '+256700000001',
          primary_email: 'ada@example.com',
          contact_phone: '+256700000001',
          contact_email: 'ada@example.com'
        })
      })
    ]);
    expect(encounterRepository.count).toHaveBeenCalledWith(
      expect.objectContaining({
        OR: expect.any(Array)
      })
    );
  });

  it('sets active OPD lock key when creating an open OPD encounter', async () => {
    encounterRepository.create.mockImplementation(async (payload) => ({
      id: 'enc-1',
      ...payload
    }));

    await subject.createEncounter(
      {
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        patient_id: 'patient-1',
        encounter_type: 'OPD',
        status: 'OPEN',
        started_at: '2026-05-21T08:00:00.000Z'
      },
      'user-1',
      '127.0.0.1'
    );

    expect(encounterRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        active_opd_lock_key: 'opd:tenant-1:facility-1:patient-1'
      })
    );
  });

  it('clears active OPD lock key when closing an encounter', async () => {
    encounterRepository.findById.mockResolvedValue({
      id: 'enc-1',
      tenant_id: 'tenant-1',
      facility_id: 'facility-1',
      patient_id: 'patient-1',
      encounter_type: 'OPD',
      status: 'OPEN',
      ended_at: null
    });
    encounterRepository.update.mockImplementation(async (_, payload) => ({
      id: 'enc-1',
      ...payload
    }));

    await subject.updateEncounter(
      'enc-1',
      {
        status: 'CLOSED'
      },
      'user-1',
      '127.0.0.1'
    );

    expect(encounterRepository.update).toHaveBeenCalledWith(
      'enc-1',
      expect.objectContaining({
        active_opd_lock_key: null,
        ended_at: expect.any(Date)
      })
    );
  });
});
