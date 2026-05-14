const icuObservationService = require('@services/icu-observation/icu-observation.service');
const icuObservationRepository = require('@repositories/icu-observation/icu-observation.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');

jest.mock('@repositories/icu-observation/icu-observation.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/resolve-entity-id');

const buildInternalObservation = () => ({
  id: '550e8400-e29b-41d4-a716-446655440210',
  human_friendly_id: 'ICUOBS-001',
  observed_at: '2026-03-04T10:00:00.000Z',
  observation: 'Stable oxygen saturation',
  created_at: '2026-03-04T10:00:00.000Z',
  updated_at: '2026-03-04T10:00:00.000Z',
  icu_stay: {
    id: '550e8400-e29b-41d4-a716-446655440220',
    human_friendly_id: 'ICU-001',
    admission: {
      id: '550e8400-e29b-41d4-a716-446655440230',
      tenant_id: 'tenant-001',
      human_friendly_id: 'ADM-001',
      patient: {
        id: '550e8400-e29b-41d4-a716-446655440240',
        human_friendly_id: 'PAT-001',
        first_name: 'Jane',
        last_name: 'Doe',
      },
    },
  },
});

describe('ICU Observation Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  it('lists ICU observations with public identifiers only', async () => {
    icuObservationRepository.findMany.mockResolvedValue([buildInternalObservation()]);
    icuObservationRepository.count.mockResolvedValue(1);

    const result = await icuObservationService.listIcuObservations(
      {},
      1,
      20,
      'created_at',
      'desc'
    );

    expect(result.icu_observations[0]).toMatchObject({
      id: 'ICUOBS-001',
      icu_stay_id: 'ICU-001',
      admission_display_id: 'ADM-001',
      patient_display_id: 'PAT-001',
      patient_display_name: 'Jane Doe',
    });
    expect(result.icu_observations[0].icu_stay.admission.patient.id).toBe(
      'PAT-001'
    );
  });

  it('resolves ICU stay filters before querying the repository', async () => {
    resolveModelIdByIdentifier.mockResolvedValueOnce({
      id: '550e8400-e29b-41d4-a716-446655440220',
      admission: { tenant_id: 'tenant-001' },
    });
    icuObservationRepository.findMany.mockResolvedValue([]);
    icuObservationRepository.count.mockResolvedValue(0);

    await icuObservationService.listIcuObservations(
      { icu_stay_id: 'ICU-001' },
      1,
      20,
      'created_at',
      'desc'
    );

    expect(icuObservationRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        icu_stay_id: '550e8400-e29b-41d4-a716-446655440220',
      }),
      0,
      20,
      { created_at: 'desc' },
      expect.any(Object)
    );
  });

  it('creates observations with internal ids and tenant-aware audit logs', async () => {
    resolveModelIdByIdentifier.mockResolvedValueOnce({
      id: '550e8400-e29b-41d4-a716-446655440220',
      admission: { tenant_id: 'tenant-001' },
    });
    icuObservationRepository.create.mockResolvedValue({
      id: '550e8400-e29b-41d4-a716-446655440210',
    });
    icuObservationRepository.findById.mockResolvedValue(buildInternalObservation());

    const result = await icuObservationService.createIcuObservation(
      {
        icu_stay_id: 'ICU-001',
        observation: 'Stable oxygen saturation',
      },
      'user-001',
      '127.0.0.1'
    );

    expect(icuObservationRepository.create).toHaveBeenCalledWith({
      icu_stay_id: '550e8400-e29b-41d4-a716-446655440220',
      observation: 'Stable oxygen saturation',
    });
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-001',
        action: 'CREATE',
        entity: 'icu_observation',
      })
    );
    expect(result.id).toBe('ICUOBS-001');
  });

  it('updates and deletes by resolved public identifier', async () => {
    resolveModelIdByIdentifier.mockResolvedValue({
      id: '550e8400-e29b-41d4-a716-446655440210',
    });
    icuObservationRepository.findById.mockResolvedValue(buildInternalObservation());
    icuObservationRepository.update.mockResolvedValue({
      id: '550e8400-e29b-41d4-a716-446655440210',
    });
    icuObservationRepository.softDelete.mockResolvedValue({});

    await icuObservationService.updateIcuObservation(
      'ICUOBS-001',
      { observation: 'Escalated monitoring' },
      'user-001',
      '127.0.0.1'
    );
    await icuObservationService.deleteIcuObservation(
      'ICUOBS-001',
      'user-001',
      '127.0.0.1'
    );

    expect(icuObservationRepository.update).toHaveBeenCalledWith(
      '550e8400-e29b-41d4-a716-446655440210',
      { observation: 'Escalated monitoring' }
    );
    expect(icuObservationRepository.softDelete).toHaveBeenCalledWith(
      '550e8400-e29b-41d4-a716-446655440210'
    );
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-001',
        action: 'DELETE',
      })
    );
  });

  it('throws when the ICU observation cannot be resolved', async () => {
    resolveModelIdByIdentifier.mockResolvedValueOnce(null);

    await expect(
      icuObservationService.getIcuObservationById('ICUOBS-404')
    ).rejects.toThrow(HttpError);
  });
});
