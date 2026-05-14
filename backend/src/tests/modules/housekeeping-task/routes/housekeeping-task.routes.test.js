/**
 * Housekeeping task routes tests
 *
 * @module tests/modules/housekeeping-task/routes
 * Per testing.mdc: Test route configuration
 */

const express = require('express');

// Mock middlewares and controllers
jest.mock('@middlewares/validate.middleware', () => ({
  validateRequest: jest.fn(() => (req, res, next) => next())
}));
jest.mock('@middlewares/auth.middleware', () => ({
  authenticate: jest.fn(() => (req, res, next) => next())
}));
jest.mock('@controllers/housekeeping-task/housekeeping-task.controller', () => ({
  listHousekeepingTasks: jest.fn((req, res) => res.json({ success: true })),
  getHousekeepingTaskById: jest.fn((req, res) => res.json({ success: true })),
  createHousekeepingTask: jest.fn((req, res) => res.json({ success: true })),
  updateHousekeepingTask: jest.fn((req, res) => res.json({ success: true })),
  deleteHousekeepingTask: jest.fn((req, res) => res.json({ success: true }))
}));

describe('Housekeeping Task Routes', () => {
  it('should export express router', () => {
    const router = require('@routes/housekeeping-task/housekeeping-task.routes');
    expect(router).toBeDefined();
    expect(typeof router).toBe('function');
  });

  it('should have GET / route', () => {
    const router = require('@routes/housekeeping-task/housekeeping-task.routes');
    const routes = router.stack.filter(layer => layer.route);
    const getRoute = routes.find(layer => layer.route.path === '/' && layer.route.methods.get);
    expect(getRoute).toBeDefined();
  });

  it('should have GET /:id route', () => {
    const router = require('@routes/housekeeping-task/housekeeping-task.routes');
    const routes = router.stack.filter(layer => layer.route);
    const getRoute = routes.find(layer => layer.route.path === '/:id' && layer.route.methods.get);
    expect(getRoute).toBeDefined();
  });

  it('should have POST / route', () => {
    const router = require('@routes/housekeeping-task/housekeeping-task.routes');
    const routes = router.stack.filter(layer => layer.route);
    const postRoute = routes.find(layer => layer.route.path === '/' && layer.route.methods.post);
    expect(postRoute).toBeDefined();
  });

  it('should have PUT /:id route', () => {
    const router = require('@routes/housekeeping-task/housekeeping-task.routes');
    const routes = router.stack.filter(layer => layer.route);
    const putRoute = routes.find(layer => layer.route.path === '/:id' && layer.route.methods.put);
    expect(putRoute).toBeDefined();
  });

  it('should have DELETE /:id route', () => {
    const router = require('@routes/housekeeping-task/housekeeping-task.routes');
    const routes = router.stack.filter(layer => layer.route);
    const deleteRoute = routes.find(layer => layer.route.path === '/:id' && layer.route.methods.delete);
    expect(deleteRoute).toBeDefined();
  });
});
