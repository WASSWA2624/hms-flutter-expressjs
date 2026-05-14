const subject = require('../../../../modules/purchase-request/controllers/purchase-request.controller');

describe('purchase-request.controller contract', () => {
  it('exports controller handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('object');
    expect(Object.keys(subject).length).toBeGreaterThan(0);
  });
});
