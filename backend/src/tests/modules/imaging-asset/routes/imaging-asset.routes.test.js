/**
 * Imaging asset routes tests
 *
 * @module tests/modules/imaging-asset/routes
 * @description Tests for imaging asset route configurations
 * Per testing.mdc: Route tests verify middleware application and endpoint configuration
 */

describe('Imaging Asset Routes', () => {
  it('should have route configuration', () => {
    const routes = require('@routes/imaging-asset/imaging-asset.routes');
    expect(routes).toBeDefined();
    expect(typeof routes).toBe('function');
  });
});
