const subject = require('../../../../modules/emergency-case/routes/emergency-case.routes');

describe('emergency-case.routes contract', () => {
  it('exports an express router with registered handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);
    expect(subject.stack.length).toBeGreaterThan(0);
  });

  it('registers the authenticated quick-arrival mutation route', () => {
    const layer = subject.stack.find(
      (candidate) => candidate.route?.path === '/quick-arrival' && candidate.route?.methods?.post === true
    );

    expect(layer).toBeDefined();
    expect(layer.route.stack.length).toBeGreaterThanOrEqual(3);
  });
});
