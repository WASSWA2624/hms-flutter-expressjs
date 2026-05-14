const subject = require('../../../../modules/shift-assignment/controllers/shift-assignment.controller');

describe('shift-assignment.controller contract', () => {
  it('exports controller handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
