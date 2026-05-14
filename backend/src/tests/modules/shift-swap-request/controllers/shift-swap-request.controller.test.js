const subject = require('../../../../modules/shift-swap-request/controllers/shift-swap-request.controller');

describe('shift-swap-request.controller contract', () => {
  it('exports controller handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
