const { context, metrics, trace, SpanStatusCode } = require('@opentelemetry/api');

const meter = metrics.getMeter('hms-backend');
const tracer = trace.getTracer('hms-backend');

const httpRequestCounter = meter.createCounter('hms.http.requests.total', {
  description: 'Total HTTP requests handled by the backend.',
});

const httpRequestDuration = meter.createHistogram('hms.http.request.duration.ms', {
  description: 'HTTP request duration in milliseconds.',
  unit: 'ms',
});

const securityEventCounter = meter.createCounter('hms.security.events.total', {
  description: 'Security-sensitive events such as auth failures and access denials.',
});

const workflowEventCounter = meter.createCounter('hms.workflow.events.total', {
  description: 'Operational workflow events for Last Office, break-glass, and related flows.',
});

const businessEventCounter = meter.createCounter('hms.business.events.total', {
  description: 'Key business workflow counters derived from successful operations.',
});

const backgroundJobCounter = meter.createCounter('hms.background.jobs.total', {
  description: 'Background job lifecycle events such as report execution.',
});

const normalizeAttributes = (attributes = {}) =>
  Object.fromEntries(
    Object.entries(attributes)
      .filter(([, value]) => value !== undefined && value !== null && value !== '')
      .map(([key, value]) => [key, typeof value === 'boolean' ? String(value) : value])
  );

const getActiveSpan = () => trace.getSpan(context.active()) || null;

const setSpanAttributes = (attributes = {}) => {
  const span = getActiveSpan();
  if (!span) return;
  span.setAttributes(normalizeAttributes(attributes));
};

const markSpanError = (error, attributes = {}) => {
  const span = getActiveSpan();
  if (!span) return;
  span.setStatus({
    code: SpanStatusCode.ERROR,
    message: String(error?.message || error || 'Unexpected error'),
  });
  if (attributes && Object.keys(attributes).length > 0) {
    span.setAttributes(normalizeAttributes(attributes));
  }
};

const recordHttpRequest = ({
  method,
  route,
  status_code,
  duration_ms,
  cache_policy,
  tenant_id,
} = {}) => {
  const attributes = normalizeAttributes({
    'http.request.method': method,
    'http.route': route,
    'http.response.status_code': status_code,
    'hms.offline.policy': cache_policy,
    'hms.tenant.present': tenant_id ? 'true' : 'false',
  });

  httpRequestCounter.add(1, attributes);
  if (Number.isFinite(duration_ms)) {
    httpRequestDuration.record(duration_ms, attributes);
  }

  setSpanAttributes({
    'http.route': route,
    'http.response.status_code': status_code,
    'hms.offline.policy': cache_policy,
  });
};

const recordSecurityEvent = (event, attributes = {}) => {
  securityEventCounter.add(
    1,
    normalizeAttributes({
      'hms.security.event': event,
      ...attributes,
    })
  );
};

const recordWorkflowEvent = (event, attributes = {}) => {
  workflowEventCounter.add(
    1,
    normalizeAttributes({
      'hms.workflow.event': event,
      ...attributes,
    })
  );
};

const recordBusinessEvent = (event, attributes = {}) => {
  businessEventCounter.add(
    1,
    normalizeAttributes({
      'hms.business.event': event,
      ...attributes,
    })
  );
};

const recordBackgroundJob = (event, attributes = {}) => {
  backgroundJobCounter.add(
    1,
    normalizeAttributes({
      'hms.background.event': event,
      ...attributes,
    })
  );
};

const startActiveSpan = async (name, attributes, fn) => {
  return tracer.startActiveSpan(name, async (span) => {
    try {
      span.setAttributes(normalizeAttributes(attributes));
      const result = await fn(span);
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (error) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: String(error?.message || error || 'Unexpected error'),
      });
      throw error;
    } finally {
      span.end();
    }
  });
};

module.exports = {
  getActiveSpan,
  markSpanError,
  recordBackgroundJob,
  recordBusinessEvent,
  recordHttpRequest,
  recordSecurityEvent,
  recordWorkflowEvent,
  setSpanAttributes,
  startActiveSpan,
};
