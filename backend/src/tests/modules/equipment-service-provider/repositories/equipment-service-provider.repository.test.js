const subject = require('@repositories/equipment-service-provider/equipment-service-provider.repository');

describe('equipment-service-provider.repository contract', () => {
  it('exports repository functions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    const keys = Object.keys(subject);
    expect(keys.length).toBeGreaterThan(0);
    keys.forEach((key) => expect(typeof subject[key]).toBe('function'));
  });
});
