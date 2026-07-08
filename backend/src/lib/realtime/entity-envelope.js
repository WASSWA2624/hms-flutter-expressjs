/**
 * Standard realtime entity envelope for websocket payloads.
 *
 * Services should pass sanitized list/detail DTO shapes — never raw Prisma rows.
 */

const REALTIME_SYNC_ACTIONS = Object.freeze({
  UPSERT: 'upsert',
  REMOVE: 'remove',
  INVALIDATE: 'invalidate'
});

const compactId = (value) => String(value || '').trim() || null;

/**
 * @param {'upsert'|'remove'|'invalidate'} action
 * @param {Object|null} entity
 * @param {Object} [extra]
 * @returns {Object}
 */
const buildRealtimeEntityEnvelope = (action, entity = null, extra = {}) => {
  const normalizedAction = String(action || REALTIME_SYNC_ACTIONS.UPSERT).trim().toLowerCase();
  const payload = {
    action: normalizedAction,
    ...extra
  };

  if (entity && typeof entity === 'object') {
    payload.entity = entity;
    if (!payload.resource_id) {
      payload.resource_id = compactId(entity.id);
    }
  }

  return payload;
};

/**
 * @param {Object} listEntry - Workspace list row (e.g. OPD { encounter, flow })
 * @param {Object} [extra]
 * @returns {Object}
 */
const buildRealtimeListEntryEnvelope = (listEntry, extra = {}) => ({
  action: REALTIME_SYNC_ACTIONS.UPSERT,
  list_entry: listEntry,
  ...extra
});

module.exports = {
  REALTIME_SYNC_ACTIONS,
  buildRealtimeEntityEnvelope,
  buildRealtimeListEntryEnvelope
};
