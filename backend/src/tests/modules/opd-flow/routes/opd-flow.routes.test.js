const subject = require('@routes/opd-flow/opd-flow.routes');

const getRouteSignatures = (router) =>
  router.stack
    .filter((layer) => layer.route)
    .flatMap((layer) =>
      Object.keys(layer.route.methods).map((method) => `${method.toUpperCase()} ${layer.route.path}`)
    )
    .sort();

describe('opd-flow.routes contract', () => {
  it('exports an express router with registered handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);
    expect(subject.stack.length).toBeGreaterThan(0);
  });

  it('registers canonical OPD flow endpoints', () => {
    expect(getRouteSignatures(subject)).toEqual([
      'GET /',
      'GET /:id',
      'GET /resolve-legacy/:resource/:id',
      'POST /:id/assign-doctor',
      'POST /:id/correct-stage',
      'POST /:id/disposition',
      'POST /:id/doctor-review',
      'POST /:id/pay-consultation',
      'POST /:id/record-vitals',
      'POST /bootstrap',
      'POST /start'
    ]);
  });

  it('applies validation/auth middleware before handlers', () => {
    const routes = subject.stack.filter((layer) => layer.route);
    routes.forEach((layer) => {
      expect(layer.route.stack.length).toBeGreaterThanOrEqual(4);
    });
  });
});
