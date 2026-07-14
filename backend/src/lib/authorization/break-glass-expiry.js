const prisma = require('@prisma/client');
const { createRequiredAuditLog } = require('@lib/audit');
const {
  emitAccessControlEvent,
  ACCESS_CONTROL_EVENTS,
} = require('@lib/last-office/events');
const { logger } = require('@lib/logging');

const DEFAULT_INTERVAL_MS = 60 * 1000;
let expiryInterval = null;

const expireBreakGlassAccesses = async (now = new Date()) => {
  const expired = await prisma.break_glass_access.findMany({
    where: {
      deleted_at: null,
      status: 'ACTIVE',
      expires_at: { lt: now },
    },
    select: {
      id: true,
      human_friendly_id: true,
      tenant_id: true,
      facility_id: true,
      expires_at: true,
      version: true,
    },
    take: 100,
  });

  let count = 0;
  for (const access of expired) {
    const updated = await prisma.break_glass_access.updateMany({
      where: {
        id: access.id,
        status: 'ACTIVE',
        expires_at: { lt: now },
      },
      data: {
        status: 'EXPIRED',
        reviewed_at: now,
        version: { increment: 1 },
      },
    });
    if (!updated.count) {
      continue;
    }

    await createRequiredAuditLog({
      tenant_id: access.tenant_id,
      user_id: null,
      action: 'UPDATE',
      entity: 'break_glass_access',
      entity_id: access.id,
      diff: {
        before: {
          status: 'ACTIVE',
          version: access.version,
          expires_at: access.expires_at,
        },
        after: {
          status: 'EXPIRED',
          version: Number(access.version || 1) + 1,
          expired_automatically: true,
        },
      },
    });
    await emitAccessControlEvent({
      tenant_id: access.tenant_id,
      facility_id: access.facility_id,
      event: ACCESS_CONTROL_EVENTS.BREAK_GLASS_REVOKED,
      payload: {
        break_glass_access_id: access.human_friendly_id,
        status: 'EXPIRED',
      },
    });
    count += 1;
  }
  return count;
};

const startBreakGlassExpiryRuntime = ({
  intervalMs = Number(
    process.env.BREAK_GLASS_EXPIRY_INTERVAL_MS || DEFAULT_INTERVAL_MS
  ),
} = {}) => {
  if (expiryInterval) {
    return;
  }
  expiryInterval = setInterval(() => {
    expireBreakGlassAccesses().catch((error) => {
      logger.error('Break-glass expiry sweep failed', {
        error: error.message,
      });
    });
  }, intervalMs);
  if (typeof expiryInterval.unref === 'function') {
    expiryInterval.unref();
  }
  setImmediate(() => {
    expireBreakGlassAccesses().catch((error) => {
      logger.error('Initial break-glass expiry sweep failed', {
        error: error.message,
      });
    });
  });
};

const stopBreakGlassExpiryRuntime = () => {
  if (!expiryInterval) {
    return;
  }
  clearInterval(expiryInterval);
  expiryInterval = null;
};

module.exports = {
  expireBreakGlassAccesses,
  startBreakGlassExpiryRuntime,
  stopBreakGlassExpiryRuntime,
};
