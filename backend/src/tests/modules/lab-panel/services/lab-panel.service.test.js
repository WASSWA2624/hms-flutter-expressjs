const { HttpError } = require('@lib/errors');

jest.mock('@repositories/lab-panel/lab-panel.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn()}));
jest.mock('@lib/websocket/crud-realtime', () => ({
  publishCrudRealtimeEvent: jest.fn().mockResolvedValue(0)
}));
jest.mock('@prisma/client', () => ({
  lab_test: {
    findFirst: jest.fn(),
    create: jest.fn()
  }
}));
jest.mock('@services/lab-workspace/lab.shared', () => {
  const actual = jest.requireActual('@services/lab-workspace/lab.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
    resolveModelRecordOrThrow: jest.fn()};
});

const labPanelRepository = require('@repositories/lab-panel/lab-panel.repository');
const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow} = require('@services/lab-workspace/lab.shared');
const labPanelService = require('@services/lab-panel/lab-panel.service');

const mockUserId = 'user-123';
const mockIpAddress = '127.0.0.1';
const now = new Date('2026-02-27T09:15:00.000Z');

const buildPanelRecord = (overrides = {}) => ({
  id: 'panel-internal-1',
  human_friendly_id: 'LBP0000001',
  tenant_id: 'tenant-internal-1',
  name: 'Complete Metabolic Panel',
  code: 'CMP',
  category: 'Chemistry',
  description: 'Expanded chemistry panel',
  panel_items: [
    {
      id: 'panel-item-internal-1',
      lab_test_id: 'lab-test-internal-1',
      is_required: true,
      instructions: 'Collect fasting sample',
      sort_order: 0,
      lab_test: {
        id: 'lab-test-internal-1',
        human_friendly_id: 'LBT0000001',
        name: 'Glucose',
        code: 'GLU',
        unit: 'mg/dL'}}],
  created_at: now,
  updated_at: now,
  tenant: {
    id: 'tenant-internal-1',
    human_friendly_id: 'TEN0000001'},
  ...overrides});

describe('lab-panel.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
    prisma.lab_test.findFirst.mockResolvedValue(null);
    prisma.lab_test.create.mockResolvedValue({
      id: 'lab-test-internal-std',
      human_friendly_id: 'LBT0000099',
      code: '42176-8'
    });
  });

  it('lists lab panels with resolved tenant filters and serialized identifiers', async () => {
    resolveModelIdOrThrow.mockResolvedValue('tenant-internal-1');
    labPanelRepository.findMany.mockResolvedValue([buildPanelRecord()]);
    labPanelRepository.count.mockResolvedValue(1);

    const result = await labPanelService.listLabPanels(
      {
        tenant_id: 'TEN0000001',
        search: 'metabolic'},
      1,
      20,
      'name',
      'asc',
      mockUserId,
      mockIpAddress
    );

    expect(resolveModelIdOrThrow).toHaveBeenCalledWith({
      identifier: 'TEN0000001',
      model: 'tenant',
      where: { deleted_at: null },
      errorKey: 'errors.tenant.not_found'});
    expect(labPanelRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-internal-1',
        OR: expect.arrayContaining([
          { name: { contains: 'metabolic' } },
          { human_friendly_id: { contains: 'METABOLIC' } }])}),
      0,
      20,
      { name: 'asc' },
      expect.any(Object)
    );
    expect(result.labPanels).toEqual([
      expect.objectContaining({
        id: 'LBP0000001',
        display_id: 'LBP0000001',
        tenant_id: 'TEN0000001',
        name: 'Complete Metabolic Panel',
        code: 'CMP',
        category: 'Chemistry',
        panel_items: [
          expect.objectContaining({
            lab_test_id: 'LBT0000001',
            test_display_name: 'Glucose'})]})]);
  });

  it('gets a lab panel by friendly identifier through shared resolution', async () => {
    resolveModelRecordOrThrow.mockResolvedValue(buildPanelRecord());

    const result = await labPanelService.getLabPanelById(
      'LBP0000001',
      mockUserId,
      mockIpAddress
    );

    expect(resolveModelRecordOrThrow).toHaveBeenCalledWith({
      identifier: 'LBP0000001',
      model: 'lab_panel',
      where: { deleted_at: null },
      include: expect.any(Object),
      errorKey: 'errors.lab_panel.not_found'});
    expect(result).toEqual(
      expect.objectContaining({
        id: 'LBP0000001',
        tenant_id: 'TEN0000001'})
    );
  });

  it('creates and updates lab panels with resolved tenant identifiers', async () => {
    const before = buildPanelRecord();
    const after = buildPanelRecord({
      name: 'Updated Panel',
      panel_items: [
        {
          id: 'panel-item-internal-2',
          lab_test_id: 'lab-test-internal-2',
          is_required: false,
          instructions: 'Optional add-on',
          sort_order: 0,
          lab_test: {
            id: 'lab-test-internal-2',
            human_friendly_id: 'LBT0000002',
            name: 'Calcium',
            code: 'CA',
            unit: 'mg/dL'}}]});
    const labTest1 = {
      id: 'lab-test-internal-1',
      human_friendly_id: 'LBT0000001',
      code: 'GLU',
      name: 'Glucose',
      tenant_id: 'tenant-internal-1'
    };
    const labTest2 = {
      id: 'lab-test-internal-2',
      human_friendly_id: 'LBT0000002',
      code: 'CA',
      name: 'Calcium',
      tenant_id: 'tenant-internal-1'
    };
    resolveModelIdOrThrow
      .mockResolvedValueOnce('tenant-internal-1')
      .mockResolvedValueOnce('tenant-internal-1');
    resolveModelRecordOrThrow
      .mockResolvedValueOnce(labTest1) // create enrich
      .mockResolvedValueOnce(labTest1) // create write resolve
      .mockResolvedValueOnce(before) // update load panel
      .mockResolvedValueOnce(labTest2) // update enrich
      .mockResolvedValueOnce(labTest2); // update write resolve
    labPanelRepository.findMany.mockResolvedValue([]);
    labPanelRepository.create.mockResolvedValue({ id: 'panel-internal-1' });
    labPanelRepository.update.mockResolvedValue({ id: 'panel-internal-1' });
    labPanelRepository.findById
      .mockResolvedValueOnce(before)
      .mockResolvedValueOnce(after);

    const created = await labPanelService.createLabPanel(
      {
        tenant_id: 'TEN0000001',
        name: 'Complete Metabolic Panel',
        code: 'CMP',
        category: 'Chemistry',
        description: 'Expanded chemistry panel',
        panel_items: [
          {
            lab_test_id: 'LBT0000001',
            is_required: true,
            instructions: 'Collect fasting sample'}]},
      mockUserId,
      mockIpAddress
    );
    const updated = await labPanelService.updateLabPanel(
      'LBP0000001',
      {
        tenant_id: 'TEN0000001',
        name: 'Updated Panel',
        category: 'Chemistry',
        description: 'Updated chemistry panel',
        panel_items: [
          {
            lab_test_id: 'LBT0000002',
            is_required: false,
            instructions: 'Optional add-on'}]},
      mockUserId,
      mockIpAddress
    );

    expect(labPanelRepository.create).toHaveBeenCalledWith({
      tenant_id: 'tenant-internal-1',
      name: 'Complete Metabolic Panel',
      code: 'CMP',
      category: 'Chemistry',
      description: 'Expanded chemistry panel',
      panel_items: {
        create: [
          {
            lab_test_id: 'lab-test-internal-1',
            is_required: true,
            instructions: 'Collect fasting sample',
            sort_order: 0}]}});
    expect(labPanelRepository.update).toHaveBeenCalledWith('panel-internal-1', {
      tenant_id: 'tenant-internal-1',
      name: 'Updated Panel',
      category: 'Chemistry',
      description: 'Updated chemistry panel',
      panel_items: {
        deleteMany: {},
        create: [
          {
            lab_test_id: 'lab-test-internal-2',
            is_required: false,
            instructions: 'Optional add-on',
            sort_order: 0}]}});
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'lab_panel',
        ip_address: mockIpAddress})
    );
    expect(created).toEqual(
      expect.objectContaining({
        id: 'LBP0000001'})
    );
    expect(updated).toEqual(
      expect.objectContaining({
        id: 'LBP0000001',
        name: 'Updated Panel'})
    );
  });

  it('materializes standard catalog member tests when creating a panel', async () => {
    const createdRecord = buildPanelRecord({
      name: 'Beta Glucan Panel',
      code: 'BGP-1'
    });
    resolveModelIdOrThrow.mockResolvedValue('tenant-internal-1');
    prisma.lab_test.findFirst
      .mockResolvedValueOnce(null) // enrich (virtual)
      .mockResolvedValueOnce(null); // write materialize lookup
    prisma.lab_test.create.mockResolvedValue({
      id: 'lab-test-internal-std',
      human_friendly_id: 'LBT0000099',
      code: '42176-8'
    });
    labPanelRepository.findMany.mockResolvedValue([]);
    labPanelRepository.create.mockResolvedValue({ id: 'panel-internal-1' });
    labPanelRepository.findById.mockResolvedValue(createdRecord);

    await labPanelService.createLabPanel(
      {
        tenant_id: 'TEN0000001',
        name: 'Beta Glucan Panel',
        code: 'BGP-1',
        category: 'Chemistry',
        panel_items: [{ lab_test_id: 'STD_LAB_TEST:LOINC_42176_8' }]
      },
      mockUserId,
      mockIpAddress
    );

    expect(prisma.lab_test.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          tenant_id: 'tenant-internal-1',
          code: '42176-8',
          name: '1,3 beta glucan [Mass/volume] in Serum'
        })
      })
    );
    expect(labPanelRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        panel_items: {
          create: [
            expect.objectContaining({
              lab_test_id: 'lab-test-internal-std'
            })
          ]
        }
      })
    );
  });

  it('rejects similar panels without confirm_similar', async () => {
    resolveModelIdOrThrow.mockResolvedValue('tenant-internal-1');
    resolveModelRecordOrThrow.mockResolvedValue({
      id: 'lab-test-internal-1',
      human_friendly_id: 'LBT0000001',
      code: 'GLU'
    });
    labPanelRepository.findMany.mockResolvedValue([
      {
        id: 'existing-1',
        name: 'Zzyx Custom Chemistry Alph',
        code: 'OTHER',
        category: 'Chemistry',
        panel_items: [{ lab_test_id: 't1', test_code: 'GLU' }]
      }
    ]);

    await expect(
      labPanelService.createLabPanel(
        {
          tenant_id: 'TEN0000001',
          name: 'Zzyx Custom Chemistry Alpha',
          code: 'NEW-001',
          category: 'Chemistry',
          panel_items: [{ lab_test_id: 'LBT0000001' }]
        },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_panel.similar_exists',
      statusCode: 409
    });
    expect(labPanelRepository.create).not.toHaveBeenCalled();
  });

  it('rejects composition-overlapping panels when only lab_test_id is sent', async () => {
    resolveModelIdOrThrow.mockResolvedValue('tenant-internal-1');
    resolveModelRecordOrThrow.mockResolvedValue({
      id: 'lab-test-internal-1',
      human_friendly_id: 'LBT0000001',
      code: 'HB'
    });
    labPanelRepository.findMany.mockResolvedValue([
      {
        id: 'existing-panel',
        name: 'Hematology Bundle',
        code: 'HEM-B',
        category: 'Chemistry',
        panel_items: [
          {
            lab_test_id: 'lab-test-internal-1',
            lab_test: { id: 'lab-test-internal-1', code: 'HB' }
          }
        ]
      }
    ]);

    await expect(
      labPanelService.createLabPanel(
        {
          tenant_id: 'TEN0000001',
          name: 'Unrelated Panel Name',
          code: 'OTHER-1',
          category: 'Admission',
          panel_items: [{ lab_test_id: 'LBT0000001' }]
        },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_panel.similar_exists',
      statusCode: 409
    });
  });

  it('creates when confirm_similar is true for near matches', async () => {
    const createdRecord = buildPanelRecord({
      name: 'Zzyx Custom Chemistry Alpha',
      code: 'NEW-001'
    });
    resolveModelIdOrThrow.mockResolvedValueOnce('tenant-internal-1');
    resolveModelRecordOrThrow.mockResolvedValue({
      id: 'lab-test-internal-1',
      human_friendly_id: 'LBT0000001',
      code: 'GLU'
    });
    labPanelRepository.findMany.mockResolvedValue([
      {
        id: 'existing-1',
        name: 'Zzyx Custom Chemistry Alph',
        code: 'OTHER',
        category: 'Chemistry',
        panel_items: [{ lab_test_id: 't1', test_code: 'GLU' }]
      }
    ]);
    labPanelRepository.create.mockResolvedValue({ id: 'panel-internal-1' });
    labPanelRepository.findById.mockResolvedValue(createdRecord);

    const result = await labPanelService.createLabPanel(
      {
        tenant_id: 'TEN0000001',
        name: 'Zzyx Custom Chemistry Alpha',
        code: 'NEW-001',
        category: 'Chemistry',
        confirm_similar: true,
        panel_items: [{ lab_test_id: 'LBT0000001' }]
      },
      mockUserId,
      mockIpAddress
    );

    expect(result).toEqual(
      expect.objectContaining({
        name: 'Zzyx Custom Chemistry Alpha',
        code: 'NEW-001'
      })
    );
    expect(labPanelRepository.create).toHaveBeenCalled();
    expect(labPanelRepository.create.mock.calls[0][0].confirm_similar).toBeUndefined();
  });

  it('updates when confirm_similar is true for near matches', async () => {
    const before = buildPanelRecord({
      name: 'Unique Source Panel',
      code: 'USP-1'
    });
    const after = buildPanelRecord({
      name: 'Zzyx Custom Chemistry Alpha',
      code: 'USP-1'
    });
    resolveModelRecordOrThrow
      .mockResolvedValueOnce(before)
      .mockResolvedValue({
        id: 'lab-test-internal-1',
        human_friendly_id: 'LBT0000001',
        code: 'GLU'
      });
    labPanelRepository.findMany.mockResolvedValue([
      {
        id: 'existing-1',
        name: 'Zzyx Custom Chemistry Alph',
        code: 'OTHER',
        category: 'Chemistry',
        panel_items: [{ lab_test_id: 't1', test_code: 'GLU' }]
      }
    ]);
    labPanelRepository.update.mockResolvedValue({ id: 'panel-internal-1' });
    labPanelRepository.findById.mockResolvedValue(after);

    const result = await labPanelService.updateLabPanel(
      'LBP0000001',
      {
        name: 'Zzyx Custom Chemistry Alpha',
        confirm_similar: true,
        panel_items: [{ lab_test_id: 'LBT0000001' }]
      },
      mockUserId,
      mockIpAddress
    );

    expect(result).toEqual(
      expect.objectContaining({
        name: 'Zzyx Custom Chemistry Alpha'
      })
    );
    expect(labPanelRepository.update.mock.calls[0][1].confirm_similar).toBeUndefined();
  });

  it('rejects exact duplicate panel names without confirm_similar', async () => {
    resolveModelIdOrThrow.mockResolvedValue('tenant-internal-1');
    resolveModelRecordOrThrow.mockResolvedValue({
      id: 'lab-test-internal-1',
      human_friendly_id: 'LBT0000001',
      code: 'GLU'
    });
    labPanelRepository.findMany.mockResolvedValue([
      buildPanelRecord({
        id: 'existing-panel',
        name: 'Complete Metabolic Panel',
        code: 'OTHER'
      })
    ]);

    await expect(
      labPanelService.createLabPanel(
        {
          tenant_id: 'TEN0000001',
          name: 'Complete Metabolic Panel',
          code: 'NEW-CMP',
          panel_items: [{ lab_test_id: 'LBT0000001' }]
        },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toMatchObject({
      message: 'errors.lab_panel.duplicate_name',
      statusCode: 409
    });
  });

  it('deletes lab panels using the resolved internal identifier', async () => {
    resolveModelRecordOrThrow.mockResolvedValue(buildPanelRecord());
    labPanelRepository.softDelete.mockResolvedValue({ id: 'panel-internal-1' });

    const result = await labPanelService.deleteLabPanel(
      'LBP0000001',
      { reason: 'Duplicate panel configuration' },
      mockUserId,
      mockIpAddress
    );

    expect(labPanelRepository.softDelete).toHaveBeenCalledWith('panel-internal-1');
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'DELETE',
        entity: 'lab_panel',
        diff: expect.objectContaining({
          deletion_reason: 'Duplicate panel configuration'})})
    );
    expect(result).toEqual(
      expect.objectContaining({
        id: 'LBP0000001',
        name: 'Complete Metabolic Panel'})
    );
  });

  it('requires a deletion reason when deleting lab panels', async () => {
    await expect(
      labPanelService.deleteLabPanel(
        'LBP0000001',
        { reason: ' ' },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toMatchObject({
      message: 'errors.validation.required',
      statusCode: 400});
    expect(labPanelRepository.softDelete).not.toHaveBeenCalled();
  });

  it('rethrows HttpError instances without wrapping them', async () => {
    const error = new HttpError('errors.tenant.not_found', 404);
    resolveModelIdOrThrow.mockRejectedValue(error);

    await expect(
      labPanelService.createLabPanel(
        { tenant_id: 'missing-tenant', name: 'Test', code: 'TST' },
        mockUserId,
        mockIpAddress
      )
    ).rejects.toBe(error);
  });
});
