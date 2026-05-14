const subject = require('@repositories/equipment-warranty-contract/equipment-warranty-contract.repository');

describe('equipment-warranty-contract.repository contract', () => {
  it('exports repository functions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    const keys = Object.keys(subject);
    expect(keys.length).toBeGreaterThan(0);
    keys.forEach((key) => expect(typeof subject[key]).toBe('function'));
  });
});
