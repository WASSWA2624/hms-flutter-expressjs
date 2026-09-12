/**
 * User service permanent delete tests
 *
 * @module tests/modules/user/services
 * Per testing.mdc: Mock repository and audit log
 */

const { HttpError } = require('@lib/errors');

jest.mock('@repositories/user/user.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn().mockResolvedValue({})}));
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) => values.find((value) => value) || null)}));
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(async ({ identifier }) => identifier)}));
jest.mock('@lib/websocket/crud-realtime', () => ({
  publishCrudRealtimeEvent: jest.fn().mockResolvedValue(undefined)}));
jest.mock('@lib/realtime/platform-realtime', () => ({
  publishPlatformRealtimeEvent: jest.fn().mockResolvedValue(undefined)}));
jest.mock('@prisma/client', () => ({
  user: { findFirst: jest.fn().mockResolvedValue(null) },
  user_role: { findMany: jest.fn().mockResolvedValue([]) }}));

const userRepository = require('@repositories/user/user.repository');
const prisma = require('@prisma/client');
const { createAuditLog } = require('@lib/audit');
const { publishCrudRealtimeEvent } = require('@lib/websocket/crud-realtime');
const { permanentDeleteUser } = require('@services/user/user.service');

const USER_ID = '550e8400-e29b-41d4-a716-446655440000';
const ACTOR = { id: 'actor-1', roles: ['PLATFORM_OWNER'] };

const deletedUser = (overrides = {}) => ({
  id: USER_ID,
  tenant_id: 'tenant-1',
  facility_id: null,
  email: 'purge.me@example.com',
  human_friendly_id: 'USR-001',
  deleted_at: new Date('2026-01-02T00:00:00Z'),
  ...overrides});

const purgeSummary = {
  removed_rows: 7,
  cleared_links: 3,
  staff_profile_ids: ['staff-1']};

describe('User Service permanentDeleteUser', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    prisma.user_role.findMany.mockResolvedValue([]);
    userRepository.permanentDelete.mockResolvedValue(purgeSummary);
  });

  it('purges the account, audits it and publishes the removal event', async () => {
    const before = deletedUser();
    userRepository.findById.mockResolvedValue(before);

    const result = await permanentDeleteUser(
      USER_ID,
      'actor-1',
      '127.0.0.1',
      ACTOR
    );

    expect(userRepository.permanentDelete).toHaveBeenCalledWith(USER_ID);
    expect(result).toEqual(purgeSummary);
    expect(createAuditLog).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'USER_PERMANENTLY_DELETED',
        entity: 'user',
        entity_id: USER_ID,
        diff: expect.objectContaining({ irreversible: true, removed_rows: 7 })})
    );
    expect(publishCrudRealtimeEvent).toHaveBeenCalledWith(
      expect.objectContaining({ event: 'user.permanently_deleted' })
    );
  });

  it('throws 404 when the account cannot be found', async () => {
    userRepository.findById.mockResolvedValue(null);

    await expect(
      permanentDeleteUser(USER_ID, 'actor-1', '127.0.0.1', ACTOR)
    ).rejects.toMatchObject({
      messageKey: 'errors.user.not_found',
      statusCode: 404});
    expect(userRepository.permanentDelete).not.toHaveBeenCalled();
  });

  it('requires the account to be soft-deleted first', async () => {
    userRepository.findById.mockResolvedValue(deletedUser({ deleted_at: null }));

    await expect(
      permanentDeleteUser(USER_ID, 'actor-1', '127.0.0.1', ACTOR)
    ).rejects.toMatchObject({
      messageKey: 'errors.user.permanent_delete_requires_soft_delete',
      statusCode: 400});
    expect(userRepository.permanentDelete).not.toHaveBeenCalled();
  });

  it('refuses to purge the acting account', async () => {
    userRepository.findById.mockResolvedValue(deletedUser());

    await expect(
      permanentDeleteUser(USER_ID, USER_ID, '127.0.0.1', { id: USER_ID })
    ).rejects.toMatchObject({
      messageKey: 'errors.user.permanent_delete_self_forbidden',
      statusCode: 400});
    expect(userRepository.permanentDelete).not.toHaveBeenCalled();
  });

  it('refuses to purge a platform admin account for a non-owner actor', async () => {
    userRepository.findById.mockResolvedValue(deletedUser());
    prisma.user_role.findMany.mockResolvedValue([
      { role: { name: 'PLATFORM_ADMIN' } }]);

    await expect(
      permanentDeleteUser(USER_ID, 'actor-1', '127.0.0.1', {
        id: 'actor-1',
        roles: ['TENANT_ADMIN']})
    ).rejects.toMatchObject({
      messageKey: 'errors.auth.insufficient_permissions',
      statusCode: 403});
    expect(userRepository.permanentDelete).not.toHaveBeenCalled();
  });

  it('propagates a retained-records conflict from the repository', async () => {
    userRepository.findById.mockResolvedValue(deletedUser());
    userRepository.permanentDelete.mockRejectedValue(
      new HttpError('errors.user.permanent_delete_has_retained_records', 409, [
        { entity: 'clinical_note', field: 'author_user_id', count: 2 }])
    );

    await expect(
      permanentDeleteUser(USER_ID, 'actor-1', '127.0.0.1', ACTOR)
    ).rejects.toMatchObject({
      messageKey: 'errors.user.permanent_delete_has_retained_records',
      statusCode: 409});
  });
});
