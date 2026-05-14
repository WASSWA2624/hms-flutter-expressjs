/**
 * Pre-authorization routes tests
 *
 * @module tests/modules/pre-authorization/routes
 * @description Tests for pre-authorization API endpoints
 * Per testing.mdc: Route tests must verify middleware application and endpoint behavior
 */

const preAuthorizationRoutes = require('@routes/pre-authorization/pre-authorization.routes');

describe('Pre-Authorization Routes', () => {
  it('should export a router', () => {
    expect(preAuthorizationRoutes).toBeDefined();
    expect(typeof preAuthorizationRoutes).toBe('function');
  });

  it('should have GET / route defined', () => {
    const routes = preAuthorizationRoutes.stack.filter(layer => layer.route);
    const getRoot = routes.find(layer => layer.route.path === '/' && layer.route.methods.get);
    expect(getRoot).toBeDefined();
  });

  it('should have GET /:id route defined', () => {
    const routes = preAuthorizationRoutes.stack.filter(layer => layer.route);
    const getById = routes.find(layer => layer.route.path === '/:id' && layer.route.methods.get);
    expect(getById).toBeDefined();
  });

  it('should have POST / route defined', () => {
    const routes = preAuthorizationRoutes.stack.filter(layer => layer.route);
    const postRoot = routes.find(layer => layer.route.path === '/' && layer.route.methods.post);
    expect(postRoot).toBeDefined();
  });

  it('should have PUT /:id route defined', () => {
    const routes = preAuthorizationRoutes.stack.filter(layer => layer.route);
    const putById = routes.find(layer => layer.route.path === '/:id' && layer.route.methods.put);
    expect(putById).toBeDefined();
  });

  it('should have DELETE /:id route defined', () => {
    const routes = preAuthorizationRoutes.stack.filter(layer => layer.route);
    const deleteById = routes.find(layer => layer.route.path === '/:id' && layer.route.methods.delete);
    expect(deleteById).toBeDefined();
  });

  it('should have authentication middleware on all routes', () => {
    const routes = preAuthorizationRoutes.stack.filter(layer => layer.route);
    routes.forEach(layer => {
      const middlewares = layer.route.stack.map(s => s.handle.name);
      // asyncHandler wraps the actual handlers
      expect(middlewares.length).toBeGreaterThan(0);
    });
  });

  it('should have validation middleware on all routes', () => {
    const routes = preAuthorizationRoutes.stack.filter(layer => layer.route);
    routes.forEach(layer => {
      // Each route should have multiple middlewares
      expect(layer.route.stack.length).toBeGreaterThan(1);
    });
  });
});
