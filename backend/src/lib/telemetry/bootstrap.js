const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-http');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { resourceFromAttributes } = require('@opentelemetry/resources');
const {
  ATTR_SERVICE_NAME,
  ATTR_SERVICE_VERSION
} = require('@opentelemetry/semantic-conventions');
const {
  NODE_ENV,
  OTEL_ENABLED,
  OTEL_SERVICE_NAME,
  OTEL_METRIC_EXPORT_INTERVAL_MS
} = require('@config/env');

const { version: appVersion } = require('../../../package.json');

let telemetrySdk = null;

const createTelemetrySdk = () =>
  new NodeSDK({
    resource: resourceFromAttributes({
      [ATTR_SERVICE_NAME]: OTEL_SERVICE_NAME,
      [ATTR_SERVICE_VERSION]: appVersion,
      'deployment.environment.name': NODE_ENV
    }),
    traceExporter: new OTLPTraceExporter(),
    metricReaders: [
      new PeriodicExportingMetricReader({
        exporter: new OTLPMetricExporter(),
        exportIntervalMillis: OTEL_METRIC_EXPORT_INTERVAL_MS
      })
    ],
    instrumentations: [
      getNodeAutoInstrumentations({
        '@opentelemetry/instrumentation-fs': {
          enabled: false
        }
      })
    ]
  });

const startOpenTelemetry = () => {
  if (!OTEL_ENABLED) {
    return { enabled: false };
  }

  if (telemetrySdk) {
    return { enabled: true, sdk: telemetrySdk };
  }

  try {
    telemetrySdk = createTelemetrySdk();
    telemetrySdk.start();
    return { enabled: true, sdk: telemetrySdk };
  } catch (error) {
    telemetrySdk = null;
    console.warn(`[telemetry] failed to initialize OpenTelemetry: ${error.message}`);
    return { enabled: false, error };
  }
};

const shutdownOpenTelemetry = async () => {
  if (!telemetrySdk) {
    return;
  }

  const sdk = telemetrySdk;
  telemetrySdk = null;
  await sdk.shutdown();
};

module.exports = {
  startOpenTelemetry,
  shutdownOpenTelemetry
};
