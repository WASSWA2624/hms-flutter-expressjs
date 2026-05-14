/**
 * Housekeeping task controller tests
 *
 * @module tests/modules/housekeeping-task/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies before requiring the controller
jest.mock('@services/housekeeping-task/housekeeping-task.service');
jest.mock('@lib/response');

const housekeepingTaskService = require('@services/housekeeping-task/housekeeping-task.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listHousekeepingTasks,
  getHousekeepingTaskById,
  createHousekeepingTask,
  updateHousekeepingTask,
  deleteHousekeepingTask
} = require('@controllers/housekeeping-task/housekeeping-task.controller');

describe('Housekeeping Task Controller', () => {
  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123', tenant_id: 'tenant-123', facility_id: 'facility-123' },
      ip: '127.0.0.1',
      get: jest.fn().mockReturnValue('test-agent')
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn()
    };
  });

  describe('listHousekeepingTasks', () => {
    it('should list housekeeping tasks with pagination', async () => {
      const mockResult = {
        housekeepingTasks: [{ id: 'task-1' }, { id: 'task-2' }],
        pagination: { page: 1, limit: 20, total: 2 }
      };
      housekeepingTaskService.listHousekeepingTasks.mockResolvedValue(mockResult);

      mockReq.query = { page: 1, limit: 20 };

      await listHousekeepingTasks(mockReq, mockRes);

      expect(housekeepingTaskService.listHousekeepingTasks).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.housekeeping_task.list.success',
        mockResult.housekeepingTasks,
        mockResult.pagination
      );
    });
  });

  describe('getHousekeepingTaskById', () => {
    it('should get housekeeping task by ID', async () => {
      const mockTask = { id: 'task-123', status: 'PENDING' };
      housekeepingTaskService.getHousekeepingTaskById.mockResolvedValue(mockTask);

      mockReq.params = { id: 'task-123' };

      await getHousekeepingTaskById(mockReq, mockRes);

      expect(housekeepingTaskService.getHousekeepingTaskById).toHaveBeenCalledWith('task-123', expect.any(Object));
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.housekeeping_task.get.success',
        mockTask
      );
    });
  });

  describe('createHousekeepingTask', () => {
    it('should create housekeeping task', async () => {
      const taskData = { status: 'PENDING' };
      const mockTask = { id: 'task-123', ...taskData };
      housekeepingTaskService.createHousekeepingTask.mockResolvedValue(mockTask);

      mockReq.body = taskData;

      await createHousekeepingTask(mockReq, mockRes);

      expect(housekeepingTaskService.createHousekeepingTask).toHaveBeenCalledWith(
        taskData,
        expect.objectContaining({
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '127.0.0.1',
          user_agent: 'test-agent'
        })
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.housekeeping_task.create.success',
        mockTask
      );
    });
  });

  describe('updateHousekeepingTask', () => {
    it('should update housekeeping task', async () => {
      const updateData = { status: 'COMPLETED' };
      const mockTask = { id: 'task-123', ...updateData };
      housekeepingTaskService.updateHousekeepingTask.mockResolvedValue(mockTask);

      mockReq.params = { id: 'task-123' };
      mockReq.body = updateData;

      await updateHousekeepingTask(mockReq, mockRes);

      expect(housekeepingTaskService.updateHousekeepingTask).toHaveBeenCalledWith(
        'task-123',
        updateData,
        expect.objectContaining({
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '127.0.0.1',
          user_agent: 'test-agent'
        })
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.housekeeping_task.update.success',
        mockTask
      );
    });
  });

  describe('deleteHousekeepingTask', () => {
    it('should delete housekeeping task', async () => {
      housekeepingTaskService.deleteHousekeepingTask.mockResolvedValue();

      mockReq.params = { id: 'task-123' };

      await deleteHousekeepingTask(mockReq, mockRes);

      expect(housekeepingTaskService.deleteHousekeepingTask).toHaveBeenCalledWith(
        'task-123',
        expect.objectContaining({
          user_id: 'user-123',
          tenant_id: 'tenant-123',
          facility_id: 'facility-123',
          ip_address: '127.0.0.1',
          user_agent: 'test-agent'
        })
      );
      expect(sendNoContent).toHaveBeenCalledWith(mockRes);
    });
  });
});
