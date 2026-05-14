const os = require('os');
const prisma = require('@prisma/client');
const { sendEmail } = require('@lib/notifications');
const { createAuditLog } = require('@lib/audit');
const { translate } = require('@lib/i18n');
const { logger } = require('@lib/logging');
const { emitToUser, NOTIFICATION_EVENTS } = require('@lib/websocket');
const { markSpanError, recordBackgroundJob } = require('@lib/telemetry/metrics');

const DELIVERY_RUNTIME_POLL_INTERVAL_MS = 15000;
const DELIVERY_RUNTIME_BATCH_SIZE = 10;
const DELIVERY_RUNTIME_MAX_ATTEMPTS = 3;
const DELIVERY_RUNTIME_REQUIRED_TABLES = ['notification', 'notification_delivery'];
const MISSING_SCHEMA_ARTIFACT_ERROR_CODES = new Set(['P2021', 'P2022']);

const runnerState = {
  interval: null,
  draining: false,
  startPromise: null,
  disabledReason: null,
  disabledLogged: false,
  instanceId: `${os.hostname()}:${process.pid}`,
};

class DeliveryError extends Error {
  constructor(messageKey, options = {}) {
    super(messageKey);
    this.name = 'DeliveryError';
    this.messageKey = messageKey;
    this.retryable = Boolean(options.retryable);
    this.details = options.details || {};
    this.provider = options.provider || null;
  }
}

const clearRuntimeInterval = () => {
  if (!runnerState.interval) return;
  clearInterval(runnerState.interval);
  runnerState.interval = null;
};

const disableNotificationRuntime = (reason, details = {}) => {
  clearRuntimeInterval();
  runnerState.disabledReason = reason;
  recordBackgroundJob('notification_runtime.disabled', {
    'hms.runtime.reason': reason,
  });

  if (runnerState.disabledLogged) return;
  runnerState.disabledLogged = true;
  logger.warn('Notification delivery runtime disabled', {
    reason,
    ...details,
  });
};

const isMissingSchemaArtifactError = (error) => {
  const code = error?.code ? String(error.code).toUpperCase() : null;
  if (code && MISSING_SCHEMA_ARTIFACT_ERROR_CODES.has(code)) {
    return true;
  }

  return /does not exist in the current database|does not exist/i.test(
    String(error?.message || '')
  );
};

const resolveSchemaArtifactName = (row) => {
  if (!row || typeof row !== 'object') return null;
  if (typeof row.table_name === 'string') return row.table_name;
  if (typeof row.TABLE_NAME === 'string') return row.TABLE_NAME;

  const firstValue = Object.values(row)[0];
  return typeof firstValue === 'string' ? firstValue : null;
};

const ensureRuntimeTablesAvailable = async () => {
  try {
    const rows = await prisma.$queryRawUnsafe(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = DATABASE()
        AND table_name IN ('notification', 'notification_delivery')
    `);

    const availableTables = new Set(
      (Array.isArray(rows) ? rows : [])
        .map(resolveSchemaArtifactName)
        .filter(Boolean)
        .map((name) => String(name).toLowerCase())
    );

    const missingTables = DELIVERY_RUNTIME_REQUIRED_TABLES.filter(
      (tableName) => !availableTables.has(tableName)
    );

    if (missingTables.length > 0) {
      disableNotificationRuntime('missing_notification_runtime_tables', {
        missing_tables: missingTables,
      });
      return false;
    }

    return true;
  } catch {
    return true;
  }
};

const computeRetryDelayMs = (attemptCount = 0) =>
  Math.min(15 * 60 * 1000, Math.max(60 * 1000, 60 * 1000 * Math.pow(2, Math.max(0, attemptCount - 1))));

const isReadyForRetry = (delivery = {}) => {
  if (String(delivery?.status || '').toUpperCase() === 'QUEUED') {
    return true;
  }

  if (String(delivery?.status || '').toUpperCase() !== 'FAILED' || !delivery?.retryable) {
    return false;
  }

  if (Number(delivery?.attempt_count || 0) >= DELIVERY_RUNTIME_MAX_ATTEMPTS) {
    return false;
  }

  if (!delivery?.last_attempt_at) {
    return true;
  }

  const nextAttemptAt =
    new Date(delivery.last_attempt_at).getTime() +
    computeRetryDelayMs(Number(delivery.attempt_count || 0));

  return Date.now() >= nextAttemptAt;
};

const resolveRecipientTarget = (delivery = {}) => {
  const explicitTarget = String(delivery?.recipient_target || '').trim();
  if (explicitTarget) return explicitTarget;

  const email = String(delivery?.notification?.user?.email || '').trim();
  const phone = String(delivery?.notification?.user?.phone || '').trim();
  const channel = String(delivery?.channel || '').toUpperCase();

  if (channel === 'EMAIL') return email || null;
  if (['SMS', 'WHATSAPP', 'CALL'].includes(channel)) return phone || null;
  if (channel === 'IN_APP') return email || phone || null;
  return email || phone || null;
};

const buildEmailPayload = (delivery = {}) => {
  const notification = delivery.notification || {};
  const recipient = resolveRecipientTarget(delivery);

  if (!recipient) {
    throw new DeliveryError('errors.notification_delivery.target_missing', {
      retryable: false,
      details: { channel: 'EMAIL' },
    });
  }

  return {
    to: recipient,
    subject: notification.title || translate('messages.notification_delivery.email.subject', 'en'),
    text: [
      notification.title || translate('messages.notification_delivery.email.subject', 'en'),
      '',
      notification.message || '',
    ].filter(Boolean).join('\n'),
    html: `<!doctype html>
<html lang="en">
<head><meta charset="utf-8" /><meta name="viewport" content="width=device-width,initial-scale=1" /></head>
<body style="font-family:Segoe UI,Tahoma,Arial,sans-serif;background:#f4f7fb;padding:20px;">
  <div style="max-width:640px;margin:0 auto;background:#ffffff;border:1px solid #dbe4f3;border-radius:12px;padding:24px;">
    <h1 style="margin:0 0 12px;font-size:22px;color:#0f172a;">${notification.title || translate('messages.notification_delivery.email.subject', 'en')}</h1>
    <p style="margin:0 0 14px;color:#1e293b;line-height:1.5;">${notification.message || ''}</p>
  </div>
</body>
</html>`,
  };
};

const dispatchDelivery = async (delivery = {}) => {
  const channel = String(delivery?.channel || '').toUpperCase();

  if (channel === 'IN_APP') {
    return {
      status: 'DELIVERED',
      provider: 'IN_APP',
      recipient_target: resolveRecipientTarget(delivery),
    };
  }

  if (channel === 'EMAIL') {
    const emailPayload = buildEmailPayload(delivery);
    const result = await sendEmail(emailPayload);

    if (!result?.sent) {
      throw new DeliveryError(
        result?.provider === 'skipped'
          ? 'errors.notification_delivery.provider_unavailable'
          : 'errors.notification_delivery.delivery_failed',
        {
          retryable: result?.provider !== 'skipped',
          provider: result?.provider || null,
          details: { channel: 'EMAIL' },
        }
      );
    }

    return {
      status: 'SENT',
      provider: result.provider || 'smtp',
      recipient_target: emailPayload.to,
    };
  }

  throw new DeliveryError('errors.notification_delivery.channel_not_supported', {
    retryable: false,
    details: { channel },
  });
};

const emitDeliveryUpdate = async (deliveryId) => {
  const delivery = await prisma.notification_delivery.findFirst({
    where: { id: deliveryId, deleted_at: null },
    include: {
      notification: {
        select: {
          user_id: true,
        },
      },
    },
  });

  if (!delivery?.notification?.user_id) return;

  emitToUser(delivery.notification.user_id, NOTIFICATION_EVENTS.NOTIFICATION_DELIVERY_UPDATED, {
    delivery: {
      id: delivery.id,
      channel: delivery.channel,
      status: delivery.status,
      recipient_target: delivery.recipient_target,
      provider_name: delivery.provider_name,
      attempt_count: delivery.attempt_count,
      sent_at: delivery.sent_at,
      delivered_at: delivery.delivered_at,
      failed_at: delivery.failed_at,
      retryable: delivery.retryable,
      error_message: delivery.error_message,
    },
  });
};

const finalizeSuccess = async (delivery, result) => {
  const now = new Date();
  const updated = await prisma.notification_delivery.update({
    where: { id: delivery.id },
    data: {
      status: result.status,
      provider_name: result.provider,
      recipient_target: result.recipient_target || delivery.recipient_target,
      sent_at: now,
      delivered_at: result.status === 'DELIVERED' ? now : null,
      failed_at: null,
      error_message: null,
      retryable: false,
    },
  });

  await createAuditLog({
    tenant_id: delivery.notification.tenant_id,
    user_id: delivery.notification.user_id,
    action: 'UPDATE',
    entity: 'notification_delivery',
    entity_id: delivery.id,
    diff: {
      before: { status: delivery.status, attempt_count: delivery.attempt_count },
      after: { status: updated.status, attempt_count: updated.attempt_count },
    },
  }).catch(() => {});

  await emitDeliveryUpdate(delivery.id).catch(() => {});
  recordBackgroundJob('notification_delivery.completed', {
    'hms.notification_delivery.id': delivery.human_friendly_id || delivery.id,
    'hms.notification_delivery.channel': delivery.channel,
  });
};

const finalizeFailure = async (delivery, error) => {
  const now = new Date();
  const retryable =
    Boolean(error?.retryable) &&
    Number(delivery.attempt_count || 0) < DELIVERY_RUNTIME_MAX_ATTEMPTS;
  const errorMessage = error?.messageKey
    ? translate(error.messageKey, 'en', error.details || {})
    : String(error?.message || translate('errors.notification_delivery.delivery_failed', 'en', {
        channel: String(delivery?.channel || 'delivery').toUpperCase(),
      }));

  await prisma.notification_delivery.update({
    where: { id: delivery.id },
    data: {
      status: 'FAILED',
      provider_name: error?.provider || delivery.provider_name,
      failed_at: now,
      error_message: errorMessage,
      retryable,
    },
  });

  await createAuditLog({
    tenant_id: delivery.notification.tenant_id,
    user_id: delivery.notification.user_id,
    action: 'UPDATE',
    entity: 'notification_delivery',
    entity_id: delivery.id,
    diff: {
      before: { status: delivery.status, attempt_count: delivery.attempt_count },
      after: { status: 'FAILED', attempt_count: delivery.attempt_count },
    },
  }).catch(() => {});

  await emitDeliveryUpdate(delivery.id).catch(() => {});
  recordBackgroundJob('notification_delivery.failed', {
    'hms.notification_delivery.id': delivery.human_friendly_id || delivery.id,
    'hms.notification_delivery.channel': delivery.channel,
  });
  markSpanError(error, {
    'hms.background.event': 'notification_delivery.failed',
  });
};

const claimDelivery = async (delivery = {}) => {
  const nextAttemptCount = Number(delivery.attempt_count || 0) + 1;
  const claimed = await prisma.notification_delivery.updateMany({
    where: {
      id: delivery.id,
      deleted_at: null,
      status: delivery.status,
      attempt_count: delivery.attempt_count,
    },
    data: {
      status: 'SENDING',
      attempt_count: nextAttemptCount,
      last_attempt_at: new Date(),
      error_message: null,
      retryable: false,
    },
  });

  if (!claimed.count) {
    return null;
  }

  return {
    ...delivery,
    status: 'SENDING',
    attempt_count: nextAttemptCount,
  };
};

const processDelivery = async (delivery = {}) => {
  const claimed = await claimDelivery(delivery);
  if (!claimed) return;

  try {
    const result = await dispatchDelivery(claimed);
    await finalizeSuccess(claimed, result);
  } catch (error) {
    await finalizeFailure(claimed, error);
  }
};

const getDispatchableDeliveries = async () => {
  const rows = await prisma.notification_delivery.findMany({
    where: {
      deleted_at: null,
      OR: [
        { status: 'QUEUED' },
        { status: 'FAILED', retryable: true },
      ],
    },
    include: {
      notification: {
        select: {
          id: true,
          tenant_id: true,
          user_id: true,
          title: true,
          message: true,
          target_path: true,
          user: {
            select: {
              email: true,
              phone: true,
            },
          },
        },
      },
    },
    orderBy: [{ updated_at: 'asc' }, { created_at: 'asc' }],
    take: DELIVERY_RUNTIME_BATCH_SIZE * 2,
  });

  return rows.filter(isReadyForRetry).slice(0, DELIVERY_RUNTIME_BATCH_SIZE);
};

const drainNotificationDeliveries = async () => {
  if (runnerState.draining) return;
  runnerState.draining = true;

  try {
    const deliveries = await getDispatchableDeliveries();
    for (const delivery of deliveries) {
      await processDelivery(delivery);
    }
  } finally {
    runnerState.draining = false;
  }
};

const handleRuntimeTickError = (error, context) => {
  if (!isMissingSchemaArtifactError(error)) return;

  disableNotificationRuntime('missing_notification_schema_artifact', {
    context,
    code: error?.code || null,
    error: String(error?.message || 'Unknown Prisma schema artifact error'),
  });
};

const startNotificationDeliveryRuntime = () => {
  if (runnerState.interval || runnerState.startPromise) return runnerState.startPromise;
  if (runnerState.disabledReason) return Promise.resolve(false);

  runnerState.startPromise = (async () => {
    const ready = await ensureRuntimeTablesAvailable();
    if (!ready) {
      return false;
    }

    runnerState.interval = setInterval(() => {
      drainNotificationDeliveries().catch((error) => {
        handleRuntimeTickError(error, 'interval');
      });
    }, DELIVERY_RUNTIME_POLL_INTERVAL_MS);
    if (typeof runnerState.interval.unref === 'function') {
      runnerState.interval.unref();
    }

    setImmediate(() => {
      drainNotificationDeliveries().catch((error) => {
        handleRuntimeTickError(error, 'startup');
      });
    });

    logger.info('Notification delivery runtime initialized', {
      instance_id: runnerState.instanceId,
    });
    return true;
  })();

  return runnerState.startPromise.finally(() => {
    runnerState.startPromise = null;
  });
};

const stopNotificationDeliveryRuntime = () => {
  clearRuntimeInterval();
};

module.exports = {
  computeRetryDelayMs,
  drainNotificationDeliveries,
  startNotificationDeliveryRuntime,
  stopNotificationDeliveryRuntime,
};
