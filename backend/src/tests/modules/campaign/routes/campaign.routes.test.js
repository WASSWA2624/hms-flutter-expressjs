const subject = require('@routes/campaign/campaign.routes');

const getRouteSignatures = (router) => {
  return router.stack
    .filter((layer) => layer.route)
    .flatMap((layer) => {
      return Object.keys(layer.route.methods).map((method) => `${method.toUpperCase()} ${layer.route.path}`);
    })
    .sort();
};

describe('campaign.routes contract', () => {
  it('exports an express router with registered handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);
    expect(subject.stack.length).toBeGreaterThan(0);
  });

  it('registers canonical campaign endpoints', () => {
    expect(getRouteSignatures(subject)).toEqual([
      'GET /',
      'GET /:id/metrics'
    ]);
  });
});
