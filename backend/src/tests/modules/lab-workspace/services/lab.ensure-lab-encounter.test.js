const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  encounter: {
    findFirst: jest.fn(),
    create: jest.fn()
  }
}));

jest.mock('@services/encounter/encounter.service', () => ({
  createEncounter: jest.fn()
}));

const prisma = require('@prisma/client');
const encounterService = require('@services/encounter/encounter.service');
const {
  ensureLabEncounterForPatient
} = require('@services/lab-workspace/lab.shared');

describe('ensureLabEncounterForPatient', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('reuses an open Lab encounter when one exists', async () => {
    prisma.encounter.findFirst.mockResolvedValueOnce({ id: 'lab-enc-1' });

    const id = await ensureLabEncounterForPatient({
      patientRecord: {
        id: 'patient-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1'
      },
      userId: 'user-1',
      ipAddress: '127.0.0.1'
    });

    expect(id).toBe('lab-enc-1');
    expect(encounterService.createEncounter).not.toHaveBeenCalled();
    expect(prisma.encounter.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          encounter_type: 'LAB',
          status: 'OPEN',
          patient_id: 'patient-1'
        })
      })
    );
  });

  it('creates a Lab encounter when none is open', async () => {
    prisma.encounter.findFirst.mockResolvedValueOnce(null);
    encounterService.createEncounter.mockResolvedValueOnce({ id: 'lab-enc-new' });

    const id = await ensureLabEncounterForPatient({
      patientRecord: {
        id: 'patient-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1'
      },
      userId: 'user-1',
      ipAddress: '127.0.0.1'
    });

    expect(id).toBe('lab-enc-new');
    expect(encounterService.createEncounter).toHaveBeenCalledWith(
      expect.objectContaining({
        encounter_type: 'LAB',
        status: 'OPEN',
        patient_id: 'patient-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1'
      }),
      'user-1',
      '127.0.0.1'
    );
  });

  it('rejects missing patient context', async () => {
    await expect(
      ensureLabEncounterForPatient({ patientRecord: {} })
    ).rejects.toBeInstanceOf(HttpError);
  });
});
