const subject = require('@routes/therapy-flow/therapy-flow.routes');

describe('therapy-flow.routes contract', () => {
  it('exports an express router with handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);
    expect(subject.stack.length).toBeGreaterThan(0);
  });
});
