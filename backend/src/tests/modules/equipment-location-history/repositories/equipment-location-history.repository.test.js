const subject = require('@repositories/equipment-location-history/equipment-location-history.repository');

describe('equipment-location-history.repository contract', () => {
  it('exports repository functions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    const keys = Object.keys(subject);
    expect(keys.length).toBeGreaterThan(0);
    keys.forEach((key) => expect(typeof subject[key]).toBe('function'));
  });
});
