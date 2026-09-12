/**
 * User service identity-review scoping tests
 *
 * @module tests/modules/user/services
 * @description The duplicate-identity review must gate identity edits only.
 * Per testing.mdc: Mock repository and audit log
 */

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
jest.mock('@lib/authorization/assignable-access', () => {
  const actual = jest.requireActual('@lib/authorization/assignable-access');
  return {
    ...actual,
    assertPermissionIdsAssignable: jest.fn(async (ids = []) => [...ids])};
});
jest.mock('@prisma/client', () => ({
  user: { findFirst: jest.fn().mockResolvedValue(null) },
  user_role: { findMany: jest.fn().mockResolvedValue([]) }}));

const userRepository = require('@repositories/user/user.repository');
const userService = require('@services/user/user.service');

const ACTOR = { id: 'actor-1', roles: ['TENANT_ADMIN'], tenant_id: 'tenant-1' };

const TARGET = {
  id: 'user-1',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  email: 'testing@example.com',
  phone: '0700000001',
  position_title: 'Nurse',
  profile: { first_name: 'Testing', middle_name: null, last_name: null }};

// Close enough to trip the similarity review when identity is edited.
const SIMILAR_PEER = {
  id: 'user-2',
  tenant_id: 'tenant-1',
  facility_id: 'facility-1',
  email: 'testing.testing@example.com',
  phone: '0700000002',
  position_title: 'Nurse',
  profile: { first_name: 'Testing', middle_name: null, last_name: 'Testing' }};

describe('User Service updateUser identity review', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    userRepository.findById.mockResolvedValue(TARGET);
    userRepository.findMany.mockResolvedValue([TARGET, SIMILAR_PEER]);
    userRepository.update.mockResolvedValue({ ...TARGET });
  });

  it('assigns direct permissions even when a similar account exists', async () => {
    await userService.updateUser(
      'user-1',
      { permission_ids: ['perm-1', 'perm-2'] },
      'actor-1',
      '127.0.0.1',
      ACTOR
    );

    expect(userRepository.update).toHaveBeenCalledWith(
      'user-1',
      expect.objectContaining({ permission_ids: ['perm-1', 'perm-2'] })
    );
  });

  it('changes status without running the identity review', async () => {
    await userService.updateUser(
      'user-1',
      { status: 'INACTIVE' },
      'actor-1',
      '127.0.0.1',
      ACTOR
    );

    expect(userRepository.update).toHaveBeenCalledWith(
      'user-1',
      expect.objectContaining({ status: 'INACTIVE' })
    );
  });

  it('still reviews identity edits against similar accounts', async () => {
    await expect(
      userService.updateUser(
        'user-1',
        { email: 'testing@example.com', phone: '0700000001' },
        'actor-1',
        '127.0.0.1',
        ACTOR
      )
    ).rejects.toMatchObject({
      messageKey: 'errors.user.similar_exists',
      statusCode: 409});
    expect(userRepository.update).not.toHaveBeenCalled();
  });

  it('persists a reviewed identity edit once confirmed', async () => {
    await userService.updateUser(
      'user-1',
      {
        email: 'testing@example.com',
        phone: '0700000001',
        confirm_similar: true},
      'actor-1',
      '127.0.0.1',
      ACTOR
    );

    expect(userRepository.update).toHaveBeenCalled();
  });
});
