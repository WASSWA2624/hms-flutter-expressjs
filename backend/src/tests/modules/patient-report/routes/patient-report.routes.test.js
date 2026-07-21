const subject = require('@modules/patient-report/routes/patient-report.routes');

describe('patient-report.routes contract', () => {
  test('exposes sections, jobs, download, and print-event routes', () => {
    const routes = subject.stack
      .filter((layer) => layer.route)
      .map((layer) => ({
        path: layer.route.path,
        methods: Object.keys(layer.route.methods).sort()}));

    expect(routes).toEqual(
      expect.arrayContaining([
        { path: '/sections', methods: ['get'] },
        { path: '/print-events', methods: ['post'] },
        { path: '/jobs', methods: ['post'] },
        { path: '/jobs/:id', methods: ['get'] },
        { path: '/jobs/:id/download', methods: ['get'] }])
    );
  });
});
