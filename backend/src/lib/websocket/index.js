/**
 * WebSocket utilities barrel export
 * 
 * @description Centralized exports for WebSocket helpers. Allows importing `@lib/websocket`.
 * Per websockets.mdc: WebSocket events are defined here.
 */

const { 
  WS_EVENTS, 
  CONNECTION_EVENTS, 
  AUTH_EVENTS,
  APPOINTMENT_EVENTS,
  OPD_EVENTS,
  IPD_EVENTS,
  VISIT_QUEUE_EVENTS,
  ADMISSION_BED_EVENTS,
  CRITICAL_ALERT_EVENTS,
  DIAGNOSTIC_EVENTS,
  PHARMACY_EVENTS,
  HR_EVENTS,
  HOUSEKEEPING_EVENTS,
  BIOMEDICAL_EVENTS,
  INVENTORY_EVENTS,
  EMERGENCY_EVENTS,
  BILLING_EVENTS,
  NOTIFICATION_EVENTS,
  SUBSCRIPTION_EVENTS,
  INTEGRATION_EVENTS,
  ACCESS_CONTROL_EVENTS,
  LAST_OFFICE_EVENTS
} = require('@lib/websocket/events');

const { emitToUser, emitBroadcast, emitToUsers } = require('@lib/websocket/emit');

module.exports = {
  // Event constants
  WS_EVENTS,
  CONNECTION_EVENTS,
  AUTH_EVENTS,
  APPOINTMENT_EVENTS,
  OPD_EVENTS,
  IPD_EVENTS,
  VISIT_QUEUE_EVENTS,
  ADMISSION_BED_EVENTS,
  CRITICAL_ALERT_EVENTS,
  DIAGNOSTIC_EVENTS,
  PHARMACY_EVENTS,
  HR_EVENTS,
  HOUSEKEEPING_EVENTS,
  BIOMEDICAL_EVENTS,
  INVENTORY_EVENTS,
  EMERGENCY_EVENTS,
  BILLING_EVENTS,
  NOTIFICATION_EVENTS,
  SUBSCRIPTION_EVENTS,
  INTEGRATION_EVENTS,
  ACCESS_CONTROL_EVENTS,
  LAST_OFFICE_EVENTS,
  
  // Emission utilities (for services)
  emitToUser,
  emitBroadcast,
  emitToUsers
};

