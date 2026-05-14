const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

const {
  CONDITIONAL_MUTATION_PREFIXES,
  IDEMPOTENCY_DISABLED_PREFIXES,
  NO_STORE_PREFIXES,
  SAFE_LIST_SYNC_PREFIXES,
} = require('../src/config/offline-policies');
const {
  ACCESS_CONTROL_EVENTS,
  APPOINTMENT_EVENTS,
  BILLING_EVENTS,
  CRITICAL_ALERT_EVENTS,
  DIAGNOSTIC_EVENTS,
  EMERGENCY_EVENTS,
  HOUSEKEEPING_EVENTS,
  INTEGRATION_EVENTS,
  INVENTORY_EVENTS,
  LAST_OFFICE_EVENTS,
  NOTIFICATION_EVENTS,
  OPD_EVENTS,
  IPD_EVENTS,
  PHARMACY_EVENTS,
  SUBSCRIPTION_EVENTS,
  VISIT_QUEUE_EVENTS,
  BIOMEDICAL_EVENTS,
} = require('../src/lib/websocket/events');

const ROOT_DIR = path.resolve(__dirname, '..');
const ROUTER_PATH = path.join(ROOT_DIR, 'src', 'app', 'router.js');
const OUTPUT_PATH = path.join(ROOT_DIR, 'docs', 'api', 'v1', 'openapi.yaml');

const MUTATION_METHODS = ['post', 'put', 'patch', 'delete'];
const LIST_METHODS = new Set(['get', 'head']);
const READ_ONLY_FAMILIES = new Set([
  '/api/v1/audit-logs',
  '/api/v1/integration-logs',
]);
const API_KEY_AUTH_ROUTE_FAMILIES = new Set([
  'integrations',
  'integration-logs',
  'webhook-subscriptions',
  'interop',
]);

const FAMILY_DESCRIPTIONS = Object.freeze({
  auth: 'Authentication, session bootstrap, credential lifecycle, and current-user identity endpoints.',
  public: 'Unauthenticated discovery endpoints used for public-facing service, provider, and branch surfaces.',
  patients: 'PHI-heavy patient registry, workspace, merge, document, timeline, and linked operational views.',
  encounters: 'Clinical encounter creation, retrieval, and lifecycle management for patient care workflows.',
  'clinical-notes': 'Structured clinician notes tied to patient encounters and PHI-safe audit trails.',
  'nursing-notes': 'Nursing documentation and bedside record updates with PHI-aware handling.',
  'medication-administrations': 'Medication administration events and point-of-care documentation.',
  refunds: 'Financial adjustment and refund operations that require approval-sensitive controls.',
  'audit-logs': 'Compliance and audit evidence retrieval endpoints.',
  'phi-access-logs': 'Protected health information access evidence and compliance review endpoints.',
  'data-processing-logs': 'Data processing evidence records for privacy and regulatory workflows.',
  'abac-policies': 'Attribute-based access control policy administration layered on top of canonical RBAC.',
  'break-glass-access': 'Emergency access request lifecycle with reason capture, expiry, revocation, and reviewability.',
  'break-glass-reviews': 'Break-glass review queue and review decisions for emergency-access governance.',
  'office-contexts': 'Last Office context lifecycle for facility, branch, shift, holder, and handover timing.',
  'shift-closes': 'Shift close reconciliation, submission, approval, and operational audit evidence.',
  'day-closes': 'End-of-day checklist, blockers, unresolved items, and approval workflow.',
  handovers: 'End-of-shift handover creation, acceptance, and accountability transfer records.',
  'custody-snapshots': 'Cash, assets, and controlled-item custody snapshots for Last Office closeout.',
  'closeout-packs': 'Evidence bundle generation and export tracking using the existing reporting/storage stack.',
  'report-runs': 'Reporting job execution, retries, cancellation, and export download tracking.',
  'report-schedules': 'Scheduled reporting definitions used to automate report-run orchestration.',
  scheduling: 'Scheduling workspace aggregation and orchestration endpoints.',
  billing: 'Billing workspace and reconciliation endpoints.',
  biomedical: 'Biomedical workspace and equipment-service operational endpoints.',
  interop: 'Integration, migration, and interoperability orchestration endpoints.',
});

const FAMILY_SCHEMA_OVERRIDES = Object.freeze({
  'abac-policies': 'AbacPolicy',
  'break-glass-access': 'BreakGlassAccess',
  'break-glass-reviews': 'BreakGlassReview',
  'office-contexts': 'OfficeContext',
  'shift-closes': 'ShiftClose',
  'day-closes': 'DayClose',
  handovers: 'Handover',
  'custody-snapshots': 'CustodySnapshot',
  'closeout-packs': 'CloseoutPack',
});

const REQUEST_SCHEMA_OVERRIDES = Object.freeze({
  'abac-policies': {
    '/': {
      post: 'AbacPolicyWriteRequest',
      put: 'AbacPolicyWriteRequest',
    },
    '/:id': {
      put: 'AbacPolicyWriteRequest',
    },
  },
  'break-glass-access': {
    '/': {
      post: 'BreakGlassAccessRequest',
    },
    '/:id/revoke': {
      post: 'BreakGlassAccessRevokeRequest',
    },
  },
  'break-glass-reviews': {
    '/': {
      post: 'BreakGlassReviewWriteRequest',
    },
  },
  'office-contexts': {
    '/': {
      post: 'OfficeContextWriteRequest',
    },
    '/:id': {
      put: 'OfficeContextUpdateRequest',
    },
    '/:id/close': {
      post: 'OfficeContextCloseRequest',
    },
  },
  'shift-closes': {
    '/': {
      post: 'ShiftCloseWriteRequest',
    },
    '/:id': {
      put: 'ShiftCloseWriteRequest',
    },
    '/:id/approve': {
      post: 'ApprovalNoteRequest',
    },
  },
  'day-closes': {
    '/': {
      post: 'DayCloseWriteRequest',
    },
    '/:id': {
      put: 'DayCloseWriteRequest',
    },
    '/:id/approve': {
      post: 'DayCloseApprovalRequest',
    },
  },
  handovers: {
    '/': {
      post: 'HandoverWriteRequest',
    },
    '/:id': {
      put: 'HandoverUpdateRequest',
    },
    '/:id/accept': {
      post: 'AcceptanceNoteRequest',
    },
  },
  'custody-snapshots': {
    '/': {
      post: 'CustodySnapshotWriteRequest',
    },
    '/:id': {
      put: 'CustodySnapshotWriteRequest',
    },
    '/:id/finalize': {
      post: 'CustodySnapshotFinalizeRequest',
    },
  },
  'closeout-packs': {
    '/': {
      post: 'CloseoutPackWriteRequest',
    },
  },
});

const FAMILY_EVENT_MAP = Object.freeze({
  appointments: Object.values(APPOINTMENT_EVENTS),
  'visit-queues': Object.values(VISIT_QUEUE_EVENTS),
  'critical-alerts': Object.values(CRITICAL_ALERT_EVENTS),
  'lab-results': Object.values(DIAGNOSTIC_EVENTS).filter((eventName) => eventName.startsWith('diagnostic.lab')),
  'radiology-results': Object.values(DIAGNOSTIC_EVENTS).filter((eventName) => eventName.startsWith('diagnostic.radiology')),
  'pharmacy-orders': Object.values(PHARMACY_EVENTS),
  'inventory-stocks': Object.values(INVENTORY_EVENTS),
  'inventory-items': Object.values(INVENTORY_EVENTS),
  'emergency-cases': Object.values(EMERGENCY_EVENTS),
  payments: Object.values(BILLING_EVENTS),
  invoices: Object.values(BILLING_EVENTS),
  refunds: Object.values(BILLING_EVENTS),
  notifications: Object.values(NOTIFICATION_EVENTS),
  messages: Object.values(NOTIFICATION_EVENTS),
  subscriptions: Object.values(SUBSCRIPTION_EVENTS),
  'module-subscriptions': Object.values(SUBSCRIPTION_EVENTS),
  integrations: Object.values(INTEGRATION_EVENTS),
  'integration-logs': Object.values(INTEGRATION_EVENTS),
  interop: Object.values(INTEGRATION_EVENTS),
  'opd-flows': Object.values(OPD_EVENTS),
  'ipd-flows': Object.values(IPD_EVENTS),
  'housekeeping-tasks': Object.values(HOUSEKEEPING_EVENTS),
  'maintenance-requests': Object.values(HOUSEKEEPING_EVENTS),
  'equipment-work-orders': Object.values(BIOMEDICAL_EVENTS),
  'break-glass-access': [
    ACCESS_CONTROL_EVENTS.BREAK_GLASS_REQUESTED,
    ACCESS_CONTROL_EVENTS.BREAK_GLASS_REVOKED,
  ],
  'break-glass-reviews': [ACCESS_CONTROL_EVENTS.BREAK_GLASS_REVIEWED],
  'office-contexts': [LAST_OFFICE_EVENTS.OFFICE_CONTEXT_OPENED],
  'shift-closes': [
    LAST_OFFICE_EVENTS.SHIFT_CLOSE_SUBMITTED,
    LAST_OFFICE_EVENTS.SHIFT_CLOSE_APPROVED,
  ],
  'day-closes': [
    LAST_OFFICE_EVENTS.DAY_CLOSE_SUBMITTED,
    LAST_OFFICE_EVENTS.DAY_CLOSE_APPROVED,
  ],
  handovers: [LAST_OFFICE_EVENTS.HANDOVER_ACCEPTED],
  'custody-snapshots': [LAST_OFFICE_EVENTS.CUSTODY_SNAPSHOT_FINALIZED],
  'closeout-packs': [LAST_OFFICE_EVENTS.CLOSEOUT_PACK_READY],
});

const HEALTH_ENDPOINTS = Object.freeze([
  { method: 'get', path: '/health', summary: 'Health check', description: 'Public readiness of the application shell and core dependencies.' },
  { method: 'get', path: '/ready', summary: 'Readiness check', description: 'Public readiness signal for orchestrators and deployment automation.' },
  { method: 'get', path: '/live', summary: 'Liveness check', description: 'Public liveness probe for runtime availability.' },
]);

const readFile = (filePath) => fs.readFileSync(filePath, 'utf8');

const ensureFilePath = (filePath) => {
  if (fs.existsSync(filePath)) {
    return filePath;
  }

  const withJs = `${filePath}.js`;
  if (fs.existsSync(withJs)) {
    return withJs;
  }

  throw new Error(`Unable to resolve route file: ${filePath}`);
};

const titleCase = (value) =>
  String(value || '')
    .replace(/[-_/]+/g, ' ')
    .replace(/\bapi\b/gi, 'API')
    .replace(/\babac\b/gi, 'ABAC')
    .replace(/\bphi\b/gi, 'PHI')
    .replace(/\bicu\b/gi, 'ICU')
    .replace(/\bipd\b/gi, 'IPD')
    .replace(/\bopd\b/gi, 'OPD')
    .replace(/\bris\b/gi, 'RIS')
    .replace(/\bpacs\b/gi, 'PACS')
    .replace(/\blis\b/gi, 'LIS')
    .replace(/\bhr\b/gi, 'HR')
    .replace(/\bkpi\b/gi, 'KPI')
    .replace(/\bfhir\b/gi, 'FHIR')
    .replace(/\bhl7\b/gi, 'HL7')
    .replace(/\bdicom\b/gi, 'DICOM')
    .replace(/\bws\b/gi, 'WS')
    .replace(/\b([a-z])/g, (match) => match.toUpperCase());

const singularize = (value) => {
  const special = {
    facilities: 'facility',
    diagnoses: 'diagnosis',
    allergies: 'allergy',
    analyses: 'analysis',
    categories: 'category',
    policies: 'policy',
    bodies: 'body',
    histories: 'history',
  };

  if (special[value]) {
    return special[value];
  }

  if (value.endsWith('ies')) {
    return `${value.slice(0, -3)}y`;
  }

  if (value.endsWith('sses')) {
    return value.slice(0, -2);
  }

  if (value.endsWith('s') && !value.endsWith('ss')) {
    return value.slice(0, -1);
  }

  return value;
};

const normalizeOpenApiPath = (value) =>
  String(value || '')
    .replace(/\/+/g, '/')
    .replace(/:(\w+)/g, '{$1}')
    .replace(/\/$/, '') || '/';

const toOperationId = (method, fullPath) => {
  const normalized = fullPath
    .replace(/[{}]/g, '')
    .replace(/^\//, '')
    .replace(/\/+/g, '_')
    .replace(/[^a-zA-Z0-9_]/g, '_');
  return `${method}_${normalized}`.replace(/_+/g, '_');
};

const unique = (values) => [...new Set(values)];

const parseMountedRoutes = () => {
  const routerSource = readFile(ROUTER_PATH);
  const mountRegex = /apiV1Router\.use\(\s*['"`]([^'"`]+)['"`]\s*,\s*require\(['"`]([^'"`]+)['"`]\)\s*\)/g;
  const routeRegex = /router\.(get|post|put|patch|delete)\(\s*['"`]([^'"`]+)['"`]/gm;
  const mounted = [];
  let mountMatch;

  while ((mountMatch = mountRegex.exec(routerSource)) !== null) {
    const mountPath = mountMatch[1];
    const requirePath = mountMatch[2];
    const absoluteRouteFile = ensureFilePath(path.resolve(path.dirname(ROUTER_PATH), requirePath));
    const routeSource = readFile(absoluteRouteFile);
    const operations = [];
    let routeMatch;

    while ((routeMatch = routeRegex.exec(routeSource)) !== null) {
      operations.push({
        method: routeMatch[1],
        localPath: routeMatch[2],
      });
    }

    mounted.push({
      mountPath,
      moduleKey: mountPath.replace(/^\//, ''),
      routeFile: path.relative(ROOT_DIR, absoluteRouteFile).replace(/\\/g, '/'),
      operations,
    });
  }

  return mounted.sort((left, right) => left.mountPath.localeCompare(right.mountPath));
};

const matchesPrefix = (fullPath, prefixes) =>
  prefixes.some((prefix) => fullPath === prefix || fullPath.startsWith(`${prefix}/`));

const inferOfflinePolicy = (method, fullPath) => {
  if (matchesPrefix(fullPath, NO_STORE_PREFIXES)) {
    return 'no-store';
  }

  if (LIST_METHODS.has(method) && matchesPrefix(fullPath, SAFE_LIST_SYNC_PREFIXES)) {
    return 'sync';
  }

  if (LIST_METHODS.has(method)) {
    return 'revalidate';
  }

  return 'no-store';
};

const requestSchemaFor = (moduleKey, localPath, method, fullPath) => {
  if (!MUTATION_METHODS.includes(method)) {
    return null;
  }

  const overrideGroup = REQUEST_SCHEMA_OVERRIDES[moduleKey];
  if (overrideGroup && overrideGroup[localPath] && overrideGroup[localPath][method]) {
    return overrideGroup[localPath][method];
  }

  if (/\/upload$/i.test(fullPath)) {
    return 'UploadRequest';
  }

  if (moduleKey === 'auth') {
    return 'AuthActionRequest';
  }

  return 'GenericMutationRequest';
};

const responseSchemaFor = (moduleKey, method, fullPath, localPath) => {
  if (fullPath === '/health' || fullPath === '/ready' || fullPath === '/live') {
    return 'HealthStatus';
  }

  if (/\/download$/i.test(fullPath) || /\/preview$/i.test(fullPath)) {
    return 'BinaryPayload';
  }

  if (method === 'delete') {
    return null;
  }

  if (moduleKey === 'auth' && localPath === '/me') {
    return 'AuthContext';
  }

  const override = FAMILY_SCHEMA_OVERRIDES[moduleKey];
  return override || 'GenericRecord';
};

const buildListOperationSummary = (moduleKey) => `List ${titleCase(moduleKey)}`;
const buildCreateOperationSummary = (moduleKey) => `Create ${titleCase(singularize(moduleKey))}`;
const buildGetOperationSummary = (moduleKey) => `Get ${titleCase(singularize(moduleKey))}`;
const buildUpdateOperationSummary = (moduleKey) => `Update ${titleCase(singularize(moduleKey))}`;
const buildDeleteOperationSummary = (moduleKey) => `Delete ${titleCase(singularize(moduleKey))}`;

const buildActionSummary = (method, moduleKey, localPath) => {
  const segments = localPath.split('/').filter(Boolean);
  const visibleSegments = segments.filter((segment) => !segment.startsWith(':'));
  const lastSegment = visibleSegments[visibleSegments.length - 1];
  const joined = titleCase(visibleSegments.join(' '));

  if (!lastSegment) {
    if (method === 'get') return buildListOperationSummary(moduleKey);
    if (method === 'post') return buildCreateOperationSummary(moduleKey);
    if (method === 'put' || method === 'patch') return buildUpdateOperationSummary(moduleKey);
    if (method === 'delete') return buildDeleteOperationSummary(moduleKey);
  }

  if (method === 'get') {
    if (segments.length === 1 && !segments[0].startsWith(':')) {
      return `Get ${joined}`;
    }

    return `Get ${joined} for ${titleCase(singularize(moduleKey))}`;
  }

  if (method === 'post') {
    return `${titleCase(lastSegment)} ${titleCase(singularize(moduleKey))}`;
  }

  if (method === 'put' || method === 'patch') {
    return `${titleCase(lastSegment)} ${titleCase(singularize(moduleKey))}`;
  }

  if (method === 'delete') {
    return `Delete ${joined} for ${titleCase(singularize(moduleKey))}`;
  }

  return `${method.toUpperCase()} ${joined}`;
};

const buildSummary = (method, moduleKey, localPath) => {
  if (localPath === '/') {
    if (method === 'get') return buildListOperationSummary(moduleKey);
    if (method === 'post') return buildCreateOperationSummary(moduleKey);
  }

  if (localPath === '/:id') {
    if (method === 'get') return buildGetOperationSummary(moduleKey);
    if (method === 'put' || method === 'patch') return buildUpdateOperationSummary(moduleKey);
    if (method === 'delete') return buildDeleteOperationSummary(moduleKey);
  }

  return buildActionSummary(method, moduleKey, localPath);
};

const makeHeaderParameterRef = (name) => ({ $ref: `#/components/parameters/${name}` });

const pathParametersFor = (fullPath) =>
  unique(Array.from(fullPath.matchAll(/\{(\w+)\}/g)).map((match) => match[1])).map((name) => ({
    name,
    in: 'path',
    required: true,
    description: `${titleCase(name)} identifier.`,
    schema: {
      type: 'string',
    },
  }));

const responseHeadersFor = (offlinePolicy) => {
  const headers = {
    'Cache-Control': { $ref: '#/components/headers/CacheControl' },
    'X-Offline-Policy': { $ref: '#/components/headers/XOfflinePolicy' },
  };

  if (offlinePolicy === 'revalidate' || offlinePolicy === 'sync') {
    headers.ETag = { $ref: '#/components/headers/ETag' };
    headers['Last-Modified'] = { $ref: '#/components/headers/LastModified' };
  }

  return headers;
};

const buildSuccessResponse = (schemaName, offlinePolicy, fullPath, method) => {
  if (schemaName === 'BinaryPayload') {
    return {
      description: 'Binary or stream response.',
      headers: responseHeadersFor(offlinePolicy),
      content: {
        'application/octet-stream': {
          schema: {
            type: 'string',
            format: 'binary',
          },
        },
      },
    };
  }

  const isList = method === 'get' && !/\{[^}]+\}/.test(fullPath);
  const contentSchema = isList
    ? {
        allOf: [
          { $ref: '#/components/schemas/PaginatedEnvelope' },
          {
            properties: {
              data: {
                type: 'array',
                items: { $ref: `#/components/schemas/${schemaName}` },
              },
            },
          },
        ],
      }
    : {
        allOf: [
          { $ref: '#/components/schemas/ResourceEnvelope' },
          {
            properties: {
              data: { $ref: `#/components/schemas/${schemaName}` },
            },
          },
        ],
      };

  return {
    description: 'Successful response envelope.',
    headers: responseHeadersFor(offlinePolicy),
    content: {
      'application/json': {
        schema: contentSchema,
      },
    },
  };
};

const buildErrorResponses = (method, fullPath, requireConditional) => {
  const responses = {
    401: { $ref: '#/components/responses/UnauthorizedProblem' },
    403: { $ref: '#/components/responses/ForbiddenProblem' },
    422: { $ref: '#/components/responses/ValidationProblem' },
    500: { $ref: '#/components/responses/InternalProblem' },
  };

  if (/\{[^}]+\}/.test(fullPath)) {
    responses[404] = { $ref: '#/components/responses/NotFoundProblem' };
  }

  if (requireConditional) {
    responses[409] = { $ref: '#/components/responses/ConflictProblem' };
    responses[428] = { $ref: '#/components/responses/PreconditionProblem' };
  }

  if (method === 'post' || method === 'put' || method === 'patch') {
    responses[409] = responses[409] || { $ref: '#/components/responses/ConflictProblem' };
  }

  return responses;
};

const securityRequirementsFor = (moduleKey) => {
  if (moduleKey === 'public') {
    return [];
  }

  if (API_KEY_AUTH_ROUTE_FAMILIES.has(moduleKey)) {
    return [{ BearerAuth: [] }, { ApiKeyAuth: [] }];
  }

  return [{ BearerAuth: [] }];
};

const makeOperation = (moduleEntry, operation) => {
  const { mountPath, moduleKey } = moduleEntry;
  const method = operation.method;
  const fullPath = normalizeOpenApiPath(`/api/v1${mountPath}${operation.localPath === '/' ? '' : operation.localPath}`);
  const offlinePolicy = inferOfflinePolicy(method, fullPath);
  const requestSchema = requestSchemaFor(moduleKey, operation.localPath, method, fullPath);
  const responseSchema = responseSchemaFor(moduleKey, method, fullPath, operation.localPath);
  const requireConditional = matchesPrefix(fullPath, CONDITIONAL_MUTATION_PREFIXES) && MUTATION_METHODS.includes(method);
  const allowIdempotency = !matchesPrefix(fullPath, IDEMPOTENCY_DISABLED_PREFIXES) && MUTATION_METHODS.includes(method);
  const parameters = [];

  parameters.push(makeHeaderParameterRef('AcceptLanguage'));

  if (method === 'get') {
    parameters.push(makeHeaderParameterRef('IfNoneMatch'));
    parameters.push(makeHeaderParameterRef('IfModifiedSince'));

    if (!/\{[^}]+\}/.test(fullPath)) {
      parameters.push(makeHeaderParameterRef('Page'));
      parameters.push(makeHeaderParameterRef('Limit'));
      parameters.push(makeHeaderParameterRef('SortBy'));
      parameters.push(makeHeaderParameterRef('Order'));
      parameters.push(makeHeaderParameterRef('Since'));
      parameters.push(makeHeaderParameterRef('Search'));
    }
  }

  if (allowIdempotency && (method === 'post' || method === 'patch')) {
    parameters.push(makeHeaderParameterRef('IdempotencyKey'));
  }

  if (requireConditional) {
    parameters.push(makeHeaderParameterRef('IfMatch'));
    parameters.push(makeHeaderParameterRef('XResourceVersion'));
  }

  parameters.push(...pathParametersFor(fullPath));

  const responses = {
    ...(method === 'delete'
      ? {
          204: {
            description: 'Resource deleted or soft-deleted successfully.',
            headers: responseHeadersFor(offlinePolicy),
          },
        }
      : {
          [method === 'post' && operation.localPath === '/' ? 201 : 200]: buildSuccessResponse(
            responseSchema,
            offlinePolicy,
            fullPath,
            method
          ),
        }),
    ...buildErrorResponses(method, fullPath, requireConditional),
  };

  const familyEvents = FAMILY_EVENT_MAP[moduleKey];
  const descriptionLines = [
    FAMILY_DESCRIPTIONS[moduleKey] || `Operations for the ${titleCase(moduleKey)} route family.`,
    `Offline policy: \`${offlinePolicy}\`.`,
  ];

  if (familyEvents && familyEvents.length) {
    descriptionLines.push(`WebSocket events: ${familyEvents.join(', ')}.`);
  }

  const operationObject = {
    tags: [titleCase(moduleKey)],
    summary: buildSummary(method, moduleKey, operation.localPath),
    description: descriptionLines.join('\n\n'),
    operationId: toOperationId(method, fullPath),
    security: securityRequirementsFor(moduleKey),
    parameters,
    responses,
    'x-route-family': moduleKey,
    'x-offline-policy': offlinePolicy,
    'x-route-source': moduleEntry.routeFile,
  };

  if (familyEvents && familyEvents.length) {
    operationObject['x-websocket-events'] = familyEvents;
  }

  if (requestSchema) {
    operationObject.requestBody = {
      required: method !== 'patch',
      content: {
        [requestSchema === 'UploadRequest' ? 'multipart/form-data' : 'application/json']: {
          schema: { $ref: `#/components/schemas/${requestSchema}` },
        },
      },
    };
  }

  return {
    fullPath,
    method,
    operationObject,
  };
};

const buildSchemas = () => ({
  ProblemDetails: {
    type: 'object',
    required: ['type', 'title', 'status'],
    properties: {
      type: { type: 'string', format: 'uri-reference' },
      title: { type: 'string' },
      status: { type: 'integer', format: 'int32' },
      detail: { type: 'string' },
      instance: { type: 'string', format: 'uri-reference' },
      errors: {
        type: 'array',
        items: {
          type: 'object',
          additionalProperties: true,
        },
      },
      request_id: { type: 'string' },
      locale: { type: 'string' },
    },
    additionalProperties: true,
  },
  Meta: {
    type: 'object',
    properties: {
      locale: { type: 'string', example: 'en' },
      direction: { type: 'string', example: 'ltr' },
      timestamp: { type: 'string', format: 'date-time' },
    },
    additionalProperties: true,
  },
  Pagination: {
    type: 'object',
    properties: {
      page: { type: 'integer', minimum: 1 },
      limit: { type: 'integer', minimum: 1 },
      total: { type: 'integer', minimum: 0 },
      hasNextPage: { type: 'boolean' },
      hasPrevPage: { type: 'boolean' },
    },
    additionalProperties: true,
  },
  SyncMetadata: {
    type: 'object',
    properties: {
      sync_token: { type: 'string' },
      has_more: { type: 'boolean' },
      timestamp: { type: 'string', format: 'date-time' },
    },
    additionalProperties: true,
  },
  ResourceEnvelope: {
    type: 'object',
    properties: {
      success: { type: 'boolean', default: true },
      message: { type: 'string' },
      data: {
        type: 'object',
        additionalProperties: true,
      },
      meta: { $ref: '#/components/schemas/Meta' },
    },
    additionalProperties: true,
  },
  PaginatedEnvelope: {
    type: 'object',
    properties: {
      success: { type: 'boolean', default: true },
      message: { type: 'string' },
      data: {
        type: 'array',
        items: {
          type: 'object',
          additionalProperties: true,
        },
      },
      pagination: { $ref: '#/components/schemas/Pagination' },
      sync: { $ref: '#/components/schemas/SyncMetadata' },
      meta: { $ref: '#/components/schemas/Meta' },
    },
    additionalProperties: true,
  },
  GenericRecord: {
    type: 'object',
    properties: {
      id: { type: 'string' },
      tenant_id: { type: 'string', nullable: true },
      facility_id: { type: 'string', nullable: true },
      branch_id: { type: 'string', nullable: true },
      version: { type: 'integer', nullable: true },
      etag: { type: 'string', nullable: true },
      created_at: { type: 'string', format: 'date-time', nullable: true },
      updated_at: { type: 'string', format: 'date-time', nullable: true },
      deleted_at: { type: 'string', format: 'date-time', nullable: true },
    },
    additionalProperties: true,
  },
  GenericMutationRequest: {
    type: 'object',
    additionalProperties: true,
  },
  AuthActionRequest: {
    type: 'object',
    description: 'Generic auth request payload. Concrete auth flows validate route-specific fields in runtime schemas.',
    additionalProperties: true,
  },
  AuthContext: {
    type: 'object',
    properties: {
      user: { type: 'object', additionalProperties: true },
      roles: { type: 'array', items: { type: 'string' } },
      permissions: { type: 'array', items: { type: 'string' } },
    },
    additionalProperties: true,
  },
  HealthStatus: {
    type: 'object',
    properties: {
      status: { type: 'string' },
      service: { type: 'string' },
      uptime: { type: 'number' },
      timestamp: { type: 'string', format: 'date-time' },
      checks: {
        type: 'object',
        additionalProperties: true,
      },
    },
    additionalProperties: true,
  },
  BinaryPayload: {
    type: 'string',
    format: 'binary',
  },
  JsonObject: {
    type: 'object',
    additionalProperties: true,
  },
  JsonValue: {
    nullable: true,
    oneOf: [
      { type: 'object', additionalProperties: true },
      { type: 'array', items: {} },
      { type: 'string' },
      { type: 'number' },
      { type: 'integer' },
      { type: 'boolean' },
    ],
  },
  UploadRequest: {
    type: 'object',
    properties: {
      files: {
        type: 'array',
        items: {
          type: 'string',
          format: 'binary',
        },
      },
      notes: { type: 'string' },
    },
    additionalProperties: true,
  },
  ApprovalNoteRequest: {
    type: 'object',
    properties: {
      notes: { type: 'string', nullable: true },
    },
    additionalProperties: false,
  },
  AcceptanceNoteRequest: {
    type: 'object',
    properties: {
      accepted_notes: { type: 'string', nullable: true },
    },
    additionalProperties: false,
  },
  AbacPolicy: {
    allOf: [
      { $ref: '#/components/schemas/GenericRecord' },
      {
        type: 'object',
        properties: {
          name: { type: 'string' },
          description: { type: 'string', nullable: true },
          resource_type: { type: 'string' },
          action: { type: 'string' },
          effect: { type: 'string', enum: ['ALLOW', 'DENY'] },
          priority: { type: 'integer' },
          subject_conditions_json: { $ref: '#/components/schemas/JsonObject' },
          object_conditions_json: { $ref: '#/components/schemas/JsonObject' },
          environment_conditions_json: { $ref: '#/components/schemas/JsonObject' },
          reason_template: { type: 'string', nullable: true },
          is_active: { type: 'boolean' },
        },
      },
    ],
  },
  AbacPolicyWriteRequest: {
    type: 'object',
    required: ['name', 'resource_type', 'action', 'effect'],
    properties: {
      tenant_id: { type: 'string' },
      facility_id: { type: 'string', nullable: true },
      branch_id: { type: 'string', nullable: true },
      department_id: { type: 'string', nullable: true },
      name: { type: 'string' },
      description: { type: 'string', nullable: true },
      resource_type: { type: 'string' },
      action: { type: 'string' },
      effect: { type: 'string', enum: ['ALLOW', 'DENY'] },
      priority: { type: 'integer', minimum: 0, maximum: 100000 },
      subject_conditions_json: { $ref: '#/components/schemas/JsonObject' },
      object_conditions_json: { $ref: '#/components/schemas/JsonObject' },
      environment_conditions_json: { $ref: '#/components/schemas/JsonObject' },
      reason_template: { type: 'string', nullable: true },
      is_active: { type: 'boolean' },
    },
    additionalProperties: false,
  },
  BreakGlassAccess: {
    allOf: [
      { $ref: '#/components/schemas/GenericRecord' },
      {
        type: 'object',
        properties: {
          patient_id: { type: 'string', nullable: true },
          requested_by_user_id: { type: 'string', nullable: true },
          reviewed_by_user_id: { type: 'string', nullable: true },
          target_resource_type: { type: 'string' },
          target_resource_id: { type: 'string', nullable: true },
          reason: { type: 'string' },
          justification_json: { $ref: '#/components/schemas/JsonObject' },
          requested_scope_json: { $ref: '#/components/schemas/JsonObject' },
          status: { type: 'string', enum: ['REQUESTED', 'ACTIVE', 'REJECTED', 'EXPIRED', 'REVOKED'] },
          review_status: { type: 'string', enum: ['PENDING', 'APPROVED', 'REJECTED', 'ESCALATED'] },
          starts_at: { type: 'string', format: 'date-time', nullable: true },
          expires_at: { type: 'string', format: 'date-time', nullable: true },
          revoked_at: { type: 'string', format: 'date-time', nullable: true },
        },
      },
    ],
  },
  BreakGlassAccessRequest: {
    type: 'object',
    required: ['target_resource_type', 'reason'],
    properties: {
      tenant_id: { type: 'string' },
      facility_id: { type: 'string', nullable: true },
      branch_id: { type: 'string', nullable: true },
      patient_id: { type: 'string', nullable: true },
      target_resource_type: { type: 'string' },
      target_resource_id: { type: 'string', nullable: true },
      reason: { type: 'string' },
      justification_json: { $ref: '#/components/schemas/JsonObject' },
      requested_scope_json: { $ref: '#/components/schemas/JsonObject' },
      starts_at: { type: 'string', format: 'date-time', nullable: true },
      expires_at: { type: 'string', format: 'date-time', nullable: true },
      etag: { type: 'string', nullable: true },
    },
    additionalProperties: false,
  },
  BreakGlassAccessRevokeRequest: {
    type: 'object',
    properties: {
      revoke_reason: { type: 'string', nullable: true },
    },
    additionalProperties: false,
  },
  BreakGlassReview: {
    allOf: [
      { $ref: '#/components/schemas/GenericRecord' },
      {
        type: 'object',
        properties: {
          break_glass_access_id: { type: 'string' },
          reviewer_user_id: { type: 'string', nullable: true },
          status: { type: 'string', enum: ['APPROVED', 'REJECTED', 'ESCALATED'] },
          notes: { type: 'string', nullable: true },
          expires_at: { type: 'string', format: 'date-time', nullable: true },
        },
      },
    ],
  },
  BreakGlassReviewWriteRequest: {
    type: 'object',
    required: ['break_glass_access_id', 'status'],
    properties: {
      break_glass_access_id: { type: 'string' },
      status: { type: 'string', enum: ['APPROVED', 'REJECTED', 'ESCALATED'] },
      notes: { type: 'string', nullable: true },
      expires_at: { type: 'string', format: 'date-time', nullable: true },
    },
    additionalProperties: false,
  },
  OfficeContext: {
    allOf: [
      { $ref: '#/components/schemas/GenericRecord' },
      {
        type: 'object',
        properties: {
          shift_id: { type: 'string' },
          current_holder_user_id: { type: 'string', nullable: true },
          office_date: { type: 'string', nullable: true },
          handover_due_at: { type: 'string', format: 'date-time', nullable: true },
          notes: { type: 'string', nullable: true },
          metadata_json: { $ref: '#/components/schemas/JsonObject' },
          status: { type: 'string', enum: ['OPEN', 'HANDOVER_PENDING', 'CLOSED'] },
        },
      },
    ],
  },
  OfficeContextWriteRequest: {
    type: 'object',
    required: ['shift_id'],
    properties: {
      tenant_id: { type: 'string' },
      facility_id: { type: 'string', nullable: true },
      branch_id: { type: 'string', nullable: true },
      shift_id: { type: 'string' },
      current_holder_user_id: { type: 'string', nullable: true },
      office_date: { type: 'string', nullable: true },
      handover_due_at: { type: 'string', format: 'date-time', nullable: true },
      notes: { type: 'string', nullable: true },
      metadata_json: { $ref: '#/components/schemas/JsonObject' },
    },
    additionalProperties: false,
  },
  OfficeContextUpdateRequest: {
    type: 'object',
    properties: {
      current_holder_user_id: { type: 'string', nullable: true },
      office_date: { type: 'string', nullable: true },
      handover_due_at: { type: 'string', format: 'date-time', nullable: true },
      notes: { type: 'string', nullable: true },
      metadata_json: { $ref: '#/components/schemas/JsonObject' },
      status: { type: 'string', enum: ['OPEN', 'HANDOVER_PENDING'] },
    },
    additionalProperties: false,
  },
  OfficeContextCloseRequest: {
    type: 'object',
    properties: {
      notes: { type: 'string', nullable: true },
    },
    additionalProperties: false,
  },
  ShiftClose: {
    allOf: [
      { $ref: '#/components/schemas/GenericRecord' },
      {
        type: 'object',
        properties: {
          office_context_id: { type: 'string', nullable: true },
          shift_id: { type: 'string', nullable: true },
          closed_by_user_id: { type: 'string', nullable: true },
          approved_by_user_id: { type: 'string', nullable: true },
          totals_json: { $ref: '#/components/schemas/JsonObject' },
          reconciliation_json: { $ref: '#/components/schemas/JsonObject' },
          expected_amount: { type: 'string', nullable: true },
          actual_amount: { type: 'string', nullable: true },
          variance_amount: { type: 'string', nullable: true },
          notes: { type: 'string', nullable: true },
          evidence_json: { $ref: '#/components/schemas/JsonObject' },
          status: { type: 'string', enum: ['DRAFT', 'SUBMITTED', 'APPROVED'] },
        },
      },
    ],
  },
  ShiftCloseWriteRequest: {
    type: 'object',
    properties: {
      tenant_id: { type: 'string' },
      facility_id: { type: 'string', nullable: true },
      branch_id: { type: 'string', nullable: true },
      office_context_id: { type: 'string' },
      shift_id: { type: 'string' },
      totals_json: { $ref: '#/components/schemas/JsonObject' },
      reconciliation_json: { $ref: '#/components/schemas/JsonObject' },
      expected_amount: { type: 'string', nullable: true },
      actual_amount: { type: 'string', nullable: true },
      notes: { type: 'string', nullable: true },
      evidence_json: { $ref: '#/components/schemas/JsonObject' },
      submit: { type: 'boolean' },
      status: { type: 'string', enum: ['DRAFT', 'SUBMITTED'] },
    },
    additionalProperties: false,
  },
  DayClose: {
    allOf: [
      { $ref: '#/components/schemas/GenericRecord' },
      {
        type: 'object',
        properties: {
          office_context_id: { type: 'string', nullable: true },
          submitted_by_user_id: { type: 'string', nullable: true },
          approved_by_user_id: { type: 'string', nullable: true },
          checklist_json: { $ref: '#/components/schemas/JsonObject' },
          blockers_json: { $ref: '#/components/schemas/JsonValue' },
          unresolved_items_json: { $ref: '#/components/schemas/JsonValue' },
          notes: { type: 'string', nullable: true },
          evidence_json: { $ref: '#/components/schemas/JsonObject' },
          status: { type: 'string', enum: ['DRAFT', 'SUBMITTED', 'APPROVED'] },
        },
      },
    ],
  },
  DayCloseWriteRequest: {
    type: 'object',
    properties: {
      tenant_id: { type: 'string' },
      facility_id: { type: 'string', nullable: true },
      branch_id: { type: 'string', nullable: true },
      office_context_id: { type: 'string' },
      checklist_json: { $ref: '#/components/schemas/JsonObject' },
      blockers_json: { $ref: '#/components/schemas/JsonValue' },
      unresolved_items_json: { $ref: '#/components/schemas/JsonValue' },
      notes: { type: 'string', nullable: true },
      evidence_json: { $ref: '#/components/schemas/JsonObject' },
      submit: { type: 'boolean' },
      status: { type: 'string', enum: ['DRAFT', 'SUBMITTED'] },
    },
    additionalProperties: false,
  },
  DayCloseApprovalRequest: {
    type: 'object',
    properties: {
      blockers_json: { $ref: '#/components/schemas/JsonValue' },
      notes: { type: 'string', nullable: true },
    },
    additionalProperties: false,
  },
  Handover: {
    allOf: [
      { $ref: '#/components/schemas/GenericRecord' },
      {
        type: 'object',
        properties: {
          office_context_id: { type: 'string', nullable: true },
          from_user_id: { type: 'string', nullable: true },
          to_user_id: { type: 'string' },
          items_json: { $ref: '#/components/schemas/JsonValue' },
          signoff_notes: { type: 'string', nullable: true },
          accepted_notes: { type: 'string', nullable: true },
          status: { type: 'string', enum: ['PENDING', 'ACCEPTED', 'REJECTED'] },
        },
      },
    ],
  },
  HandoverWriteRequest: {
    type: 'object',
    required: ['to_user_id'],
    properties: {
      tenant_id: { type: 'string' },
      facility_id: { type: 'string', nullable: true },
      branch_id: { type: 'string', nullable: true },
      office_context_id: { type: 'string' },
      from_user_id: { type: 'string' },
      to_user_id: { type: 'string' },
      items_json: { $ref: '#/components/schemas/JsonValue' },
      signoff_notes: { type: 'string', nullable: true },
    },
    additionalProperties: false,
  },
  HandoverUpdateRequest: {
    type: 'object',
    properties: {
      to_user_id: { type: 'string' },
      items_json: { $ref: '#/components/schemas/JsonValue' },
      signoff_notes: { type: 'string', nullable: true },
    },
    additionalProperties: false,
  },
  CustodySnapshot: {
    allOf: [
      { $ref: '#/components/schemas/GenericRecord' },
      {
        type: 'object',
        properties: {
          office_context_id: { type: 'string', nullable: true },
          captured_by_user_id: { type: 'string', nullable: true },
          asset_snapshot_json: { $ref: '#/components/schemas/JsonValue' },
          cash_drawer_snapshot_json: { $ref: '#/components/schemas/JsonValue' },
          controlled_items_json: { $ref: '#/components/schemas/JsonValue' },
          notes: { type: 'string', nullable: true },
          status: { type: 'string', enum: ['DRAFT', 'FINALIZED'] },
        },
      },
    ],
  },
  CustodySnapshotWriteRequest: {
    type: 'object',
    properties: {
      tenant_id: { type: 'string' },
      facility_id: { type: 'string', nullable: true },
      branch_id: { type: 'string', nullable: true },
      office_context_id: { type: 'string' },
      asset_snapshot_json: { $ref: '#/components/schemas/JsonValue' },
      cash_drawer_snapshot_json: { $ref: '#/components/schemas/JsonValue' },
      controlled_items_json: { $ref: '#/components/schemas/JsonValue' },
      notes: { type: 'string', nullable: true },
    },
    additionalProperties: false,
  },
  CustodySnapshotFinalizeRequest: {
    type: 'object',
    properties: {
      asset_snapshot_json: { $ref: '#/components/schemas/JsonValue' },
      cash_drawer_snapshot_json: { $ref: '#/components/schemas/JsonValue' },
      controlled_items_json: { $ref: '#/components/schemas/JsonValue' },
      notes: { type: 'string', nullable: true },
    },
    additionalProperties: false,
  },
  CloseoutPack: {
    allOf: [
      { $ref: '#/components/schemas/GenericRecord' },
      {
        type: 'object',
        properties: {
          office_context_id: { type: 'string', nullable: true },
          shift_close_id: { type: 'string', nullable: true },
          day_close_id: { type: 'string', nullable: true },
          handover_id: { type: 'string', nullable: true },
          custody_snapshot_id: { type: 'string', nullable: true },
          generated_by_user_id: { type: 'string', nullable: true },
          status: { type: 'string', enum: ['QUEUED', 'PROCESSING', 'READY', 'FAILED'] },
          format: { type: 'string', enum: ['PDF', 'CSV', 'JSON', 'XLSX'] },
          storage_key: { type: 'string', nullable: true },
          download_url: { type: 'string', nullable: true },
        },
      },
    ],
  },
  CloseoutPackWriteRequest: {
    type: 'object',
    properties: {
      tenant_id: { type: 'string' },
      facility_id: { type: 'string', nullable: true },
      branch_id: { type: 'string', nullable: true },
      office_context_id: { type: 'string' },
      shift_close_id: { type: 'string', nullable: true },
      day_close_id: { type: 'string', nullable: true },
      handover_id: { type: 'string', nullable: true },
      custody_snapshot_id: { type: 'string', nullable: true },
      format: { type: 'string', enum: ['PDF', 'CSV', 'JSON', 'XLSX'] },
      parameter_overrides_json: { $ref: '#/components/schemas/JsonObject' },
    },
    additionalProperties: false,
  },
});

const buildComponents = () => ({
  securitySchemes: {
    BearerAuth: {
      type: 'http',
      scheme: 'bearer',
      bearerFormat: 'JWT',
      description: 'JWT bearer token issued by the HMS auth module.',
    },
    ApiKeyAuth: {
      type: 'apiKey',
      in: 'header',
      name: 'x-api-key',
      description: 'Tenant-scoped API key for integration-facing HMS routes.',
    },
  },
  headers: {
    ETag: {
      description: 'Entity tag used for conditional GET and replay-safe caching.',
      schema: { type: 'string' },
    },
    LastModified: {
      description: 'RFC 7231 last modified timestamp for conditional requests.',
      schema: { type: 'string', format: 'date-time' },
    },
    CacheControl: {
      description: 'Cache classification emitted by the offline middleware.',
      schema: { type: 'string' },
    },
    XOfflinePolicy: {
      description: 'Resolved offline/cache policy for the route family.',
      schema: {
        type: 'string',
        enum: ['no-store', 'revalidate', 'sync'],
      },
    },
  },
  parameters: {
    AcceptLanguage: {
      name: 'Accept-Language',
      in: 'header',
      description: 'Preferred locale. Runtime currently resolves all supported requests to the `en` backend locale, with `en-GB` mapped explicitly to `en`.',
      schema: { type: 'string', example: 'en-GB' },
    },
    IfNoneMatch: {
      name: 'If-None-Match',
      in: 'header',
      description: 'Conditional GET validator.',
      schema: { type: 'string' },
    },
    IfModifiedSince: {
      name: 'If-Modified-Since',
      in: 'header',
      description: 'Conditional GET timestamp validator.',
      schema: { type: 'string', format: 'date-time' },
    },
    IfMatch: {
      name: 'If-Match',
      in: 'header',
      description: 'Required for conditional mutations on selected safety-critical resources.',
      schema: { type: 'string' },
    },
    XResourceVersion: {
      name: 'X-Resource-Version',
      in: 'header',
      description: 'Optional explicit resource version header validated alongside `If-Match` for safety-critical mutations.',
      schema: { type: 'string' },
    },
    IdempotencyKey: {
      name: 'Idempotency-Key',
      in: 'header',
      description: 'Replay-safe key for supported mutation requests.',
      schema: { type: 'string' },
    },
    Page: {
      name: 'page',
      in: 'query',
      description: 'Pagination page number.',
      schema: { type: 'integer', minimum: 1, default: 1 },
    },
    Limit: {
      name: 'limit',
      in: 'query',
      description: 'Pagination size.',
      schema: { type: 'integer', minimum: 1, maximum: 200, default: 20 },
    },
    SortBy: {
      name: 'sort_by',
      in: 'query',
      description: 'Sort field selector.',
      schema: { type: 'string' },
    },
    Order: {
      name: 'order',
      in: 'query',
      description: 'Sort order.',
      schema: { type: 'string', enum: ['asc', 'desc'], default: 'desc' },
    },
    Since: {
      name: 'since',
      in: 'query',
      description: 'Incremental sync cursor timestamp for route families with offline sync support.',
      schema: { type: 'string', format: 'date-time' },
    },
    Search: {
      name: 'search',
      in: 'query',
      description: 'Text search query used by modules that expose search-capable list endpoints.',
      schema: { type: 'string' },
    },
  },
  responses: {
    UnauthorizedProblem: {
      description: 'Authentication is required or the token is invalid.',
      content: {
        'application/problem+json': {
          schema: { $ref: '#/components/schemas/ProblemDetails' },
        },
      },
    },
    ForbiddenProblem: {
      description: 'The caller is authenticated but not authorized for the requested action.',
      content: {
        'application/problem+json': {
          schema: { $ref: '#/components/schemas/ProblemDetails' },
        },
      },
    },
    NotFoundProblem: {
      description: 'The requested resource was not found.',
      content: {
        'application/problem+json': {
          schema: { $ref: '#/components/schemas/ProblemDetails' },
        },
      },
    },
    ConflictProblem: {
      description: 'The request conflicts with current server state or a duplicate uniqueness constraint.',
      content: {
        'application/problem+json': {
          schema: { $ref: '#/components/schemas/ProblemDetails' },
        },
      },
    },
    PreconditionProblem: {
      description: 'A required conditional mutation header is missing or inconsistent.',
      content: {
        'application/problem+json': {
          schema: { $ref: '#/components/schemas/ProblemDetails' },
        },
      },
    },
    ValidationProblem: {
      description: 'Validation failed for path, query, header, or body input.',
      content: {
        'application/problem+json': {
          schema: { $ref: '#/components/schemas/ProblemDetails' },
        },
      },
    },
    InternalProblem: {
      description: 'Unexpected server failure.',
      content: {
        'application/problem+json': {
          schema: { $ref: '#/components/schemas/ProblemDetails' },
        },
      },
    },
  },
  schemas: buildSchemas(),
});

const buildSpecification = () => {
  const mountedRoutes = parseMountedRoutes();
  const paths = {};

  HEALTH_ENDPOINTS.forEach((endpoint) => {
    paths[endpoint.path] = {
      [endpoint.method]: {
        tags: ['System'],
        summary: endpoint.summary,
        description: endpoint.description,
        operationId: toOperationId(endpoint.method, endpoint.path),
        security: [],
        responses: {
          200: buildSuccessResponse('HealthStatus', 'no-store', endpoint.path, endpoint.method),
          503: { $ref: '#/components/responses/InternalProblem' },
        },
        'x-offline-policy': 'no-store',
      },
    };
  });

  mountedRoutes.forEach((moduleEntry) => {
    moduleEntry.operations.forEach((operation) => {
      const generated = makeOperation(moduleEntry, operation);
      paths[generated.fullPath] = paths[generated.fullPath] || {};
      paths[generated.fullPath][generated.method] = generated.operationObject;
    });
  });

  const tags = [
    {
      name: 'System',
      description: 'Root-level health and readiness endpoints.',
    },
    ...mountedRoutes.map((moduleEntry) => ({
      name: titleCase(moduleEntry.moduleKey),
      description:
        FAMILY_DESCRIPTIONS[moduleEntry.moduleKey] ||
        `Operations for the ${titleCase(moduleEntry.moduleKey)} route family mounted in the versioned router.`,
    })),
  ].sort((left, right) => left.name.localeCompare(right.name));

  return {
    openapi: '3.0.3',
    info: {
      title: 'HMS Backend API',
      version: '1.0.0',
      description: [
        'Generated contract for the live Express + Prisma modular monolith under `/api/v1`.',
        'This spec is built from mounted route families in `src/app/router.js` and standardizes documented error responses on RFC 9457 `application/problem+json`.',
        'The document includes the new ABAC, break-glass, and Last Office families together with offline/cache semantics and websocket-linked operational families.',
      ].join('\n\n'),
    },
    servers: [
      {
        url: '/',
        description: 'Relative server root for the deployed HMS backend.',
      },
    ],
    tags,
    paths,
    components: buildComponents(),
    'x-generated-at': new Date().toISOString(),
    'x-generated-from': {
      router: path.relative(ROOT_DIR, ROUTER_PATH).replace(/\\/g, '/'),
      mounted_family_count: mountedRoutes.length,
      mounted_families: mountedRoutes.map((entry) => ({
        path: `/api/v1${entry.mountPath}`,
        module: entry.moduleKey,
        route_file: entry.routeFile,
        operations: entry.operations.length,
      })),
    },
    'x-offline-policy-families': {
      no_store: NO_STORE_PREFIXES,
      sync: SAFE_LIST_SYNC_PREFIXES,
      conditional_mutation: CONDITIONAL_MUTATION_PREFIXES,
      idempotency_disabled: IDEMPOTENCY_DISABLED_PREFIXES,
    },
    'x-read-only-route-families': Array.from(READ_ONLY_FAMILIES),
  };
};

const writeSpec = () => {
  const spec = buildSpecification();
  const yamlText = yaml.dump(spec, {
    noRefs: true,
    lineWidth: -1,
    sortKeys: false,
  });

  fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true });
  fs.writeFileSync(OUTPUT_PATH, yamlText);

  console.log(`[openapi] generated ${OUTPUT_PATH}`);
  console.log(`[openapi] documented ${Object.keys(spec.paths).length} paths`);
};

writeSpec();
