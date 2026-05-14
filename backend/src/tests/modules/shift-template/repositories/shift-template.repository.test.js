const subject = require('../../../../modules/shift-template/repositories/shift-template.repository');

describe('shift-template.repository contract', () => {
  it('exports repository methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
