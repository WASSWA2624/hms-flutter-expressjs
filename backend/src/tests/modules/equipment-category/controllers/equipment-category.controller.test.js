const subject = require('@controllers/equipment-category/equipment-category.controller');

describe('equipment-category.controller contract', () => {
  it('exports controller functions', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    const keys = Object.keys(subject);
    expect(keys.length).toBeGreaterThan(0);
    keys.forEach((key) => expect(typeof subject[key]).toBe('function'));
  });
});
