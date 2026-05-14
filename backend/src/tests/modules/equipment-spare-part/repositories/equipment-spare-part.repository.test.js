const subject = require('@repositories/equipment-spare-part/equipment-spare-part.repository');

describe('equipment-spare-part.repository contract', () => {
  it('exports repository functions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    const keys = Object.keys(subject);
    expect(keys.length).toBeGreaterThan(0);
    keys.forEach((key) => expect(typeof subject[key]).toBe('function'));
  });
});
