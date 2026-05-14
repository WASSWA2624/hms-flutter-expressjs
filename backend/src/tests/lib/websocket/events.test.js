const websocketLib = require('@lib/websocket');
const websocketEvents = require('@lib/websocket/events');

const REQUIRED_GROUPS = [
  'APPOINTMENT_EVENTS',
  'OPD_EVENTS',
  'VISIT_QUEUE_EVENTS',
  'ADMISSION_BED_EVENTS',
  'CRITICAL_ALERT_EVENTS',
  'DIAGNOSTIC_EVENTS',
  'PHARMACY_EVENTS',
  'INVENTORY_EVENTS',
  'EMERGENCY_EVENTS',
  'BILLING_EVENTS',
  'NOTIFICATION_EVENTS',
  'SUBSCRIPTION_EVENTS',
  'INTEGRATION_EVENTS'
];

describe('websocket event catalog', () => {
  test('exports all required HMS app-specific event groups', () => {
    REQUIRED_GROUPS.forEach((group) => {
      expect(websocketEvents[group]).toBeDefined();
      expect(websocketLib[group]).toBeDefined();
      expect(Object.keys(websocketEvents[group]).length).toBeGreaterThan(0);
    });
  });

  test('combined WS_EVENTS map contains unique event names', () => {
    const values = Object.values(websocketEvents.WS_EVENTS);
    const uniqueValues = new Set(values);
    expect(uniqueValues.size).toBe(values.length);
  });
});
