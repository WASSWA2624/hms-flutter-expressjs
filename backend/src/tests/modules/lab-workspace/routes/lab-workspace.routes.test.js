const subject = require('@routes/lab-workspace/lab-workspace.routes');

describe('lab-workspace.routes contract', () => {
  it('exports the expected lab workspace endpoints', () => {
    const routes = subject.stack
      .filter((layer) => layer.route)
      .map((layer) => ({
        path: layer.route.path,
        methods: Object.keys(layer.route.methods),
      }));

    expect(routes).toEqual(
      expect.arrayContaining([
        { path: '/workbench', methods: ['get'] },
        { path: '/resolve-legacy/:resource/:id', methods: ['get'] },
        { path: '/orders/:id/workflow', methods: ['get'] },
        { path: '/orders/:id/collect', methods: ['post'] },
        { path: '/orders/:id/reverse', methods: ['post'] },
        { path: '/samples/:id/receive', methods: ['post'] },
        { path: '/samples/:id/reject', methods: ['post'] },
        { path: '/order-items/:id/release', methods: ['post'] },
      ])
    );
  });
});
