/**
 * Interop controller
 */

const interopService = require('@services/interop/interop.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');

const exportFhirResource = asyncHandler(async (req, res) => {
  const { resource } = req.params;
  const payload = await interopService.exportFhirResource(resource);
  sendSuccess(res, 200, 'messages.interop.fhir_export.success', payload);
});

const importFhirResource = asyncHandler(async (req, res) => {
  const { resource } = req.params;
  const payload = await interopService.importFhirResource(resource, req.body, {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  });
  sendSuccess(res, 200, 'messages.interop.fhir_import.success', payload);
});

const submitHl7Message = asyncHandler(async (req, res) => {
  const payload = await interopService.submitHl7Message(req.body, {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  });
  sendSuccess(res, 200, 'messages.interop.hl7_message.success', payload);
});

const linkDicomStudy = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const payload = await interopService.linkDicomStudy(id, req.body, {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  });
  sendSuccess(res, 200, 'messages.interop.dicom_link.success', payload);
});

const exportMigrations = asyncHandler(async (req, res) => {
  const payload = await interopService.exportMigrations();
  sendSuccess(res, 200, 'messages.interop.migration_export.success', payload);
});

const importMigrations = asyncHandler(async (req, res) => {
  const payload = await interopService.importMigrations(req.body, {
    user_id: req.user?.id,
    tenant_id: req.user?.tenant_id,
    ip_address: req.ip
  });
  sendSuccess(res, 200, 'messages.interop.migration_import.success', payload);
});

module.exports = {
  exportFhirResource,
  importFhirResource,
  submitHl7Message,
  linkDicomStudy,
  exportMigrations,
  importMigrations
};
