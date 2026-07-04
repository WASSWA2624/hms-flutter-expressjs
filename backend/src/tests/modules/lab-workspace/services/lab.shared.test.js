const mockResolveModelRecordByIdentifier = jest.fn();
const mockNormalizeIdentifier = jest.fn((value) => (typeof value === 'string' ? value.trim() : ''));

jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  normalizeIdentifier: (...args) => mockNormalizeIdentifier(...args),
  resolveModelIdByIdentifier: jest.fn(),
  resolveModelRecordByIdentifier: (...args) => mockResolveModelRecordByIdentifier(...args),
}));

const mockEncounterFindFirst = jest.fn();

jest.mock('@prisma/client', () => ({
  encounter: {
    findFirst: (...args) => mockEncounterFindFirst(...args),
  },
}));

const loadResolver = () => {
  jest.resetModules();
  return require('@services/lab-workspace/lab.shared').resolveLabOrderEncounterId;
};

describe('lab.shared resolveLabOrderEncounterId', () => {
  beforeEach(() => {
    mockResolveModelRecordByIdentifier.mockReset();
    mockEncounterFindFirst.mockReset();
    mockNormalizeIdentifier.mockImplementation((value) =>
      typeof value === 'string' ? value.trim() : ''
    );
  });

  it('returns encounter id when identifier is an encounter public id', async () => {
    const resolveLabOrderEncounterId = loadResolver();
    mockResolveModelRecordByIdentifier.mockResolvedValueOnce({ id: 'encounter-1' });

    const result = await resolveLabOrderEncounterId({ identifier: 'ENC0000001' });

    expect(result).toBe('encounter-1');
    expect(mockResolveModelRecordByIdentifier).toHaveBeenCalledWith(
      expect.objectContaining({
        identifier: 'ENC0000001',
        model: 'encounter',
      })
    );
    expect(mockEncounterFindFirst).not.toHaveBeenCalled();
  });

  it('resolves visit queue id to linked encounter via opd_flow extension', async () => {
    const resolveLabOrderEncounterId = loadResolver();
    mockResolveModelRecordByIdentifier
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({
        id: 'visit-queue-1',
        patient_id: 'patient-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
      });
    mockEncounterFindFirst.mockResolvedValueOnce({ id: 'encounter-from-queue' });

    const result = await resolveLabOrderEncounterId({
      identifier: 'VIS0000001',
      patientId: 'patient-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
    });

    expect(result).toBe('encounter-from-queue');
    expect(mockEncounterFindFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          extension_json: {
            path: '$.opd_flow.visit_queue_id',
            equals: 'visit-queue-1',
          },
        }),
      })
    );
  });

  it('falls back to open encounter for visit queue when no linked encounter exists', async () => {
    const resolveLabOrderEncounterId = loadResolver();
    mockResolveModelRecordByIdentifier
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({
        id: 'visit-queue-1',
        patient_id: 'patient-1',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
      });
    mockEncounterFindFirst
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ id: 'open-encounter-1' });

    const result = await resolveLabOrderEncounterId({ identifier: 'VIS0000001' });

    expect(result).toBe('open-encounter-1');
    expect(mockEncounterFindFirst).toHaveBeenCalledTimes(2);
  });

  it('returns null for visit queue when no encounter can be resolved', async () => {
    const resolveLabOrderEncounterId = loadResolver();
    mockResolveModelRecordByIdentifier
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({
        id: 'visit-queue-1',
        patient_id: 'patient-1',
        tenant_id: 'tenant-1',
        facility_id: null,
      });
    mockEncounterFindFirst.mockResolvedValue(null);

    const result = await resolveLabOrderEncounterId({ identifier: 'VIS0000001' });

    expect(result).toBeNull();
  });

  it('resolves admission id to encounter id', async () => {
    const resolveLabOrderEncounterId = loadResolver();
    mockResolveModelRecordByIdentifier
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({ encounter_id: 'encounter-from-admission' });

    const result = await resolveLabOrderEncounterId({ identifier: 'ADM0000001' });

    expect(result).toBe('encounter-from-admission');
  });

  it('throws when identifier cannot be resolved to any clinical context', async () => {
    const resolveLabOrderEncounterId = loadResolver();
    mockResolveModelRecordByIdentifier.mockResolvedValue(null);

    await expect(resolveLabOrderEncounterId({ identifier: 'UNKNOWN0001' })).rejects.toMatchObject({
      message: 'errors.encounter.not_found',
      statusCode: 404,
    });
  });
});
