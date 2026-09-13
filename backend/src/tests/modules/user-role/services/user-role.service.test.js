/**
 * User-Role service tests
 *
 * @module tests/modules/user-role/services
 * Per testing.mdc: Mock repository and audit log
 */

const { HttpError } = require('@lib/errors');

jest.mock('@repositories/user-role/user-role.repository');
jest.mock('@lib/audit', () => ({
  createAuditLog: jest.fn()
}));
jest.mock('@lib/billing/identifiers', () => ({
  resolveIdentifierForPayload: jest.fn()
}));
jest.mock('@lib/authorization/assignable-access', () => ({
  assertRoleIdAssignable: jest.fn()
}));
jest.mock('@lib/authorization/demo-user-guard', () => ({
  assertUserIdNotDemoProtected: jest.fn()
}));

const userRoleRepository = require('@repositories/user-role/user-role.repository');
const { createAuditLog } = require('@lib/audit');
const { resolveIdentifierForPayload } = require('@lib/billing/identifiers');
const { assertRoleIdAssignable } = require('@lib/authorization/assignable-access');
const { assertUserIdNotDemoProtected } = require('@lib/authorization/demo-user-guard');
const {
  listUserRoles,
  getUserRoleById,
  createUserRole,
  updateUserRole,
  deleteUserRole
} = require('@services/user-role/user-role.service');

const TENANT_ID = '11111111-1111-4111-8111-111111111111';
const OTHER_TENANT_ID = '22222222-2222-4222-8222-222222222222';
const FACILITY_ID = '33333333-3333-4333-8333-333333333333';
const OTHER_FACILITY_ID = '44444444-4444-4444-8444-444444444444';
const USER_ID = '55555555-5555-4555-8555-555555555555';
const ROLE_ID = '66666666-6666-4666-8666-666666666666';
const USER_ROLE_ID = '77777777-7777-4777-8777-777777777777';

const actor = { id: 'actor-1', tenant_id: TENANT_ID, roles: ['TENANT_ADMIN'] };

describe('User-Role Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveIdentifierForPayload.mockImplementation(async ({ value }) => value);
    assertUserIdNotDemoProtected.mockResolvedValue(undefined);
    assertRoleIdAssignable.mockResolvedValue({ id: ROLE_ID, tenant_id: TENANT_ID, facility_id: null });
    userRoleRepository.findUserScope.mockResolvedValue({
      id: USER_ID,
      tenant_id: TENANT_ID,
      facility_id: FACILITY_ID
    });
    userRoleRepository.findFacilityScope.mockResolvedValue({ id: FACILITY_ID, tenant_id: TENANT_ID });
    userRoleRepository.findRoleScope.mockResolvedValue({ id: ROLE_ID, tenant_id: TENANT_ID, facility_id: null });
    userRoleRepository.create.mockImplementation(async (payload) => ({ id: USER_ROLE_ID, ...payload }));
  });

  describe('listUserRoles', () => {
    it('should list user-roles with pagination', async () => {
      const mocks = [{ id: USER_ROLE_ID }];
      userRoleRepository.findMany.mockResolvedValue(mocks);
      userRoleRepository.count.mockResolvedValue(1);

      const result = await listUserRoles({}, 1, 20, 'created_at', 'asc', 'user-123', '127.0.0.1');

      expect(result.userRoles).toEqual(mocks);
    });
  });

  describe('getUserRoleById', () => {
    it('should get user-role by ID', async () => {
      const mock = { id: USER_ROLE_ID };
      userRoleRepository.findById.mockResolvedValue(mock);

      const result = await getUserRoleById(USER_ROLE_ID, 'user-123', '127.0.0.1');

      expect(result).toEqual(mock);
    });

    it('should throw HttpError when not found', async () => {
      userRoleRepository.findById.mockResolvedValue(null);

      await expect(getUserRoleById(USER_ROLE_ID, 'user-123', '127.0.0.1'))
        .rejects.toThrow(HttpError);
    });
  });

  describe('createUserRole', () => {
    it('binds the assignment to the user tenant and facility and audits it', async () => {
      const result = await createUserRole(
        { user_id: USER_ID, role_id: ROLE_ID, tenant_id: TENANT_ID, facility_id: FACILITY_ID },
        actor.id,
        '127.0.0.1',
        actor
      );

      expect(assertRoleIdAssignable).toHaveBeenCalledWith(ROLE_ID, actor);
      expect(userRoleRepository.create).toHaveBeenCalledWith({
        user_id: USER_ID,
        role_id: ROLE_ID,
        tenant_id: TENANT_ID,
        facility_id: FACILITY_ID
      });
      expect(result.id).toBe(USER_ROLE_ID);
      expect(createAuditLog).toHaveBeenCalled();
    });

    it("uses the user's facility when the request omits one", async () => {
      await createUserRole({ user_id: USER_ID, role_id: ROLE_ID, tenant_id: TENANT_ID }, actor.id, '127.0.0.1', actor);

      expect(userRoleRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({ facility_id: FACILITY_ID })
      );
    });

    it("rejects an assignment tenant that differs from the user's tenant", async () => {
      await expect(
        createUserRole(
          { user_id: USER_ID, role_id: ROLE_ID, tenant_id: OTHER_TENANT_ID },
          actor.id,
          '127.0.0.1',
          actor
        )
      ).rejects.toMatchObject({
        messageKey: 'errors.user_role.tenant_mismatch',
        statusCode: 400,
        errors: [expect.objectContaining({ field: 'tenant_id' })]
      });
      expect(userRoleRepository.create).not.toHaveBeenCalled();
    });

    it("rejects a facility outside the user's tenant", async () => {
      userRoleRepository.findFacilityScope.mockResolvedValue({
        id: OTHER_FACILITY_ID,
        tenant_id: OTHER_TENANT_ID
      });

      await expect(
        createUserRole(
          { user_id: USER_ID, role_id: ROLE_ID, tenant_id: TENANT_ID, facility_id: OTHER_FACILITY_ID },
          actor.id,
          '127.0.0.1',
          actor
        )
      ).rejects.toMatchObject({
        messageKey: 'errors.user_role.facility_tenant_mismatch',
        errors: [expect.objectContaining({ field: 'facility_id' })]
      });
      expect(userRoleRepository.create).not.toHaveBeenCalled();
    });

    it('rejects a role that belongs to another tenant', async () => {
      assertRoleIdAssignable.mockResolvedValue({ id: ROLE_ID, tenant_id: OTHER_TENANT_ID, facility_id: null });

      await expect(
        createUserRole({ user_id: USER_ID, role_id: ROLE_ID, tenant_id: TENANT_ID }, actor.id, '127.0.0.1', actor)
      ).rejects.toMatchObject({
        messageKey: 'errors.user_role.role_tenant_mismatch',
        errors: [expect.objectContaining({ field: 'role_id' })]
      });
      expect(userRoleRepository.create).not.toHaveBeenCalled();
    });

    it('rejects a role limited to a different facility', async () => {
      assertRoleIdAssignable.mockResolvedValue({
        id: ROLE_ID,
        tenant_id: TENANT_ID,
        facility_id: OTHER_FACILITY_ID
      });

      await expect(
        createUserRole({ user_id: USER_ID, role_id: ROLE_ID, tenant_id: TENANT_ID }, actor.id, '127.0.0.1', actor)
      ).rejects.toMatchObject({ messageKey: 'errors.user_role.role_facility_mismatch' });
      expect(userRoleRepository.create).not.toHaveBeenCalled();
    });

    it('propagates the actor ceiling check', async () => {
      assertRoleIdAssignable.mockRejectedValue(
        new HttpError('errors.auth.insufficient_permissions', 403, [{ field: 'role_id' }])
      );

      await expect(
        createUserRole({ user_id: USER_ID, role_id: ROLE_ID, tenant_id: TENANT_ID }, actor.id, '127.0.0.1', actor)
      ).rejects.toMatchObject({ messageKey: 'errors.auth.insufficient_permissions', statusCode: 403 });
      expect(userRoleRepository.create).not.toHaveBeenCalled();
    });

    it('still validates role scope for internal callers without an actor', async () => {
      userRoleRepository.findRoleScope.mockResolvedValue({ id: ROLE_ID, tenant_id: OTHER_TENANT_ID, facility_id: null });

      await expect(
        createUserRole({ user_id: USER_ID, role_id: ROLE_ID, tenant_id: TENANT_ID }, 'system', '127.0.0.1')
      ).rejects.toMatchObject({ messageKey: 'errors.user_role.role_tenant_mismatch' });
      expect(assertRoleIdAssignable).not.toHaveBeenCalled();
    });

    it('returns not found for an unknown user', async () => {
      userRoleRepository.findUserScope.mockResolvedValue(null);

      await expect(
        createUserRole({ user_id: USER_ID, role_id: ROLE_ID, tenant_id: TENANT_ID }, actor.id, '127.0.0.1', actor)
      ).rejects.toMatchObject({
        messageKey: 'errors.user.not_found',
        statusCode: 404,
        errors: [expect.objectContaining({ field: 'user_id' })]
      });
    });
  });

  describe('updateUserRole', () => {
    const before = {
      id: USER_ROLE_ID,
      user_id: USER_ID,
      role_id: ROLE_ID,
      tenant_id: TENANT_ID,
      facility_id: FACILITY_ID
    };

    it('validates and persists the assignment as it will exist after the update', async () => {
      userRoleRepository.findById.mockResolvedValue(before);
      userRoleRepository.update.mockImplementation(async (id, payload) => ({ id, ...payload }));

      const result = await updateUserRole(USER_ROLE_ID, { facility_id: null }, actor.id, '127.0.0.1', actor);

      expect(userRoleRepository.update).toHaveBeenCalledWith(USER_ROLE_ID, {
        user_id: USER_ID,
        role_id: ROLE_ID,
        tenant_id: TENANT_ID,
        facility_id: null
      });
      expect(result.facility_id).toBeNull();
      expect(createAuditLog).toHaveBeenCalled();
    });

    it('rejects moving an assignment to a facility in another tenant', async () => {
      userRoleRepository.findById.mockResolvedValue(before);
      userRoleRepository.findFacilityScope.mockResolvedValue({
        id: OTHER_FACILITY_ID,
        tenant_id: OTHER_TENANT_ID
      });

      await expect(
        updateUserRole(USER_ROLE_ID, { facility_id: OTHER_FACILITY_ID }, actor.id, '127.0.0.1', actor)
      ).rejects.toMatchObject({ messageKey: 'errors.user_role.facility_tenant_mismatch' });
      expect(userRoleRepository.update).not.toHaveBeenCalled();
    });
  });

  describe('deleteUserRole', () => {
    it('should soft delete user-role and audit log', async () => {
      userRoleRepository.findById.mockResolvedValue({ id: USER_ROLE_ID, user_id: USER_ID });
      userRoleRepository.softDelete.mockResolvedValue({});

      await deleteUserRole(USER_ROLE_ID, 'user-123', '127.0.0.1');

      expect(userRoleRepository.softDelete).toHaveBeenCalled();
      expect(createAuditLog).toHaveBeenCalled();
    });
  });
});
