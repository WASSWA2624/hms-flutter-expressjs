jest.mock('@services/report-run/report-run.service');
jest.mock('@lib/response');

const reportRunService = require('@services/report-run/report-run.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  cancelReportRun,
  listReportRuns,
  getReportRunById,
  createReportRun,
  downloadReportRun,
  updateReportRun,
  deleteReportRun,
} = require('@controllers/report-run/report-run.controller');

describe('Report Run Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = {
      params: {},
      query: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
      },
      ip: '127.0.0.1',
      get: jest.fn().mockReturnValue('Test Agent'),
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      send: jest.fn(),
      setHeader: jest.fn(),
    };
  });

  describe('listReportRuns', () => {
    it('passes list filters and req.user to the service', async () => {
      const mockResult = {
        reportRuns: [
          { id: 'run-1', status: 'COMPLETED' },
          { id: 'run-2', status: 'PENDING' },
        ],
        pagination: {
          page: 1,
          limit: 20,
          total: 2,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false,
        },
      };
      mockReq.query = { page: '1', limit: '20', status: 'FAILED', format: 'PDF' };
      reportRunService.listReportRuns.mockResolvedValue(mockResult);

      await listReportRuns(mockReq, mockRes);

      expect(reportRunService.listReportRuns).toHaveBeenCalledWith(
        { status: 'FAILED', format: 'PDF' },
        1,
        20,
        undefined,
        undefined,
        mockReq.user
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.report_run.list_success',
        mockResult.reportRuns,
        mockResult.pagination
      );
    });
  });

  describe('getReportRunById', () => {
    it('passes req.user when loading a single run', async () => {
      const mockReportRun = {
        id: 'run-123',
        status: 'COMPLETED',
      };
      mockReq.params.id = 'run-123';
      reportRunService.getReportRunById.mockResolvedValue(mockReportRun);

      await getReportRunById(mockReq, mockRes);

      expect(reportRunService.getReportRunById).toHaveBeenCalledWith(
        'run-123',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.report_run.get_success',
        mockReportRun
      );
    });
  });

  describe('createReportRun', () => {
    it('builds mutation context from the authenticated user', async () => {
      const newData = {
        report_definition_id: 'report-def-123',
        format: 'PDF',
      };
      const mockCreated = { id: 'run-123', ...newData };
      mockReq.body = newData;
      reportRunService.createReportRun.mockResolvedValue(mockCreated);

      await createReportRun(mockReq, mockRes);

      expect(reportRunService.createReportRun).toHaveBeenCalledWith(
        newData,
        {
          user: mockReq.user,
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '127.0.0.1',
          user_agent: 'Test Agent',
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.report_run.create_success',
        mockCreated
      );
    });
  });

  describe('updateReportRun', () => {
    it('passes the current request context into updates', async () => {
      const updateData = { status: 'COMPLETED', version: 1 };
      const mockUpdated = {
        id: 'run-123',
        status: 'COMPLETED',
      };
      mockReq.params.id = 'run-123';
      mockReq.body = updateData;
      reportRunService.updateReportRun.mockResolvedValue(mockUpdated);

      await updateReportRun(mockReq, mockRes);

      expect(reportRunService.updateReportRun).toHaveBeenCalledWith(
        'run-123',
        updateData,
        {
          user: mockReq.user,
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '127.0.0.1',
          user_agent: 'Test Agent',
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.report_run.update_success',
        mockUpdated
      );
    });
  });

  describe('cancelReportRun', () => {
    it('passes the current request context into cancels', async () => {
      const mockCancelled = { id: 'run-123', status: 'CANCELLED' };
      mockReq.params.id = 'run-123';
      reportRunService.cancelReportRunById.mockResolvedValue(mockCancelled);

      await cancelReportRun(mockReq, mockRes);

      expect(reportRunService.cancelReportRunById).toHaveBeenCalledWith(
        'run-123',
        expect.objectContaining({
          user: mockReq.user,
          user_id: 'user-123',
        })
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.report_run.update_success',
        mockCancelled
      );
    });
  });

  describe('downloadReportRun', () => {
    it('writes file headers and body for downloads', async () => {
      const payload = {
        buffer: Buffer.from('file'),
        file_name: 'report.pdf',
        mime_type: 'application/pdf',
      };
      mockReq.params.id = 'run-123';
      reportRunService.downloadReportRun.mockResolvedValue(payload);

      await downloadReportRun(mockReq, mockRes);

      expect(reportRunService.downloadReportRun).toHaveBeenCalledWith(
        'run-123',
        expect.objectContaining({
          user: mockReq.user,
          user_id: 'user-123',
        })
      );
      expect(mockRes.setHeader).toHaveBeenCalledWith('Content-Type', 'application/pdf');
      expect(mockRes.setHeader).toHaveBeenCalledWith(
        'Content-Disposition',
        'attachment; filename="report.pdf"'
      );
      expect(mockRes.status).toHaveBeenCalledWith(200);
      expect(mockRes.send).toHaveBeenCalledWith(payload.buffer);
    });
  });

  describe('deleteReportRun', () => {
    it('passes the current request context into deletes', async () => {
      mockReq.params.id = 'run-123';
      reportRunService.deleteReportRun.mockResolvedValue();

      await deleteReportRun(mockReq, mockRes);

      expect(reportRunService.deleteReportRun).toHaveBeenCalledWith(
        'run-123',
        {
          user: mockReq.user,
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '127.0.0.1',
          user_agent: 'Test Agent',
        }
      );
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
