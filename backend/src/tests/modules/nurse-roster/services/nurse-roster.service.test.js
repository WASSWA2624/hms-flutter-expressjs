const subject = require('../../../../modules/nurse-roster/services/nurse-roster.service');

describe('nurse-roster.service contract', () => {
  it('exports service methods', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
