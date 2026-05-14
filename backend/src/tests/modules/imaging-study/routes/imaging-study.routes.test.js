/**
 * Imaging study routes tests
 *
 * @module tests/modules/imaging-study/routes
 * @description Tests for imaging study route configurations
 * Per testing.mdc: Route tests verify middleware application and endpoint configuration
 */

describe('Imaging Study Routes', () => {
  it('should have route configuration', () => {
    const routes = require('@routes/imaging-study/imaging-study.routes');
    expect(routes).toBeDefined();
    expect(typeof routes).toBe('function');
  });
});
