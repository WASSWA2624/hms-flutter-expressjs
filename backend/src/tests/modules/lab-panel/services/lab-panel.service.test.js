const { HttpError } = require('@lib/errors');

jest.mock('@repositories/lab-panel/lab-panel.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
}));
jest.mock('@services/lab-workspace/lab.shared', () => {
  const actual = jest.requireActual('@services/lab-workspace/lab.shared');
  return {
    ...actual,
    resolveModelIdOrThrow: jest.fn(),
    resolveModelRecordOrThrow: jest.fn(),
  };
});

const labPanelRepository = require('@repositories/lab-panel/lab-panel.repository');
const { createAuditLog } = require('@lib/audit');
const {
  resolveModelIdOrThrow,
  resolveModelRecordOrThrow,
} = require('@services/lab-workspace/lab.shared');
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
        unit: 'mg/dL',
      },
    },
  ],
  created_at: now,
  updated_at: now,
  tenant: {
    id: 'tenant-internal-1',
    human_friendly_id: 'TEN0000001',
  },
  ...overrides,
});

describe('lab-panel.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue(undefined);
  });

  it('lists lab panels with resolved tenant filters and serialized identifiers', async () => {
    resolveModelIdOrThrow.mockResolvedValue('tenant-internal-1');
    labPanelRepository.findMany.mockResolvedValue([buildPanelRecord()]);
    labPanelRepository.count.mockResolvedValue(1);

    const result = await labPanelService.listLabPanels(
      {
        tenant_id: 'TEN0000001',
        search: 'metabolic',
      },
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
      errorKey: 'errors.tenant.not_found',
    });
    expect(labPanelRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-internal-1',
        OR: expect.arrayContaining([
          { name: { contains: 'metabolic' } },
          { human_friendly_id: { contains: 'METABOLIC' } },
        ]),
      }),
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
            test_display_name: 'Glucose',
          }),
        ],
      }),
    ]);
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
      errorKey: 'errors.lab_panel.not_found',
    });
    expect(result).toEqual(
      expect.objectContaining({
        id: 'LBP0000001',
        tenant_id: 'TEN0000001',
      })
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
            unit: 'mg/dL',
          },
        },
      ],
    });
    resolveModelIdOrThrow
      .mockResolvedValueOnce('tenant-internal-1')
      .mockResolvedValueOnce('lab-test-internal-1')
      .mockResolvedValueOnce('tenant-internal-1')
      .mockResolvedValueOnce('lab-test-internal-2');
    resolveModelRecordOrThrow.mockResolvedValue(before);
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
            instructions: 'Collect fasting sample',
          },
        ],
      },
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
            instructions: 'Optional add-on',
          },
        ],
      },
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
            sort_order: 0,
          },
        ],
      },
    });
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
            sort_order: 0,
          },
        ],
      },
    });
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'CREATE',
        entity: 'lab_panel',
        ip_address: mockIpAddress,
      })
    );
    expect(created).toEqual(
      expect.objectContaining({
        id: 'LBP0000001',
      })
    );
    expect(updated).toEqual(
      expect.objectContaining({
        id: 'LBP0000001',
        name: 'Updated Panel',
      })
    );
  });

  it('deletes lab panels using the resolved internal identifier', async () => {
    resolveModelRecordOrThrow.mockResolvedValue(buildPanelRecord());
    labPanelRepository.softDelete.mockResolvedValue({ id: 'panel-internal-1' });

    const result = await labPanelService.deleteLabPanel(
      'LBP0000001',
      mockUserId,
      mockIpAddress
    );

    expect(labPanelRepository.softDelete).toHaveBeenCalledWith('panel-internal-1');
    expect(result).toEqual(
      expect.objectContaining({
        id: 'LBP0000001',
        name: 'Complete Metabolic Panel',
      })
    );
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
