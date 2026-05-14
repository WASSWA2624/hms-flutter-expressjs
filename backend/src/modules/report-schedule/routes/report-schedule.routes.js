const express = require('express');
const reportScheduleController = require('@controllers/report-schedule/report-schedule.controller');
const { PERMISSIONS } = require('@config/permissions');
const { authenticate, authorize } = require('@middlewares/auth.middleware');
const { validateRequest } = require('@middlewares/validate.middleware');
const {
  createReportScheduleSchema,
  listReportSchedulesQuerySchema,
  reportScheduleIdParamsSchema,
  updateReportScheduleSchema,
} = require('@validations/report-schedule/report-schedule.schema');

const router = express.Router();

router.get(
  '/',
  validateRequest({ query: listReportSchedulesQuerySchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  reportScheduleController.listReportSchedules
);

router.get(
  '/:id',
  validateRequest({ params: reportScheduleIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_READ, 'permission'),
  reportScheduleController.getReportScheduleById
);

router.post(
  '/',
  validateRequest({ body: createReportScheduleSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  reportScheduleController.createReportSchedule
);

router.put(
  '/:id',
  validateRequest({ params: reportScheduleIdParamsSchema, body: updateReportScheduleSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  reportScheduleController.updateReportSchedule
);

router.post(
  '/:id/pause',
  validateRequest({ params: reportScheduleIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  reportScheduleController.pauseReportSchedule
);

router.post(
  '/:id/resume',
  validateRequest({ params: reportScheduleIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_WRITE, 'permission'),
  reportScheduleController.resumeReportSchedule
);

router.delete(
  '/:id',
  validateRequest({ params: reportScheduleIdParamsSchema }),
  authenticate(),
  authorize(PERMISSIONS.REPORTS_DELETE, 'permission'),
  reportScheduleController.deleteReportSchedule
);

module.exports = router;
