const subject = require('../../../../modules/roster-day-off/controllers/roster-day-off.controller');

describe('roster-day-off.controller contract', () => {
  it('exports controller handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
