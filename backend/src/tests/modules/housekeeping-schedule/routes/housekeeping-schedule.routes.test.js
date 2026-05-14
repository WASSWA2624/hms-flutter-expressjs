/**
 * Housekeeping schedule routes tests
 *
 * @module tests/modules/housekeeping-schedule/routes
 * Per testing.mdc: Test route configuration
 */

// Mock middlewares and controllers
jest.mock('@middlewares/validate.middleware', () => ({
  validateRequest: jest.fn(() => (req, res, next) => next())
}));
jest.mock('@middlewares/auth.middleware', () => ({
  authenticate: jest.fn(() => (req, res, next) => next())
}));
jest.mock('@controllers/housekeeping-schedule/housekeeping-schedule.controller', () => ({
  listHousekeepingSchedules: jest.fn((req, res) => res.json({ success: true })),
  getHousekeepingScheduleById: jest.fn((req, res) => res.json({ success: true })),
  createHousekeepingSchedule: jest.fn((req, res) => res.json({ success: true })),
  updateHousekeepingSchedule: jest.fn((req, res) => res.json({ success: true })),
  deleteHousekeepingSchedule: jest.fn((req, res) => res.json({ success: true }))
}));

describe('Housekeeping Schedule Routes', () => {
  it('should export express router', () => {
    const router = require('@routes/housekeeping-schedule/housekeeping-schedule.routes');
    expect(router).toBeDefined();
    expect(typeof router).toBe('function');
  });

  it('should have GET / route', () => {
    const router = require('@routes/housekeeping-schedule/housekeeping-schedule.routes');
    const routes = router.stack.filter(layer => layer.route);
    const getRoute = routes.find(layer => layer.route.path === '/' && layer.route.methods.get);
    expect(getRoute).toBeDefined();
  });

  it('should have GET /:id route', () => {
    const router = require('@routes/housekeeping-schedule/housekeeping-schedule.routes');
    const routes = router.stack.filter(layer => layer.route);
    const getRoute = routes.find(layer => layer.route.path === '/:id' && layer.route.methods.get);
    expect(getRoute).toBeDefined();
  });

  it('should have POST / route', () => {
    const router = require('@routes/housekeeping-schedule/housekeeping-schedule.routes');
    const routes = router.stack.filter(layer => layer.route);
    const postRoute = routes.find(layer => layer.route.path === '/' && layer.route.methods.post);
    expect(postRoute).toBeDefined();
  });

  it('should have PUT /:id route', () => {
    const router = require('@routes/housekeeping-schedule/housekeeping-schedule.routes');
    const routes = router.stack.filter(layer => layer.route);
    const putRoute = routes.find(layer => layer.route.path === '/:id' && layer.route.methods.put);
    expect(putRoute).toBeDefined();
  });

  it('should have DELETE /:id route', () => {
    const router = require('@routes/housekeeping-schedule/housekeeping-schedule.routes');
    const routes = router.stack.filter(layer => layer.route);
    const deleteRoute = routes.find(layer => layer.route.path === '/:id' && layer.route.methods.delete);
    expect(deleteRoute).toBeDefined();
  });
});
