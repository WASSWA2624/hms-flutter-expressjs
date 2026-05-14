const subject = require('../../../../modules/nurse-roster/controllers/nurse-roster.controller');

describe('nurse-roster.controller contract', () => {
  it('exports controller handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
