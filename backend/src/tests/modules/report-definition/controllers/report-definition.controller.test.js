jest.mock('@services/report-definition/report-definition.service');
jest.mock('@lib/response');

const reportDefinitionService = require('@services/report-definition/report-definition.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listReportDefinitions,
  getReportDefinitionById,
  createReportDefinition,
  updateReportDefinition,
  deleteReportDefinition
} = require('@controllers/report-definition/report-definition.controller');

describe('Report Definition Controller', () => {
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
    mockRes = {};
  });

  describe('listReportDefinitions', () => {
    it('passes scoped list inputs to the service', async () => {
      const mockResult = {
        reportDefinitions: [
          { id: 'report-1', name: 'Report 1' },
          { id: 'report-2', name: 'Report 2' },
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
      mockReq.query = {
        page: '1',
        limit: '20',
        status: 'ACTIVE',
        search: 'Admissions',
      };
      reportDefinitionService.listReportDefinitions.mockResolvedValue(mockResult);

      await listReportDefinitions(mockReq, mockRes);

      expect(reportDefinitionService.listReportDefinitions).toHaveBeenCalledWith(
        { status: 'ACTIVE', search: 'Admissions' },
        1,
        20,
        undefined,
        undefined,
        mockReq.user
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.report_definition.list_success',
        mockResult.reportDefinitions,
        mockResult.pagination
      );
    });
  });

  describe('getReportDefinitionById', () => {
    it('passes req.user when loading a single record', async () => {
      const mockReportDefinition = {
        id: 'report-123',
        name: 'Test Report',
      };
      mockReq.params.id = 'report-123';
      reportDefinitionService.getReportDefinitionById.mockResolvedValue(mockReportDefinition);

      await getReportDefinitionById(mockReq, mockRes);

      expect(reportDefinitionService.getReportDefinitionById).toHaveBeenCalledWith(
        'report-123',
        mockReq.user
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.report_definition.get_success',
        mockReportDefinition
      );
    });
  });

  describe('createReportDefinition', () => {
    it('builds mutation context from the authenticated user', async () => {
      const newData = {
        name: 'New Report',
        dataset_key: 'patient_registrations',
        definition_json: { columns: ['date'] },
      };
      const mockCreated = { id: 'report-123', ...newData };
      mockReq.body = newData;
      reportDefinitionService.createReportDefinition.mockResolvedValue(mockCreated);

      await createReportDefinition(mockReq, mockRes);

      expect(reportDefinitionService.createReportDefinition).toHaveBeenCalledWith(
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
        'messages.report_definition.create_success',
        mockCreated
      );
    });
  });

  describe('updateReportDefinition', () => {
    it('passes the current request context into updates', async () => {
      const updateData = { name: 'Updated Report', version: 1 };
      const mockUpdated = {
        id: 'report-123',
        name: 'Updated Report',
      };
      mockReq.params.id = 'report-123';
      mockReq.body = updateData;
      reportDefinitionService.updateReportDefinition.mockResolvedValue(mockUpdated);

      await updateReportDefinition(mockReq, mockRes);

      expect(reportDefinitionService.updateReportDefinition).toHaveBeenCalledWith(
        'report-123',
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
        'messages.report_definition.update_success',
        mockUpdated
      );
    });
  });

  describe('deleteReportDefinition', () => {
    it('passes the current request context into deletes', async () => {
      mockReq.params.id = 'report-123';
      reportDefinitionService.deleteReportDefinition.mockResolvedValue();

      await deleteReportDefinition(mockReq, mockRes);

      expect(reportDefinitionService.deleteReportDefinition).toHaveBeenCalledWith(
        'report-123',
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
