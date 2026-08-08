/**
 * Guards for seeded demo / default users.
 *
 * @module lib/authorization/demo-user-guard
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');
const { isDemoUser, isDemoUserEmail } = require('@config/demo-users');

const assertDemoUserNotMutable = (user = {}, operation = 'update') => {
  if (!isDemoUser(user)) {
    return;
  }
  throw new HttpError('errors.user.demo_protected', 403, [
    {
      field: 'user_id',
      reason: 'demo_user_protected',
      operation,
      email: user.email || null,
    },
  ]);
};

const assertUserIdNotDemoProtected = async (userId, operation = 'update') => {
  const id = String(userId || '').trim();
  if (!id) {
    return;
  }
  const user = await prisma.user.findFirst({
    where: { id },
    select: { id: true, email: true },
  });
  assertDemoUserNotMutable(user || {}, operation);
};

module.exports = {
  assertDemoUserNotMutable,
  assertUserIdNotDemoProtected,
  isDemoUser,
  isDemoUserEmail,
};
