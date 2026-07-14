const patientReportService = require('@services/patient-report/patient-report.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess } = require('@lib/response');

const listSections = asyncHandler(async (req, res) => {
  const result = await patientReportService.listSections(
    req.query,
    patientReportService.buildContext(req)
  );
  sendSuccess(res, 200, 'messages.patient_report.sections.success', result);
});

const createJob = asyncHandler(async (req, res) => {
  const result = await patientReportService.createJob(
    req.body,
    patientReportService.buildContext(req)
  );
  const statusCode = result.status === 'QUEUED' || result.status === 'PROCESSING' ? 202 : 201;
  sendSuccess(res, statusCode, 'messages.patient_report.job.create.success', result);
});

const getJobById = asyncHandler(async (req, res) => {
  const result = await patientReportService.getJobById(
    req.params.id,
    patientReportService.buildContext(req)
  );
  sendSuccess(res, 200, 'messages.patient_report.job.get.success', result);
});

const downloadJob = asyncHandler(async (req, res) => {
  const result = await patientReportService.downloadJob(
    req.params.id,
    patientReportService.buildContext(req)
  );
  res.setHeader('Content-Type', result.mime_type);
  res.setHeader(
    'Content-Disposition',
    `attachment; filename="${result.file_name}"`
  );
  res.status(200).send(result.buffer);
});

const recordPrintEvent = asyncHandler(async (req, res) => {
  const result = await patientReportService.recordPrintEvent(
    req.body,
    patientReportService.buildContext(req)
  );
  sendSuccess(res, 201, 'messages.patient_report.print.success', result);
});

module.exports = {
  createJob,
  downloadJob,
  getJobById,
  listSections,
  recordPrintEvent,
};
