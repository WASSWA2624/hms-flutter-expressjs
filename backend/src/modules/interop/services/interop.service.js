/**
 * Interop service
 */

const interopRepository = require('@repositories/interop/interop.repository');
const { createAuditLog } = require('@lib/audit');
const dicomWebClient = require('@lib/dicomweb/client');

const exportFhirResource = async (resource) => {
  return interopRepository.buildFhirExportPayload(resource);
};

const importFhirResource = async (resource, data = {}, context = {}) => {
  const result = interopRepository.buildFhirImportResult(resource, data.records, data.mode || 'merge');

  await createAuditLog({
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    action: 'FHIR_IMPORT',
    entity: 'interop',
    entity_id: resource,
    diff: {
      metadata: {
        source_system: data.source_system || null,
        mode: result.mode,
        accepted_records: result.accepted_records
      }
    },
    ip_address: context.ip_address
  }).catch(() => {});

  return result;
};

const submitHl7Message = async (data = {}, context = {}) => {
  const result = interopRepository.buildHl7Result();

  await createAuditLog({
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    action: 'HL7_MESSAGE_RECEIVED',
    entity: 'interop',
    entity_id: result.ack_id,
    diff: {
      metadata: {
        source_system: data.source_system || null,
        message_length: data.message ? data.message.length : 0
      }
    },
    ip_address: context.ip_address
  }).catch(() => {});

  return result;
};

const linkDicomStudy = async (id, data = {}, context = {}) => {
  let dicomResult = null;
  let status = 'PENDING';
  let errorMessage = null;
  const targetStudyUid = data.study_uid || null;

  try {
    if (!dicomWebClient.isConfigured()) {
      throw new Error('PACS_DICOMWEB_BASE_URL is not configured');
    }

    dicomResult = await dicomWebClient.searchStudies(
      targetStudyUid ? { StudyInstanceUID: targetStudyUid } : {}
    );
    status = 'LINKED';
  } catch (error) {
    status = 'FAILED';
    errorMessage = error.message;
  }

  const result = {
    study_id: id,
    linked: status === 'LINKED',
    linked_at: new Date().toISOString(),
    study_uid: targetStudyUid,
    pacs_url: data.pacs_url || null,
    status,
    error: errorMessage,
    dicom_response: dicomResult?.data || null,
  };

  await createAuditLog({
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    action: 'DICOM_LINK',
    entity: 'interop',
    entity_id: id,
    diff: {
      metadata: {
        study_uid: data.study_uid,
        pacs_url: data.pacs_url || null,
        status,
        error: errorMessage,
        notes: data.notes || null
      }
    },
    ip_address: context.ip_address
  }).catch(() => {});

  return result;
};

const exportMigrations = async () => {
  return interopRepository.buildMigrationExportPayload();
};

const importMigrations = async (data = {}, context = {}) => {
  const result = interopRepository.buildMigrationImportResult(data.mode || 'append');

  await createAuditLog({
    user_id: context.user_id,
    tenant_id: context.tenant_id,
    action: 'MIGRATION_IMPORT',
    entity: 'interop',
    entity_id: 'migration_bundle',
    diff: {
      metadata: {
        source_system: data.source_system || null,
        mode: result.mode
      }
    },
    ip_address: context.ip_address
  }).catch(() => {});

  return result;
};

module.exports = {
  exportFhirResource,
  importFhirResource,
  submitHl7Message,
  linkDicomStudy,
  exportMigrations,
  importMigrations
};
