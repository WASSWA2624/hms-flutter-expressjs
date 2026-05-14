/**
 * Follow-up service
 *
 * @module modules/follow-up/services
 * @description Business logic layer for follow-up operations and reminders.
 */

const followUpRepository = require("@repositories/follow-up/follow-up.repository");
const prisma = require("@prisma/client");
const { createAuditLog } = require("@lib/audit");
const { HttpError } = require("@lib/errors");
const { ROLES } = require("@config/roles");
const { isFeatureEnabled } = require("@config/feature-flags");
const { emitToUser, NOTIFICATION_EVENTS } = require("@lib/websocket");
const {
  parseIpdMedicationReminderNote,
} = require("@lib/clinical/ipdMedicationReminder");

const FOLLOW_UP_TRANSITIONS = Object.freeze({
  SCHEDULED: new Set(["COMPLETED", "CANCELLED"]),
  COMPLETED: new Set([]),
  CANCELLED: new Set([]),
});

const IPD_REMINDER_RECIPIENT_ROLES = [
  ROLES.SUPER_ADMIN,
  ROLES.TENANT_ADMIN,
  ROLES.FACILITY_ADMIN,
  ROLES.DOCTOR,
  ROLES.NURSE,
];

const normalizeStatus = (value, fallback = "SCHEDULED") => {
  const normalized = String(value || "")
    .trim()
    .toUpperCase();
  return normalized || fallback;
};

const canTransitionFollowUp = (fromStatus, toStatus) => {
  const source = normalizeStatus(fromStatus, "");
  const target = normalizeStatus(toStatus, "");
  const allowed = FOLLOW_UP_TRANSITIONS[source];
  return Boolean(allowed && allowed.has(target));
};

const assertTransition = (fromStatus, toStatus) => {
  if (!canTransitionFollowUp(fromStatus, toStatus)) {
    throw new HttpError("errors.follow_up.invalid_status_transition", 400, [
      { field: "status" },
      { from: fromStatus },
      { to: toStatus },
    ]);
  }
};

const resolveFrontDeskRecipients = async ({ tenantId, facilityId = null }) => {
  if (!tenantId) return [];

  const rows = await prisma.user_role.findMany({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      role: {
        deleted_at: null,
        name: ROLES.RECEPTIONIST,
      },
      ...(facilityId
        ? { OR: [{ facility_id: facilityId }, { facility_id: null }] }
        : {}),
    },
    select: { user_id: true },
  });

  return rows.map((row) => row.user_id).filter(Boolean);
};

const resolveRoleRecipients = async ({
  tenantId,
  facilityId = null,
  roles = [],
}) => {
  if (!tenantId || !Array.isArray(roles) || roles.length === 0) return [];

  const rows = await prisma.user_role.findMany({
    where: {
      tenant_id: tenantId,
      deleted_at: null,
      role: {
        deleted_at: null,
        name: {
          in: roles,
        },
      },
      ...(facilityId
        ? { OR: [{ facility_id: facilityId }, { facility_id: null }] }
        : {}),
    },
    select: { user_id: true },
  });

  return rows.map((row) => row.user_id).filter(Boolean);
};

const createReminderNotifications = async ({
  tenantId,
  recipientUserIds,
  title,
  message,
  priority = "MEDIUM",
  targetPath = null,
  contextType = null,
  contextPublicId = null,
  emitRealtime = true,
}) => {
  const uniqueRecipients = Array.from(
    new Set(recipientUserIds.filter(Boolean)),
  );
  if (uniqueRecipients.length === 0) return [];

  const notifications = [];
  for (const userId of uniqueRecipients) {
    try {
      const notification = await prisma.notification.create({
        data: {
          tenant_id: tenantId,
          user_id: userId,
          notification_type: "SYSTEM",
          priority,
          title,
          message,
          target_path: targetPath || null,
          context_type: contextType || null,
          context_public_id: contextPublicId || null,
        },
      });
      notifications.push(notification);
    } catch (_error) {
      // Ignore per-recipient failure to keep dispatcher resilient.
    }
  }

  if (notifications.length > 0) {
    try {
      await prisma.notification_delivery.createMany({
        data: notifications.map((notification) => ({
          notification_id: notification.id,
          channel: "IN_APP",
          status: "PENDING_ATTENTION",
          sent_at: new Date(),
        })),
      });
    } catch (_error) {
      // Delivery metadata is best-effort.
    }
  }

  if (emitRealtime) {
    notifications.forEach((notification) => {
      try {
        emitToUser(
          notification.user_id,
          NOTIFICATION_EVENTS.NOTIFICATION_CREATED,
          {
            notification: {
              id: notification.human_friendly_id || null,
              tenant_id: null,
              user_id: null,
              notification_type: notification.notification_type,
              priority: notification.priority,
              title: notification.title,
              message: notification.message,
              read_at: notification.read_at || null,
              created_at: notification.created_at,
              updated_at: notification.updated_at,
              target_path: notification.target_path || targetPath || null,
              context_type: notification.context_type || contextType || null,
              context_public_id:
                notification.context_public_id || contextPublicId || null,
            },
            target_path: notification.target_path || targetPath || null,
          },
        );
      } catch (_error) {
        // realtime emission is best-effort.
      }
    });
  }

  return notifications;
};

/**
 * List follow-ups with pagination and filtering
 */
const listFollowUps = async (filters, page, limit, sortBy, order) => {
  try {
    const skip = (page - 1) * limit;
    const orderBy = sortBy ? { [sortBy]: order } : { scheduled_at: "asc" };
    const whereClause = {};

    if (filters.encounter_id) whereClause.encounter_id = filters.encounter_id;
    if (filters.status)
      whereClause.status = normalizeStatus(filters.status, "SCHEDULED");
    if (filters.scheduled_before || filters.scheduled_after) {
      whereClause.scheduled_at = {};
      if (filters.scheduled_before)
        whereClause.scheduled_at.lte = new Date(filters.scheduled_before);
      if (filters.scheduled_after)
        whereClause.scheduled_at.gte = new Date(filters.scheduled_after);
    }

    const [followUps, total] = await Promise.all([
      followUpRepository.findMany(whereClause, skip, limit, orderBy),
      followUpRepository.count(whereClause),
    ]);

    return {
      followUps,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasNextPage: page < Math.ceil(total / limit),
        hasPreviousPage: page > 1,
      },
    };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError("errors.server.unexpected", 500, [
      { originalError: error.message },
    ]);
  }
};

/**
 * Get follow-up by ID
 */
const getFollowUpById = async (id) => {
  try {
    const followUp = await followUpRepository.findById(id);
    if (!followUp) {
      throw new HttpError("errors.follow_up.not_found", 404);
    }
    return followUp;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError("errors.server.unexpected", 500, [
      { originalError: error.message },
    ]);
  }
};

/**
 * Create follow-up
 */
const createFollowUp = async (data, userId, ipAddress) => {
  try {
    const payload = {
      ...data,
      status: normalizeStatus(data.status, "SCHEDULED"),
    };
    const followUp = await followUpRepository.create(payload);

    createAuditLog({
      user_id: userId,
      action: "CREATE",
      entity: "follow_up",
      entity_id: followUp.id,
      diff: { after: followUp },
      ip_address: ipAddress,
    }).catch(() => {});

    return followUp;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError("errors.server.unexpected", 500, [
      { originalError: error.message },
    ]);
  }
};

/**
 * Update follow-up
 */
const updateFollowUp = async (id, data, userId, ipAddress) => {
  try {
    const before = await followUpRepository.findById(id);
    if (!before) {
      throw new HttpError("errors.follow_up.not_found", 404);
    }

    const payload = { ...data };
    if (payload.status) {
      const nextStatus = normalizeStatus(payload.status);
      if (nextStatus !== before.status) {
        assertTransition(before.status, nextStatus);
      }
      payload.status = nextStatus;
    }

    const followUp = await followUpRepository.update(id, payload);

    createAuditLog({
      user_id: userId,
      action: "UPDATE",
      entity: "follow_up",
      entity_id: followUp.id,
      diff: { before, after: followUp },
      ip_address: ipAddress,
    }).catch(() => {});

    return followUp;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError("errors.server.unexpected", 500, [
      { originalError: error.message },
    ]);
  }
};

/**
 * Delete follow-up (soft delete)
 */
const deleteFollowUp = async (id, userId, ipAddress) => {
  try {
    const before = await followUpRepository.findById(id);
    if (!before) {
      throw new HttpError("errors.follow_up.not_found", 404);
    }

    await followUpRepository.softDelete(id);

    createAuditLog({
      user_id: userId,
      action: "DELETE",
      entity: "follow_up",
      entity_id: id,
      diff: { before },
      ip_address: ipAddress,
    }).catch(() => {});
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError("errors.server.unexpected", 500, [
      { originalError: error.message },
    ]);
  }
};

const transitionFollowUp = async (
  id,
  targetStatus,
  metadata = {},
  userId,
  ipAddress,
  action = "UPDATE",
) => {
  const before = await followUpRepository.findById(id);
  if (!before) {
    throw new HttpError("errors.follow_up.not_found", 404);
  }

  const normalizedTarget = normalizeStatus(targetStatus);
  if (before.status === normalizedTarget) {
    return before;
  }

  assertTransition(before.status, normalizedTarget);

  const updatePayload = {
    status: normalizedTarget,
  };
  if (normalizedTarget === "COMPLETED") {
    updatePayload.completed_at = new Date();
    updatePayload.completed_by_user_id = userId || null;
  }

  const followUp = await followUpRepository.update(id, updatePayload);

  createAuditLog({
    user_id: userId,
    action,
    entity: "follow_up",
    entity_id: followUp.id,
    diff: {
      before,
      after: followUp,
      metadata: {
        notes: metadata?.notes || null,
      },
    },
    ip_address: ipAddress,
  }).catch(() => {});

  return followUp;
};

const completeFollowUp = async (id, data = {}, userId, ipAddress) =>
  transitionFollowUp(id, "COMPLETED", data, userId, ipAddress, "COMPLETE");

const cancelFollowUp = async (id, data = {}, userId, ipAddress) =>
  transitionFollowUp(id, "CANCELLED", data, userId, ipAddress, "CANCEL");

const getFollowUpReminderDueSummary = async () => {
  const now = new Date();
  const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);

  const [dueNowCount, dueIn24hCount] = await Promise.all([
    prisma.follow_up.count({
      where: {
        deleted_at: null,
        status: "SCHEDULED",
        scheduled_at: { lte: now },
        reminder_due_sent_at: null,
      },
    }),
    prisma.follow_up.count({
      where: {
        deleted_at: null,
        status: "SCHEDULED",
        scheduled_at: { gt: now, lte: in24h },
        reminder_24h_sent_at: null,
      },
    }),
  ]);

  return {
    generated_at: now.toISOString(),
    due_now: dueNowCount,
    due_in_24h: dueIn24hCount,
  };
};

const dispatchFollowUpReminders = async (context = {}) => {
  if (!isFeatureEnabled("follow_up_reminder_dispatch")) {
    return {
      dispatched: false,
      reason: "feature_disabled",
      summary: await getFollowUpReminderDueSummary(),
      sent_24h: 0,
      sent_due: 0,
    };
  }

  const now = new Date();
  const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);

  const candidates = await prisma.follow_up.findMany({
    where: {
      deleted_at: null,
      status: "SCHEDULED",
      OR: [
        {
          scheduled_at: { gt: now, lte: in24h },
          reminder_24h_sent_at: null,
        },
        {
          scheduled_at: { lte: now },
          reminder_due_sent_at: null,
        },
      ],
    },
    include: {
      encounter: {
        include: {
          patient: true,
        },
      },
    },
    orderBy: { scheduled_at: "asc" },
  });

  let sent24h = 0;
  let sentDue = 0;

  for (const followUp of candidates) {
    const encounter = followUp.encounter;
    if (!encounter?.tenant_id) continue;

    const ipdMedicationReminder = parseIpdMedicationReminderNote(
      followUp.notes,
    );

    const recipientUserIds = ipdMedicationReminder
      ? [
          ...(encounter.provider_user_id ? [encounter.provider_user_id] : []),
          ...(await resolveRoleRecipients({
            tenantId: encounter.tenant_id,
            facilityId: encounter.facility_id || null,
            roles: IPD_REMINDER_RECIPIENT_ROLES,
          })),
        ]
      : [
          ...(encounter.provider_user_id ? [encounter.provider_user_id] : []),
          ...(await resolveFrontDeskRecipients({
            tenantId: encounter.tenant_id,
            facilityId: encounter.facility_id || null,
          })),
        ];

    const patientName = [
      encounter?.patient?.first_name,
      encounter?.patient?.last_name,
    ]
      .map((value) => String(value || "").trim())
      .filter(Boolean)
      .join(" ");

    const shouldSendDue =
      followUp.reminder_due_sent_at == null && followUp.scheduled_at <= now;
    const shouldSend24h =
      !ipdMedicationReminder &&
      !shouldSendDue &&
      followUp.reminder_24h_sent_at == null &&
      followUp.scheduled_at > now &&
      followUp.scheduled_at <= in24h;

    if (!shouldSendDue && !shouldSend24h) {
      continue;
    }

    const reminderKind = shouldSendDue ? "DUE" : "DUE_IN_24H";
    const title = ipdMedicationReminder
      ? reminderKind === "DUE"
        ? "Medication due now"
        : "Medication due in 24 hours"
      : reminderKind === "DUE"
        ? "Follow-up due now"
        : "Follow-up due in 24 hours";
    const medicationLabel =
      ipdMedicationReminder?.medication_label ||
      [ipdMedicationReminder?.dose, ipdMedicationReminder?.unit]
        .filter(Boolean)
        .join(" ");
    const message = ipdMedicationReminder
      ? patientName
        ? `${medicationLabel || "Medication"} for ${patientName} is due now.`
        : `${medicationLabel || "Medication"} is due now.`
      : patientName
        ? `Follow-up for ${patientName} is ${reminderKind === "DUE" ? "due now" : "due within 24 hours"}.`
        : `A scheduled follow-up is ${reminderKind === "DUE" ? "due now" : "due within 24 hours"}.`;
    const targetPath = ipdMedicationReminder?.admission_public_id
      ? `/ipd?id=${encodeURIComponent(ipdMedicationReminder.admission_public_id)}&panel=medication`
      : null;

    await createReminderNotifications({
      tenantId: encounter.tenant_id,
      recipientUserIds,
      title,
      message,
      priority: reminderKind === "DUE" ? "HIGH" : "MEDIUM",
      targetPath,
      contextType: ipdMedicationReminder
        ? "ipd_medication_reminder"
        : "follow_up",
      contextPublicId: ipdMedicationReminder?.admission_public_id || null,
    });

    await prisma.follow_up.update({
      where: { id: followUp.id },
      data: shouldSendDue
        ? { reminder_due_sent_at: new Date() }
        : { reminder_24h_sent_at: new Date() },
    });

    if (shouldSendDue) sentDue += 1;
    if (shouldSend24h) sent24h += 1;
  }

  createAuditLog({
    tenant_id: context.tenant_id || null,
    user_id: context.user_id || null,
    action: "DISPATCH",
    entity: "follow_up_reminder",
    entity_id: `dispatcher:${new Date().toISOString()}`,
    diff: {
      after: {
        sent_24h: sent24h,
        sent_due: sentDue,
      },
    },
    ip_address: context.ip_address,
  }).catch(() => {});

  return {
    dispatched: true,
    sent_24h: sent24h,
    sent_due: sentDue,
    summary: await getFollowUpReminderDueSummary(),
  };
};

module.exports = {
  listFollowUps,
  getFollowUpById,
  createFollowUp,
  updateFollowUp,
  deleteFollowUp,
  completeFollowUp,
  cancelFollowUp,
  dispatchFollowUpReminders,
  getFollowUpReminderDueSummary,
};
