const subject = require('@routes/triage/triage.routes');

const getRoute = (path, method) =>
  subject.stack.find((layer) => layer.route?.path === path && layer.route?.methods?.[method]);

describe('triage.routes contract', () => {
  it('exports an express router with all triage workflow endpoints', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);

    expect(getRoute('/', 'get')).toBeDefined();
    expect(getRoute('/:id', 'get')).toBeDefined();
    expect(getRoute('/:id/record-vitals', 'post')).toBeDefined();
    expect(getRoute('/:id/assign-provider', 'post')).toBeDefined();
    expect(getRoute('/:id/route', 'post')).toBeDefined();
    expect(getRoute('/:id/correct-stage', 'post')).toBeDefined();
  });

  it('keeps validation, authentication, authorization, and controller middleware on each route', () => {
    const workflowRoutes = ['/', '/:id', '/:id/record-vitals', '/:id/assign-provider', '/:id/route', '/:id/correct-stage'];

    workflowRoutes.forEach((path) => {
      const layer = subject.stack.find((entry) => entry.route?.path === path);

      expect(layer?.route?.stack.length).toBeGreaterThanOrEqual(4);
    });
  });
});
