jest.mock('@repositories/opd-flow/opd-flow.repository', () => ({}));
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn(),
}));
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  OPD_EVENTS: {},
  NOTIFICATION_EVENTS: {},
}));
jest.mock('@services/clinical-alert-threshold/clinical-alert-threshold.service', () => ({}));
jest.mock('@prisma/client', () => ({
  emergency_case: { findFirst: jest.fn() },
  triage_assessment: { findFirst: jest.fn() },
  emergency_response: { findFirst: jest.fn() },
  ambulance: { findFirst: jest.fn() },
  ambulance_dispatch: { findFirst: jest.fn() },
  ambulance_trip: { findFirst: jest.fn() },
  encounter: { findFirst: jest.fn() },
}));

const prisma = require('@prisma/client');
const opdFlowService = require('@services/opd-flow/opd-flow.service');

describe('opd-flow.service resolveLegacyRoute', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('maps ambulance dispatch legacy ids to emergency workbench context', async () => {
    prisma.ambulance_dispatch.findFirst.mockResolvedValue({
      id: 'a9ca2c62-b6c0-4a66-9118-cf0210ed455f',
      human_friendly_id: 'ADP0000001',
      emergency_case_id: '5bd999be-6088-4f6a-871a-6dd74ecef8f5',
      ambulance_id: 'c65e9694-6d5c-4666-97f4-355acfd9fbf4',
    });
    prisma.emergency_case.findFirst.mockResolvedValue({
      id: '5bd999be-6088-4f6a-871a-6dd74ecef8f5',
      human_friendly_id: 'EMC0000001',
    });
    prisma.ambulance.findFirst.mockResolvedValue({
      id: 'c65e9694-6d5c-4666-97f4-355acfd9fbf4',
      human_friendly_id: 'AMB0000001',
    });
    prisma.encounter.findFirst.mockResolvedValue({
      id: 'f03f97cd-cfc8-4215-b5ab-124f8f190de3',
      human_friendly_id: 'ENC0000001',
    });

    const result = await opdFlowService.resolveLegacyRoute(
      'ambulance-dispatches',
      'ADP0000001'
    );

    expect(result).toEqual({
      encounter_id: 'ENC0000001',
      emergency_case_id: 'EMC0000001',
      ambulance_id: 'AMB0000001',
      resource: 'ambulance-dispatches',
      resource_id: 'ADP0000001',
      panel: 'dispatch',
      action: 'manage_dispatch',
    });
  });

  it('returns panel/action context even when encounter mapping is unavailable', async () => {
    prisma.emergency_response.findFirst.mockResolvedValue({
      id: '602eb80e-4ec0-469a-9f35-88f4fb70a6bf',
      human_friendly_id: 'ERS0000001',
      emergency_case_id: '5bd999be-6088-4f6a-871a-6dd74ecef8f5',
    });
    prisma.emergency_case.findFirst.mockResolvedValue({
      id: '5bd999be-6088-4f6a-871a-6dd74ecef8f5',
      human_friendly_id: 'EMC0000001',
    });
    prisma.encounter.findFirst.mockResolvedValue(null);

    const result = await opdFlowService.resolveLegacyRoute(
      'emergency-responses',
      'ERS0000001'
    );

    expect(result).toMatchObject({
      encounter_id: null,
      emergency_case_id: 'EMC0000001',
      resource: 'emergency-responses',
      resource_id: 'ERS0000001',
      panel: 'responses',
      action: 'add_response',
    });
  });
});
