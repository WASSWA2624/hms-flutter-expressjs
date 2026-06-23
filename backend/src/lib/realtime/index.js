/**
 * Realtime utilities barrel export
 */

const { findRealtimeRecipientUserIds } = require('@lib/realtime/recipients');
const {
  DEFAULT_RECIPIENT_ROLES,
  REALTIME_SKIP_ENTITIES,
  REALTIME_EVENT_OVERRIDES,
  ENTITY_RECIPIENT_ROLES,
  REALTIME_MUTATION_ACTIONS
} = require('@lib/realtime/config');
const {
  publishAuditRealtime,
  resolveRealtimeOperation,
  extractResourceFromAudit
} = require('@lib/realtime/audit-realtime');

module.exports = {
  findRealtimeRecipientUserIds,
  DEFAULT_RECIPIENT_ROLES,
  REALTIME_SKIP_ENTITIES,
  REALTIME_EVENT_OVERRIDES,
  ENTITY_RECIPIENT_ROLES,
  REALTIME_MUTATION_ACTIONS,
  publishAuditRealtime,
  resolveRealtimeOperation,
  extractResourceFromAudit
};
