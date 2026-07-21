jest.mock('@repositories/opd-flow/opd-flow.repository');
jest.mock('@lib/audit', () => ({ createAuditLog: jest.fn().mockResolvedValue({}) }));
jest.mock('@services/ipd-flow/ipd-flow.service', () => ({
  emitAdmissionRefreshEvent: jest.fn().mockResolvedValue(null)}));
jest.mock(
  '@services/clinical-alert-threshold/clinical-alert-threshold.service',
  () => ({ evaluateVitalAndCreateAlerts: jest.fn().mockResolvedValue(null) })
);
jest.mock('@lib/websocket', () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  OPD_EVENTS: { OPD_FLOW_UPDATED: 'opd.flow.updated' },
  NOTIFICATION_EVENTS: { NOTIFICATION_CREATED: 'notification.created' }}));

jest.mock('@prisma/client', () => ({
  $transaction: jest.fn(),
  encounter: { findFirst: jest.fn(), update: jest.fn() },
  user_role: { findMany: jest.fn().mockResolvedValue([]) },
  notification: { create: jest.fn() },
  notification_delivery: { createMany: jest.fn() }}));

const prisma = require('@prisma/client');
const opdFlowService = require('@services/opd-flow/opd-flow.service');

const txEncounter = prisma.encounter;

const buildEncounter = (overrides = {}) => ({
  id: 'encounter-1',
  human_friendly_id: 'ENC0000001',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  encounter_type: 'OPD',
  status: 'OPEN',
  provider_user_id: 'doctor-1',
  extension_json: {
    opd_flow: { stage: 'LAB_REQUESTED', next_step: 'LAB_WORKSPACE' }},
  vital_signs: [{ id: 'v1', deleted_at: null }],
  admissions: [],
  lab_orders: [],
  radiology_orders: [],
  pharmacy_orders: [],
  ...overrides});

const completedLabOrder = {
  status: 'COMPLETED',
  deleted_at: null,
  items: [
    {
      deleted_at: null,
      status: 'COMPLETED',
      results: [{ deleted_at: null, status: 'NORMAL' }]}],
  samples: [{ deleted_at: null, status: 'RECEIVED' }]};

const completedLabOrderWithCancelledItem = {
  status: 'IN_PROCESS',
  deleted_at: null,
  items: [
    {
      deleted_at: null,
      status: 'COMPLETED',
      results: [{ deleted_at: null, status: 'NORMAL' }]},
    {
      deleted_at: null,
      status: 'CANCELLED',
      results: []}],
  samples: [{ deleted_at: null, status: 'PENDING' }]};

const pendingLabOrder = {
  status: 'IN_PROCESS',
  deleted_at: null,
  items: [
    {
      deleted_at: null,
      status: 'IN_PROCESS',
      results: [{ deleted_at: null, status: 'PENDING' }]}],
  samples: [{ deleted_at: null, status: 'RECEIVED' }]};

describe('opd-flow syncDiagnosticsStage', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    prisma.$transaction.mockImplementation((callback) => callback(prisma));
    txEncounter.update.mockImplementation(async ({ data }) => ({
      id: 'encounter-1',
      ...data}));
  });

  it('is a no-op when the encounter cannot be resolved', async () => {
    txEncounter.findFirst.mockResolvedValue(null);
    const result = await opdFlowService.syncDiagnosticsStage('ENC0000001');
    expect(result).toBeNull();
    expect(txEncounter.update).not.toHaveBeenCalled();
  });

  it('does not advance while lab work is still pending', async () => {
    txEncounter.findFirst.mockResolvedValue(
      buildEncounter({ lab_orders: [pendingLabOrder] })
    );
    const result = await opdFlowService.syncDiagnosticsStage('ENC0000001');
    expect(result).toBeNull();
    expect(txEncounter.update).not.toHaveBeenCalled();
  });

  it('does nothing when the encounter is not parked in a diagnostics stage', async () => {
    txEncounter.findFirst.mockResolvedValue(
      buildEncounter({
        extension_json: { opd_flow: { stage: 'WAITING_DISPOSITION' } },
        lab_orders: [completedLabOrder]})
    );
    const result = await opdFlowService.syncDiagnosticsStage('ENC0000001');
    expect(result).toBeNull();
    expect(txEncounter.update).not.toHaveBeenCalled();
  });

  it('advances out of LAB_REQUESTED to WAITING_DISPOSITION once lab work is complete', async () => {
    txEncounter.findFirst
      .mockResolvedValueOnce(buildEncounter({ lab_orders: [completedLabOrder] }))
      .mockResolvedValue(null);

    await opdFlowService.syncDiagnosticsStage('ENC0000001', {
      trigger: 'LAB_RESULTS_VERIFIED'});

    expect(txEncounter.update).toHaveBeenCalledTimes(1);
    const updateArg = txEncounter.update.mock.calls[0][0];
    expect(updateArg.where).toEqual({ id: 'encounter-1' });
    expect(updateArg.data.extension_json.opd_flow.stage).toBe('WAITING_DISPOSITION');
  });

  it('advances when only active lab items are complete and cancelled items remain', async () => {
    txEncounter.findFirst
      .mockResolvedValueOnce(
        buildEncounter({ lab_orders: [completedLabOrderWithCancelledItem] })
      )
      .mockResolvedValue(null);

    await opdFlowService.syncDiagnosticsStage('ENC0000001', {
      trigger: 'LAB_RESULTS_VERIFIED'});

    expect(txEncounter.update).toHaveBeenCalledTimes(1);
    const updateArg = txEncounter.update.mock.calls[0][0];
    expect(updateArg.data.extension_json.opd_flow.stage).toBe('WAITING_DISPOSITION');
  });

  it('clears only the lab portion when radiology is still pending', async () => {
    txEncounter.findFirst
      .mockResolvedValueOnce(
        buildEncounter({
          extension_json: { opd_flow: { stage: 'LAB_AND_RADIOLOGY_REQUESTED' } },
          lab_orders: [completedLabOrder],
          radiology_orders: [
            { status: 'IN_PROCESS', deleted_at: null, results: [], imaging_studies: [] }]})
      )
      .mockResolvedValue(null);

    await opdFlowService.syncDiagnosticsStage('ENC0000001');

    expect(txEncounter.update).toHaveBeenCalledTimes(1);
    const updateArg = txEncounter.update.mock.calls[0][0];
    expect(updateArg.data.extension_json.opd_flow.stage).toBe('RADIOLOGY_REQUESTED');
  });
});
