jest.mock('@prisma/client', () => ({
  break_glass_access: {
    findMany: jest.fn(),
    updateMany: jest.fn()}}));
jest.mock('@lib/audit', () => ({
  createRequiredAuditLog: jest.fn()}));
jest.mock('@lib/last-office/events', () => ({
  ACCESS_CONTROL_EVENTS: {
    BREAK_GLASS_REVOKED: 'access.break_glass_revoked'},
  emitAccessControlEvent: jest.fn()}));
jest.mock('@lib/logging', () => ({
  logger: { error: jest.fn() }}));

const prisma = require('@prisma/client');
const { createRequiredAuditLog } = require('@lib/audit');
const { emitAccessControlEvent } = require('@lib/last-office/events');
const {
  expireBreakGlassAccesses} = require('@lib/authorization/break-glass-expiry');

describe('break-glass expiry runtime', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('expires active grants and persists audit evidence', async () => {
    const now = new Date('2026-07-14T20:00:00.000Z');
    prisma.break_glass_access.findMany.mockResolvedValue([
      {
        id: 'access-1',
        human_friendly_id: 'BGA-001',
        tenant_id: 'tenant-1',
        facility_id: 'facility-1',
        expires_at: new Date('2026-07-14T19:59:00.000Z'),
        version: 2}]);
    prisma.break_glass_access.updateMany.mockResolvedValue({ count: 1 });
    createRequiredAuditLog.mockResolvedValue();
    emitAccessControlEvent.mockResolvedValue();

    await expect(expireBreakGlassAccesses(now)).resolves.toBe(1);

    expect(prisma.break_glass_access.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: 'EXPIRED' })})
    );
    expect(createRequiredAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        tenant_id: 'tenant-1',
        entity: 'break_glass_access',
        entity_id: 'access-1'})
    );
    expect(emitAccessControlEvent).toHaveBeenCalledWith(
      expect.objectContaining({
        payload: expect.objectContaining({ status: 'EXPIRED' })})
    );
  });
});
