const theatreFlowService = require('@services/theatre-flow/theatre-flow.service');
const theatreFlowRepository = require('@repositories/theatre-flow/theatre-flow.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@repositories/theatre-flow/theatre-flow.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({}),
}));
jest.mock('@prisma/client', () => ({
  tenant: { findFirst: jest.fn() },
  facility: { findFirst: jest.fn() },
  patient: { findFirst: jest.fn() },
  encounter: { findFirst: jest.fn() },
  room: { findFirst: jest.fn() },
  user: { findFirst: jest.fn() },
  staff_profile: { findFirst: jest.fn() },
  equipment_registry: { findFirst: jest.fn() },
  anesthesia_record: { findFirst: jest.fn() },
  post_op_note: { findFirst: jest.fn() },
  theatre_case_checklist_item: { findFirst: jest.fn(), findMany: jest.fn() },
  theatre_case_resource_allocation: { findFirst: jest.fn() },
  theatre_case: {
    findFirst: jest.fn(),
    update: jest.fn(),
    create: jest.fn(),
  },
  $transaction: jest.fn(),
}));

describe('theatre-flow.service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('lists theatre flows and returns pagination', async () => {
    theatreFlowRepository.findMany.mockResolvedValue([
      {
        id: 'uuid-case',
        human_friendly_id: 'TC-001',
        status: 'SCHEDULED',
        workflow_stage: 'PRE_OP',
        encounter: { id: 'uuid-enc', human_friendly_id: 'ENC-001', patient: null },
        checklist_items: [],
        resource_allocations: [],
        anesthesia_observations: [],
        anesthesia_records: [],
        post_op_notes: [],
      },
    ]);
    theatreFlowRepository.count.mockResolvedValue(1);

    const result = await theatreFlowService.listTheatreFlows({}, 1, 20, 'scheduled_at', 'desc');

    expect(result.items).toHaveLength(1);
    expect(result.items[0].id).toBe('TC-001');
    expect(result.pagination.total).toBe(1);
  });

  it('gets a theatre flow by friendly id', async () => {
    prisma.theatre_case.findFirst
      .mockResolvedValueOnce({ id: 'uuid-case', encounter_id: 'uuid-enc', status: 'SCHEDULED' })
      .mockResolvedValueOnce({ id: 'uuid-case', human_friendly_id: 'TC-001', workflow_stage: 'PRE_OP' });
    theatreFlowRepository.findById.mockResolvedValue({
      id: 'uuid-case',
      human_friendly_id: 'TC-001',
      status: 'SCHEDULED',
      workflow_stage: 'PRE_OP',
      encounter: { id: 'uuid-enc', human_friendly_id: 'ENC-001', patient: null },
      checklist_items: [],
      resource_allocations: [],
      anesthesia_observations: [],
      anesthesia_records: [],
      post_op_notes: [],
    });

    const result = await theatreFlowService.getTheatreFlowById('TC-001', { include_timeline: true });

    expect(result.id).toBe('TC-001');
    expect(result.encounter_display_id).toBe('ENC-001');
  });

  it('rejects unsupported legacy resources', async () => {
    await expect(theatreFlowService.resolveLegacyRoute('unknown-resource', 'ABC-1')).rejects.toThrow(HttpError);
  });
});

