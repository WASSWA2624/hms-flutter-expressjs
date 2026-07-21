/**
 * Performance Middleware
 * 
 * Measures and logs API endpoint response times per performance.mdc
 * Must be applied before routes to measure full request/response cycle
 * 
 * Per performance.mdc:
 * - Performance metrics must be logged or monitored
 * - Alert on API endpoints exceeding thresholds
 */

const { logEndpointPerformance } = require('@lib/performance');
const {
  recordBusinessEvent,
  recordHttpRequest,
  setSpanAttributes,
} = require('@lib/telemetry/metrics');

const deriveBusinessEvent = (req, res) => {
  if (res.statusCode < 200 || res.statusCode >= 300 || req.method !== 'POST') {
    return null;
  }

  const path = String(req.originalUrl || req.path || '').split('?')[0].toLowerCase();
  if (path === '/api/v1/appointments' || path.startsWith('/api/v1/appointments/')) {
    return 'appointment_created';
  }
  if (path === '/api/v1/invoices' || path.startsWith('/api/v1/invoices/')) {
    return 'invoice_created';
  }
  if (path === '/api/v1/payments' || path.startsWith('/api/v1/payments/')) {
    return 'payment_recorded';
  }
  if (path === '/api/v1/lab-results' || path.startsWith('/api/v1/lab-results/')) {
    return 'lab_result_recorded';
  }
  if (path === '/api/v1/equipment-work-orders' || path.startsWith('/api/v1/equipment-work-orders/')) {
    return 'equipment_work_order_updated';
  }
  return null;
};

/**
 * Performance monitoring middleware
 * Measures request duration and logs metrics
 * 
 * @returns {Function} Express middleware
 */
const performanceMiddleware = () => {
  return (req, res, next) => {
    const startTime = Date.now();
    res.once('finish', () => {
      const durationMs = Date.now() - startTime;
      const method = req.method;
      const path = req.route?.path
        ? `${req.baseUrl || ''}${req.route.path}`
        : String(req.originalUrl || req.path || '').split('?')[0];
      const statusCode = res.statusCode;
      const cachePolicy = req.offlinePolicy?.cache || null;

      setImmediate(() => {
        logEndpointPerformance(method, path, durationMs, statusCode);
        recordHttpRequest({
          method,
          route: path,
          status_code: statusCode,
          duration_ms: durationMs,
          cache_policy: cachePolicy,
          tenant_id: req.user?.tenant_id || req.user?.tenantId || null,
        });

        const businessEvent = deriveBusinessEvent(req, res);
        if (businessEvent) {
          recordBusinessEvent(businessEvent, {
            'hms.route.family': String(req.baseUrl || '').replace(/^\/api\/v1\//, ''),
            'hms.status_code': statusCode,
          });
        }
      });

      setSpanAttributes({
        'hms.request.id': req.requestContext?.request_id || req.request_id || null,
        'hms.tenant.id': req.user?.tenant_id || req.user?.tenantId || null,
        'hms.offline.policy': cachePolicy,
      });
    });

    next();
  };
};

module.exports = performanceMiddleware;

