const subject = require('../../../../modules/nurse-roster/repositories/nurse-roster.repository');

describe('nurse-roster.repository contract', () => {
  it('exports repository methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
