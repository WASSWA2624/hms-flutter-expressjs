const websocketLib = require('@lib/websocket');
const websocketEvents = require('@lib/websocket/events');

const REQUIRED_GROUPS = [
  'APPOINTMENT_EVENTS',
  'PATIENT_EVENTS',
  'ENCOUNTER_EVENTS',
  'OPD_EVENTS',
  'VISIT_QUEUE_EVENTS',
  'ADMISSION_BED_EVENTS',
  'CRITICAL_ALERT_EVENTS',
  'DIAGNOSTIC_EVENTS',
  'PHARMACY_EVENTS',
  'INVENTORY_EVENTS',
  'EMERGENCY_EVENTS',
  'PAYMENT_EVENTS',
  'BILLING_EVENTS',
  'NOTIFICATION_EVENTS',
  'SUBSCRIPTION_EVENTS',
  'INTEGRATION_EVENTS'
];

const REQUIRED_DOMAIN_EVENTS = [
  'patient.created',
  'patient.updated',
  'patient.deleted',
  'encounter.created',
  'encounter.updated',
  'encounter.deleted',
  'visit_queue.created',
  'visit_queue.updated',
  'visit_queue.deleted',
  'visit_queue.position_changed',
  'payment.created',
  'payment.updated',
  'payment.deleted',
  'payment.reconciled',
  'invoice.updated',
  'billing.balance_updated'
];

describe('websocket event catalog', () => {
  test('exports all required HMS app-specific event groups', () => {
    REQUIRED_GROUPS.forEach((group) => {
      expect(websocketEvents[group]).toBeDefined();
      expect(websocketLib[group]).toBeDefined();
      expect(Object.keys(websocketEvents[group]).length).toBeGreaterThan(0);
    });
  });

  test('contains required realtime CRUD domain events', () => {
    REQUIRED_DOMAIN_EVENTS.forEach((event) => {
      expect(Object.values(websocketEvents.WS_EVENTS)).toContain(event);
    });
  });

  test('combined WS_EVENTS map contains unique event names', () => {
    const values = Object.values(websocketEvents.WS_EVENTS);
    const uniqueValues = new Set(values);
    expect(uniqueValues.size).toBe(values.length);
  });
});
