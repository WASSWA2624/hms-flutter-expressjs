const subject = require('@services/equipment-incident-report/equipment-incident-report.service');

describe('equipment-incident-report.service contract', () => {
  it('exports service functions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    const keys = Object.keys(subject);
    expect(keys.length).toBeGreaterThan(0);
    keys.forEach((key) => expect(typeof subject[key]).toBe('function'));
  });
});
