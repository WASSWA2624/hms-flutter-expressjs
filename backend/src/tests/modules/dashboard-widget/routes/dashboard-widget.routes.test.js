const subject = require('@modules/dashboard-widget/routes/dashboard-widget.routes');

describe('dashboard-widget.routes contract', () => {
  it('exports an express router with registered handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);
    expect(subject.stack.length).toBeGreaterThan(0);
  });

  it('registers GET /summary route', () => {
    const summaryLayer = subject.stack.find((layer) =>
      layer?.route?.path === '/summary' &&
      layer?.route?.methods?.get
    );
    expect(summaryLayer).toBeDefined();
  });
});
