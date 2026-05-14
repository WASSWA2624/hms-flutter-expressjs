const icuStayService = require('@services/icu-stay/icu-stay.service');
const icuStayRepository = require('@repositories/icu-stay/icu-stay.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');
const { resolveModelIdByIdentifier } = require('@lib/identifiers/resolve-entity-id');

jest.mock('@repositories/icu-stay/icu-stay.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/resolve-entity-id');

const buildInternalIcuStay = () => ({
  id: '550e8400-e29b-41d4-a716-446655440110',
  human_friendly_id: 'ICU-001',
  admission: {
    id: '550e8400-e29b-41d4-a716-446655440120',
    tenant_id: 'tenant-001',
    human_friendly_id: 'ADM-001',
    patient: {
      id: '550e8400-e29b-41d4-a716-446655440130',
      human_friendly_id: 'PAT-001',
      first_name: 'Jane',
      last_name: 'Doe',
    },
  },
  started_at: '2026-03-04T08:30:00.000Z',
  ended_at: null,
  created_at: '2026-03-04T08:30:00.000Z',
  updated_at: '2026-03-04T08:30:00.000Z',
});

describe('ICU Stay Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
  });

  describe('listIcuStays', () => {
    it('maps ICU stays to public identifiers only', async () => {
      icuStayRepository.findMany.mockResolvedValue([buildInternalIcuStay()]);
      icuStayRepository.count.mockResolvedValue(1);

      const result = await icuStayService.listIcuStays(
        {},
        1,
        20,
        'created_at',
        'desc'
      );

      expect(result.icu_stays[0]).toMatchObject({
        id: 'ICU-001',
        display_id: 'ICU-001',
        admission_id: 'ADM-001',
        patient_display_id: 'PAT-001',
        patient_display_name: 'Jane Doe',
      });
      expect(result.icu_stays[0].admission.id).toBe('ADM-001');
      expect(result.icu_stays[0].admission.patient.id).toBe('PAT-001');
      expect(result.icu_stays[0].admission.tenant_id).toBeUndefined();
    });

    it('resolves admission filters before querying the repository', async () => {
      resolveModelIdByIdentifier.mockResolvedValueOnce({
        id: '550e8400-e29b-41d4-a716-446655440120',
        tenant_id: 'tenant-001',
      });
      icuStayRepository.findMany.mockResolvedValue([]);
      icuStayRepository.count.mockResolvedValue(0);

      await icuStayService.listIcuStays(
        { admission_id: 'ADM-001' },
        1,
        20,
        'created_at',
        'desc'
      );

      expect(resolveModelIdByIdentifier).toHaveBeenCalledWith(
        expect.objectContaining({
          model: 'admission',
          identifier: 'ADM-001',
        })
      );
      expect(icuStayRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          admission_id: '550e8400-e29b-41d4-a716-446655440120',
        }),
        0,
        20,
        { created_at: 'desc' },
        expect.any(Object)
      );
    });
  });

  describe('getIcuStayById', () => {
    it('loads ICU stays by resolved internal id and returns the public shape', async () => {
      resolveModelIdByIdentifier.mockResolvedValueOnce({
        id: '550e8400-e29b-41d4-a716-446655440110',
      });
      icuStayRepository.findById.mockResolvedValue(buildInternalIcuStay());

      const result = await icuStayService.getIcuStayById('ICU-001');

      expect(icuStayRepository.findById).toHaveBeenCalledWith(
        '550e8400-e29b-41d4-a716-446655440110',
        expect.any(Object)
      );
      expect(result.id).toBe('ICU-001');
    });

    it('throws when the ICU stay cannot be resolved', async () => {
      resolveModelIdByIdentifier.mockResolvedValueOnce(null);

      await expect(icuStayService.getIcuStayById('ICU-404')).rejects.toThrow(
        HttpError
      );
    });
  });

  describe('createIcuStay', () => {
    it('creates ICU stays with internal ids and writes tenant-aware audit logs', async () => {
      resolveModelIdByIdentifier.mockResolvedValueOnce({
        id: '550e8400-e29b-41d4-a716-446655440120',
        tenant_id: 'tenant-001',
      });
      icuStayRepository.create.mockResolvedValue({
        id: '550e8400-e29b-41d4-a716-446655440110',
      });
      icuStayRepository.findById.mockResolvedValue(buildInternalIcuStay());

      const result = await icuStayService.createIcuStay(
        { admission_id: 'ADM-001', started_at: '2026-03-04T08:30:00.000Z' },
        'user-001',
        '127.0.0.1'
      );

      expect(icuStayRepository.create).toHaveBeenCalledWith({
        admission_id: '550e8400-e29b-41d4-a716-446655440120',
        started_at: '2026-03-04T08:30:00.000Z',
      });
      expect(createAuditLog).toHaveBeenCalledWith({
        tenant_id: 'tenant-001',
        user_id: 'user-001',
        action: 'CREATE',
        entity: 'icu_stay',
        entity_id: '550e8400-e29b-41d4-a716-446655440110',
        diff: { after: buildInternalIcuStay() },
        ip_address: '127.0.0.1',
      });
      expect(result.id).toBe('ICU-001');
    });
  });

  describe('updateIcuStay', () => {
    it('updates ICU stays through the resolved internal identifier', async () => {
      resolveModelIdByIdentifier.mockResolvedValueOnce({
        id: '550e8400-e29b-41d4-a716-446655440110',
      });
      icuStayRepository.findById.mockResolvedValue(buildInternalIcuStay());
      icuStayRepository.update.mockResolvedValue({
        id: '550e8400-e29b-41d4-a716-446655440110',
      });

      await icuStayService.updateIcuStay(
        'ICU-001',
        { ended_at: '2026-03-04T11:00:00.000Z' },
        'user-001',
        '127.0.0.1'
      );

      expect(icuStayRepository.update).toHaveBeenCalledWith(
        '550e8400-e29b-41d4-a716-446655440110',
        { ended_at: '2026-03-04T11:00:00.000Z' }
      );
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-001',
          action: 'UPDATE',
        })
      );
    });
  });

  describe('deleteIcuStay', () => {
    it('deletes ICU stays through the resolved internal identifier', async () => {
      resolveModelIdByIdentifier.mockResolvedValueOnce({
        id: '550e8400-e29b-41d4-a716-446655440110',
      });
      icuStayRepository.findById.mockResolvedValue(buildInternalIcuStay());
      icuStayRepository.softDelete.mockResolvedValue({});

      await icuStayService.deleteIcuStay('ICU-001', 'user-001', '127.0.0.1');

      expect(icuStayRepository.softDelete).toHaveBeenCalledWith(
        '550e8400-e29b-41d4-a716-446655440110'
      );
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-001',
          action: 'DELETE',
        })
      );
    });
  });
});
