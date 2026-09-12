/**
 * User repository permanent delete tests
 *
 * @module tests/modules/user/repositories
 * @description Purge behaviour for permanently deleted users.
 * Per testing.mdc: Mock all Prisma calls, test error handling
 */

const userRepository = require('@repositories/user/user.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('../../../../prisma/tenant-guard', () => ({
  runWithoutTenantGuard: jest.fn(async (callback) => callback()),
}));

// The purge touches dozens of models, so delegates are built lazily and reset
// between tests through $resetDelegates.
jest.mock('@prisma/client', () => {
  const delegates = new Map();
  const applyDefaults = (delegate) => {
    delegate.findFirst.mockResolvedValue(null);
    delegate.findMany.mockResolvedValue([]);
    delegate.count.mockResolvedValue(0);
    delegate.deleteMany.mockResolvedValue({ count: 0 });
    delegate.updateMany.mockResolvedValue({ count: 0 });
    delegate.delete.mockResolvedValue({});
    delegate.update.mockResolvedValue({});
    return delegate;
  };
  const createDelegate = () =>
    applyDefaults({
      findFirst: jest.fn(),
      findMany: jest.fn(),
      count: jest.fn(),
      deleteMany: jest.fn(),
      updateMany: jest.fn(),
      delete: jest.fn(),
      update: jest.fn()});

  const client = {};
  const proxy = new Proxy(client, {
    get(target, prop) {
      if (typeof prop !== 'string' || prop === 'then' || prop === 'default' ||
        prop === '__esModule') {
        return undefined;
      }
      if (prop.startsWith('$')) {
        return target[prop];
      }
      if (!delegates.has(prop)) {
        delegates.set(prop, createDelegate());
      }
      return delegates.get(prop);
    }});

  client.$transaction = jest.fn(async (callback) => callback(proxy));
  client.$resetDelegates = () => {
    delegates.forEach((delegate) => applyDefaults(delegate));
  };
  return proxy;
});

const USER_ID = '550e8400-e29b-41d4-a716-446655440000';

const primeUser = (deletedAt) => {
  prisma.user.findFirst.mockResolvedValue({ id: USER_ID, deleted_at: deletedAt });
};

describe('User Repository permanentDelete', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    // clearMocks keeps implementations, so per-test overrides must be undone.
    prisma.$resetDelegates();
  });

  it('returns an empty summary when the user no longer exists', async () => {
    prisma.user.findFirst.mockResolvedValue(null);

    const result = await userRepository.permanentDelete(USER_ID);

    expect(result).toEqual({
      removed_rows: 0,
      cleared_links: 0,
      staff_profile_ids: []});
    expect(prisma.user.delete).not.toHaveBeenCalled();
  });

  it('refuses to purge a user that is not soft-deleted', async () => {
    primeUser(null);

    await expect(userRepository.permanentDelete(USER_ID)).rejects.toMatchObject({
      messageKey: 'errors.user.permanent_delete_requires_soft_delete',
      statusCode: 400});
    expect(prisma.user.delete).not.toHaveBeenCalled();
  });

  it('refuses to purge a user with retained clinical records', async () => {
    primeUser(new Date());
    prisma.clinical_note.count.mockResolvedValue(3);

    const error = await userRepository
      .permanentDelete(USER_ID)
      .catch((thrown) => thrown);

    expect(error).toBeInstanceOf(HttpError);
    expect(error.messageKey).toBe(
      'errors.user.permanent_delete_has_retained_records'
    );
    expect(error.statusCode).toBe(409);
    expect(error.errors).toEqual([
      { entity: 'clinical_note', field: 'author_user_id', count: 3 }]);
    expect(prisma.user.delete).not.toHaveBeenCalled();
  });

  it('removes account-owned rows, clears attribution links and deletes the user', async () => {
    primeUser(new Date());
    prisma.user_session.deleteMany.mockResolvedValue({ count: 2 });
    prisma.audit_log.updateMany.mockResolvedValue({ count: 5 });

    const result = await userRepository.permanentDelete(USER_ID);

    expect(prisma.user_session.deleteMany).toHaveBeenCalledWith({
      where: { user_id: USER_ID }});
    expect(prisma.user_role.deleteMany).toHaveBeenCalledWith({
      where: { user_id: USER_ID }});
    expect(prisma.audit_log.updateMany).toHaveBeenCalledWith({
      where: { user_id: USER_ID },
      data: { user_id: null }});
    expect(prisma.clinical_note.deleteMany).not.toHaveBeenCalled();
    expect(prisma.user.delete).toHaveBeenCalledWith({ where: { id: USER_ID } });
    expect(result).toEqual({
      removed_rows: 3,
      cleared_links: 5,
      staff_profile_ids: []});
  });

  it('purges employment rows owned by the staff profile', async () => {
    primeUser(new Date());
    prisma.staff_profile.findMany.mockResolvedValue([{ id: 'staff-1' }]);

    await userRepository.permanentDelete(USER_ID);

    expect(prisma.staff_assignment.deleteMany).toHaveBeenCalledWith({
      where: { staff_profile_id: { in: ['staff-1'] } }});
    expect(prisma.housekeeping_task.updateMany).toHaveBeenCalledWith({
      where: { assigned_to_staff_id: { in: ['staff-1'] } },
      data: { assigned_to_staff_id: null }});
    expect(prisma.staff_profile.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: ['staff-1'] } }});
  });

  it('blocks the purge when the staff profile has payroll history', async () => {
    primeUser(new Date());
    prisma.staff_profile.findMany.mockResolvedValue([{ id: 'staff-1' }]);
    prisma.payroll_item.count.mockResolvedValue(4);

    await expect(userRepository.permanentDelete(USER_ID)).rejects.toMatchObject({
      messageKey: 'errors.user.permanent_delete_has_retained_records',
      statusCode: 409});
    expect(prisma.staff_profile.deleteMany).not.toHaveBeenCalled();
  });
});
