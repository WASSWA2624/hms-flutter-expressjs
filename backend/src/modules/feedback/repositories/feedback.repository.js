/**
 * Feedback repository
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const createFeedbackEvent = async (tenantId, userId, eventName, payloadJson) => {
  try {
    return await prisma.analytics_event.create({
      data: {
        tenant_id: tenantId,
        user_id: userId || null,
        event_name: eventName,
        payload_json: payloadJson
      }
    });
  } catch (error) {
    if (error.code === 'P2003') {
      const target = error.meta?.field_name || 'field';
      throw new HttpError('errors.database.foreign_key_field', 400, [{ field: target }]);
    }
    throw new HttpError('errors.database.unexpected', 500, [{ originalError: error.message }]);
  }
};

module.exports = {
  createFeedbackEvent
};
