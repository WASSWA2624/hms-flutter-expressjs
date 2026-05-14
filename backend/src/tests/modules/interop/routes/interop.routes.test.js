const subject = require('@routes/interop/interop.routes');

const getRouteSignatures = (router) => {
  return router.stack
    .filter((layer) => layer.route)
    .flatMap((layer) => {
      return Object.keys(layer.route.methods).map((method) => `${method.toUpperCase()} ${layer.route.path}`);
    })
    .sort();
};

describe('interop.routes contract', () => {
  it('exports an express router with registered handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);
    expect(subject.stack.length).toBeGreaterThan(0);
  });

  it('registers canonical interop endpoints', () => {
    expect(getRouteSignatures(subject)).toEqual([
      'GET /fhir/export/:resource',
      'GET /migrations/export',
      'POST /dicom/studies/:id/link',
      'POST /fhir/import/:resource',
      'POST /hl7/messages',
      'POST /migrations/import'
    ]);
  });
});
