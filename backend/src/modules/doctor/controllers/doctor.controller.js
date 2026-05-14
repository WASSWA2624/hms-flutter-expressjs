/**
 * Doctor orchestration controller
 *
 * @module modules/doctor/controllers
 */

const doctorService = require('@services/doctor/doctor.service');
const { asyncHandler } = require('@lib/async');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { DEFAULT_PAGE, DEFAULT_PAGE_LIMIT } = require('@config/constants');

const listDoctors = asyncHandler(async (req, res) => {
  const {
    tenant_id,
    facility_id,
    practitioner_type,
    position_title,
    search,
    page = DEFAULT_PAGE,
    limit = DEFAULT_PAGE_LIMIT,
    sort_by = 'created_at',
    order = 'desc',
  } = req.query;

  const result = await doctorService.listDoctors(
    {
      tenant_id,
      facility_id,
      practitioner_type,
      position_title,
      search,
    },
    Number(page),
    Number(limit),
    sort_by,
    order
  );

  return sendPaginated(res, 'messages.doctor.list.success', result.doctors, result.pagination);
});

const getDoctorById = asyncHandler(async (req, res) => {
  const doctor = await doctorService.getDoctorById(req.params.id);
  return sendSuccess(res, 200, 'messages.doctor.get.success', doctor);
});

const createDoctor = asyncHandler(async (req, res) => {
  const payload = {
    ...req.body,
    tenant_id: req.body.tenant_id || req.user?.tenant_id,
    facility_id: req.body.facility_id !== undefined ? req.body.facility_id : null,
  };

  const doctor = await doctorService.createDoctor(payload, req.user?.id, req.ip);
  return sendSuccess(res, 201, 'messages.doctor.create.success', doctor);
});

const updateDoctor = asyncHandler(async (req, res) => {
  const doctor = await doctorService.updateDoctor(req.params.id, req.body, req.user?.id, req.ip);
  return sendSuccess(res, 200, 'messages.doctor.update.success', doctor);
});

module.exports = {
  listDoctors,
  getDoctorById,
  createDoctor,
  updateDoctor,
};
