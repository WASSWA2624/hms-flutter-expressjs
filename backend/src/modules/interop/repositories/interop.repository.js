/**
 * Interop repository
 *
 * Read-only data shaping helpers for interoperability actions.
 */

const buildFhirExportPayload = (resource) => {
  return {
    format: 'FHIR',
    resource,
    exported_at: new Date().toISOString(),
    total_records: 0,
    records: []
  };
};

const buildFhirImportResult = (resource, records = [], mode = 'merge') => {
  return {
    format: 'FHIR',
    resource,
    imported_at: new Date().toISOString(),
    mode,
    accepted_records: Array.isArray(records) ? records.length : 0,
    rejected_records: 0
  };
};

const buildHl7Result = () => {
  return {
    accepted: true,
    received_at: new Date().toISOString(),
    ack_id: `ACK-${Date.now()}`
  };
};

const buildDicomLinkResult = (studyId, payload) => {
  return {
    study_id: studyId,
    linked: true,
    linked_at: new Date().toISOString(),
    study_uid: payload.study_uid,
    pacs_url: payload.pacs_url || null
  };
};

const buildMigrationExportPayload = () => {
  return {
    format: 'HMS_MIGRATION_BUNDLE',
    exported_at: new Date().toISOString(),
    version: '1.0.0',
    entities: []
  };
};

const buildMigrationImportResult = (mode = 'append') => {
  return {
    imported: true,
    imported_at: new Date().toISOString(),
    mode
  };
};

module.exports = {
  buildFhirExportPayload,
  buildFhirImportResult,
  buildHl7Result,
  buildDicomLinkResult,
  buildMigrationExportPayload,
  buildMigrationImportResult
};
