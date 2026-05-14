const subject = require('@modules/patient-document/routes/patient-document.routes');

describe('patient-document.routes contract', () => {
  it('exports an express router with registered handlers', () => {
    expect(subject).toBeDefined();
    expect(typeof subject).toBe('function');
    expect(Array.isArray(subject.stack)).toBe(true);
    expect(subject.stack.length).toBeGreaterThan(0);
  });

  it('registers the expected patient document endpoints and methods', () => {
    const routes = subject.stack
      .filter(layer => layer.route)
      .map(layer => ({
        path: layer.route.path,
        methods: Object.keys(layer.route.methods).sort()
      }));

    expect(routes).toEqual(
      expect.arrayContaining([
        { path: '/', methods: ['get'] },
        { path: '/', methods: ['post'] },
        { path: '/:id', methods: ['get'] },
        { path: '/:id', methods: ['put'] },
        { path: '/:id', methods: ['delete'] }
      ])
    );
  });
});
