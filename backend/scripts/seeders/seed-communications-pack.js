const { DEMO_TENANT } = require('./seed-catalog');

const seedCommunicationsPack = async (ctx, orgPack, accessPack) => {
  const result = {
    conversations: {},
    notifications: {},
    templates: {},
  };

  const scenario = DEMO_TENANT;
  const tenant = orgPack.tenants[scenario.key];
  const doctor = accessPack.users[`${scenario.key}:doctor`];
  const biomed = accessPack.users[`${scenario.key}:biomed`];
  const operations = accessPack.users[`${scenario.key}:operations`];
  const receptionist = accessPack.users[`${scenario.key}:reception`];
  const billing = accessPack.users[`${scenario.key}:billing`];
  const superAdmin = accessPack.users[`${scenario.key}:superadmin`];

  const unreadDirectConversation = await ctx.upsert(
    'conversation',
    `${scenario.key}:conversation:unread-direct`,
    {
      tenant_id: tenant.id,
      subject: null,
      created_by_user_id: doctor.id,
      conversation_type: 'DIRECT',
      status: 'OPEN',
      is_sensitive: false,
      last_message_at: ctx.date(-1, 120),
      archived_at: null,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'CONV',
    }
  );
  result.conversations.unreadDirect = unreadDirectConversation;

  const directOpeningMessage = await ctx.upsert(
    'message',
    `${scenario.key}:message:unread-direct:opening`,
    {
      conversation_id: unreadDirectConversation.id,
      sender_user_id: doctor.id,
      sender_patient_id: null,
      reply_to_message_id: null,
      content: 'Bedside oxygen outlet pressure dropped overnight. Please review the attached fault image before ward rounds.',
      message_type: 'TEXT',
      sent_at: ctx.date(-1, 90),
    },
    {
      publicIdPrefix: 'MSG',
      seedMeta: false,
    }
  );

  const directReplyMessage = await ctx.upsert(
    'message',
    `${scenario.key}:message:unread-direct:reply`,
    {
      conversation_id: unreadDirectConversation.id,
      sender_user_id: biomed.id,
      sender_patient_id: null,
      reply_to_message_id: directOpeningMessage.id,
      content: 'Received. I will inspect bay 1 and bring a backup regulator before the morning handover.',
      message_type: 'TEXT',
      sent_at: ctx.date(-1, 120),
    },
    {
      publicIdPrefix: 'MSG',
      seedMeta: false,
    }
  );

  for (const [participantKey, user, roleSnapshot, lastReadMessageId, lastReadAt] of [
    ['doctor', doctor, 'DOCTOR', directReplyMessage.id, ctx.date(-1, 120)],
    ['biomed', biomed, 'BIOMED', directOpeningMessage.id, ctx.date(-1, 95)],
  ]) {
    await ctx.upsert(
      'conversation_participant',
      `${scenario.key}:participant:unread-direct:${participantKey}`,
      {
        conversation_id: unreadDirectConversation.id,
        user_id: user.id,
        role_snapshot: roleSnapshot,
        joined_at: ctx.date(-10),
        last_read_message_id: lastReadMessageId,
        last_read_at: lastReadAt,
        archived_at: null,
        muted_at: null,
      },
      {
        publicIdPrefix: 'CPA',
        seedMeta: false,
      }
    );
  }

  await ctx.upsert(
    'message_attachment',
    `${scenario.key}:attachment:direct:image`,
    {
      message_id: directOpeningMessage.id,
      tenant_id: tenant.id,
      uploaded_by_user_id: doctor.id,
      storage_key: 'demo/communications/oxygen-outlet-fault.jpg',
      storage_provider: 'public-demo',
      file_name: 'oxygen-outlet-fault.jpg',
      content_type: 'image/jpeg',
      size_bytes: 184320,
      attachment_kind: 'IMAGE',
      public_url: 'https://images.example.com/demo/oxygen-outlet-fault.jpg',
    },
    {
      publicIdPrefix: 'ATT',
      seedMeta: false,
    }
  );

  await ctx.upsert(
    'message_attachment',
    `${scenario.key}:attachment:direct:document`,
    {
      message_id: directReplyMessage.id,
      tenant_id: tenant.id,
      uploaded_by_user_id: biomed.id,
      storage_key: 'demo/communications/maintenance-note.pdf',
      storage_provider: 'public-demo',
      file_name: 'maintenance-note.pdf',
      content_type: 'application/pdf',
      size_bytes: 246810,
      attachment_kind: 'DOCUMENT',
      public_url: 'https://files.example.com/demo/maintenance-note.pdf',
    },
    {
      publicIdPrefix: 'ATT',
      seedMeta: false,
    }
  );

  const archivedConversation = await ctx.upsert(
    'conversation',
    `${scenario.key}:conversation:archived-billing`,
    {
      tenant_id: tenant.id,
      subject: 'Archived discharge deposit handoff',
      created_by_user_id: receptionist.id,
      conversation_type: 'GROUP',
      status: 'ARCHIVED',
      is_sensitive: false,
      last_message_at: ctx.date(-4, 80),
      archived_at: ctx.date(-2),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'CONV',
    }
  );
  result.conversations.archived = archivedConversation;

  for (const [participantKey, user, roleSnapshot] of [
    ['reception', receptionist, 'RECEPTIONIST'],
    ['billing', billing, 'BILLING'],
  ]) {
    await ctx.upsert(
      'conversation_participant',
      `${scenario.key}:participant:archived:${participantKey}`,
      {
        conversation_id: archivedConversation.id,
        user_id: user.id,
        role_snapshot: roleSnapshot,
        joined_at: ctx.date(-10),
        last_read_at: ctx.date(-3),
        archived_at: ctx.date(-2),
      },
      {
        publicIdPrefix: 'CPA',
        seedMeta: false,
      }
    );
  }

  await ctx.upsert(
    'message',
    `${scenario.key}:message:archived:summary`,
    {
      conversation_id: archivedConversation.id,
      sender_user_id: receptionist.id,
      content: 'Archived after confirming the discharge balance was settled and the receipt was posted to billing.',
      message_type: 'SYSTEM',
      sent_at: ctx.date(-4, 80),
    },
    {
      publicIdPrefix: 'MSG',
      seedMeta: false,
    }
  );

  const sensitiveConversation = await ctx.upsert(
    'conversation',
    `${scenario.key}:conversation:sensitive-recall`,
    {
      tenant_id: tenant.id,
      subject: 'Sensitive biomedical incident command channel',
      created_by_user_id: operations.id,
      conversation_type: 'GROUP',
      status: 'OPEN',
      is_sensitive: true,
      last_message_at: ctx.date(-1, 200),
      archived_at: null,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'CONV',
    }
  );
  result.conversations.sensitive = sensitiveConversation;

  for (const [participantKey, user, roleSnapshot] of [
    ['doctor', doctor, 'DOCTOR'],
    ['biomed', biomed, 'BIOMED'],
    ['operations', operations, 'OPERATIONS'],
  ]) {
    await ctx.upsert(
      'conversation_participant',
      `${scenario.key}:participant:sensitive:${participantKey}`,
      {
        conversation_id: sensitiveConversation.id,
        user_id: user.id,
        role_snapshot: roleSnapshot,
        joined_at: ctx.date(-5),
        last_read_at: participantKey === 'doctor' ? ctx.date(-1, 150) : ctx.date(-1, 205),
      },
      {
        publicIdPrefix: 'CPA',
        seedMeta: false,
      }
    );
  }

  for (const roleCode of ['BIOMED', 'TENANT_ADMIN', 'OPERATIONS']) {
    await ctx.upsert(
      'conversation_visibility_role',
      `${scenario.key}:visibility-role:${roleCode}`,
      {
        tenant_id: tenant.id,
        conversation_id: sensitiveConversation.id,
        role_code: roleCode,
      },
      {
        publicIdPrefix: 'CVR',
        seedMeta: false,
      }
    );
  }

  await ctx.upsert(
    'message',
    `${scenario.key}:message:sensitive:incident`,
    {
      conversation_id: sensitiveConversation.id,
      sender_user_id: biomed.id,
      content: 'Recall scope confirmed for the ventilator control board. Quarantine the device and issue the compliance notice before midday.',
      message_type: 'TEXT',
      sent_at: ctx.date(-1, 200),
    },
    {
      publicIdPrefix: 'MSG',
      seedMeta: false,
    }
  );

  const encounterReminderTemplate = await ctx.upsert(
    'template',
    `${scenario.key}:template:encounter-reminder`,
    {
      tenant_id: tenant.id,
      name: 'Encounter Reminder',
      channel: 'IN_APP',
      subject: 'Visit follow-up for {{patient_name}}',
      description: 'In-app reminder after triage review',
      body: 'Hello {{user_name}}, please review {{patient_name}} before {{visit_time}}.',
      is_active: true,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'TPL',
    }
  );
  result.templates.encounterReminder = encounterReminderTemplate;

  const recallTemplate = await ctx.upsert(
    'template',
    `${scenario.key}:template:recall-alert`,
    {
      tenant_id: tenant.id,
      name: 'Recall Alert',
      channel: 'SMS',
      subject: 'Recall alert',
      description: 'Compliance recall escalation',
      body: 'Recall {{device_name}} is due by {{due_date}}. Owner: {{owner_name}}.',
      is_active: true,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'TPL',
    }
  );
  result.templates.recallAlert = recallTemplate;

  for (const [templateKey, templateId, variableKey, description, sampleValue] of [
    ['encounter-reminder', encounterReminderTemplate.id, 'patient_name', 'Patient display name', 'Amina Demo-Alpha'],
    ['encounter-reminder', encounterReminderTemplate.id, 'user_name', 'Assigned user display name', 'Jordan Demo'],
    ['encounter-reminder', encounterReminderTemplate.id, 'visit_time', 'Scheduled visit time', '10:30 AM'],
    ['recall-alert', recallTemplate.id, 'device_name', 'Affected device name', 'Puritan Bennett Ventilator'],
    ['recall-alert', recallTemplate.id, 'due_date', 'Recall due date', '2026-03-20'],
    ['recall-alert', recallTemplate.id, 'owner_name', 'Current owner', 'Avery Demo'],
  ]) {
    await ctx.upsert(
      'template_variable',
      `${scenario.key}:template-variable:${templateKey}:${variableKey}`,
      {
        template_id: templateId,
        key: variableKey,
        description,
        sample_value: sampleValue,
      },
      {
        publicIdPrefix: 'TVR',
        seedMeta: false,
      }
    );
  }

  const unreadNotification = await ctx.upsert(
    'notification',
    `${scenario.key}:notification:unread-conversation`,
    {
      tenant_id: tenant.id,
      user_id: biomed.id,
      template_id: encounterReminderTemplate.id,
      notification_type: 'SYSTEM',
      priority: 'HIGH',
      title: 'Unread maintenance escalation',
      message: 'The oxygen outlet escalation thread has unread follow-up notes.',
      target_path: `/communications?panel=inbox&conversationId=${unreadDirectConversation.human_friendly_id}`,
      context_type: 'conversation',
      context_public_id: unreadDirectConversation.human_friendly_id,
      read_at: null,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'NOTI',
    }
  );
  result.notifications.unread = unreadNotification;

  await ctx.upsert(
    'notification_delivery',
    `${scenario.key}:delivery:unread-inapp`,
    {
      notification_id: unreadNotification.id,
      channel: 'IN_APP',
      status: 'DELIVERED',
      recipient_target: biomed.email,
      provider_name: 'in-app',
      attempt_count: 1,
      sent_at: ctx.date(-1, 121),
      delivered_at: ctx.date(-1, 121),
      failed_at: null,
      error_message: null,
      retryable: false,
    },
    {
      publicIdPrefix: 'NDL',
      seedMeta: false,
    }
  );

  const readNotification = await ctx.upsert(
    'notification',
    `${scenario.key}:notification:read-billing`,
    {
      tenant_id: tenant.id,
      user_id: superAdmin.id,
      template_id: null,
      notification_type: 'BILLING',
      priority: 'MEDIUM',
      title: 'Deposit settlement posted',
      message: 'The discharge deposit settlement was posted successfully.',
      target_path: '/billing?tab=settlements',
      context_type: 'invoice',
      context_public_id: 'INV-DEMO-SETTLEMENT',
      read_at: ctx.date(-2, 60),
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'NOTI',
    }
  );
  result.notifications.read = readNotification;

  await ctx.upsert(
    'notification_delivery',
    `${scenario.key}:delivery:failed-sms`,
    {
      notification_id: readNotification.id,
      channel: 'SMS',
      status: 'FAILED',
      recipient_target: superAdmin.email,
      provider_name: 'africas-talking-demo',
      attempt_count: 3,
      sent_at: ctx.date(-2, 55),
      delivered_at: null,
      failed_at: ctx.date(-2, 56),
      error_message: 'Carrier timeout after three retries.',
      retryable: true,
    },
    {
      publicIdPrefix: 'NDL',
      seedMeta: false,
    }
  );

  const conversationLinkedNotification = await ctx.upsert(
    'notification',
    `${scenario.key}:notification:conversation-linked`,
    {
      tenant_id: tenant.id,
      user_id: doctor.id,
      template_id: recallTemplate.id,
      notification_type: 'SYSTEM',
      priority: 'URGENT',
      title: 'Sensitive recall channel updated',
      message: 'A new directive was posted in the biomedical incident command channel.',
      target_path: `/communications?panel=inbox&conversationId=${sensitiveConversation.human_friendly_id}`,
      context_type: 'conversation',
      context_public_id: sensitiveConversation.human_friendly_id,
      read_at: null,
    },
    {
      tenantCode: scenario.tenant_code,
      scenarioKey: scenario.scenario_key,
      publicIdPrefix: 'NOTI',
    }
  );
  result.notifications.conversationLinked = conversationLinkedNotification;

  await ctx.upsert(
    'notification_delivery',
    `${scenario.key}:delivery:conversation-linked-sms`,
    {
      notification_id: conversationLinkedNotification.id,
      channel: 'SMS',
      status: 'SENT',
      recipient_target: doctor.email,
      provider_name: 'enterprise-sms-demo',
      attempt_count: 1,
      sent_at: ctx.date(-1, 201),
      delivered_at: null,
      failed_at: null,
      error_message: null,
      retryable: false,
    },
    {
      publicIdPrefix: 'NDL',
      seedMeta: false,
    }
  );

  return result;
};

module.exports = {
  seedCommunicationsPack,
};
