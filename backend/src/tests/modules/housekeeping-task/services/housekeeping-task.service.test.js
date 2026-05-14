/**
 * Housekeeping task service tests
 *
 * @module tests/modules/housekeeping-task/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies before requiring the service
jest.mock('@repositories/housekeeping-task/housekeeping-task.repository');
jest.mock('@lib/audit');
jest.mock('@lib/billing/identifiers', () => ({
  resolveEntityId: jest.fn(async ({ identifier }) => identifier),
  resolveIdentifierForFilter: jest.fn(async ({ value }) => value),
  resolveIdentifierForPayload: jest.fn(async ({ value }) => value),
  resolvePublicIdentifier: jest.fn((...values) => values.find(Boolean) || null)
}));

const housekeepingTaskRepository = require('@repositories/housekeeping-task/housekeeping-task.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listHousekeepingTasks,
  getHousekeepingTaskById,
  createHousekeepingTask,
  updateHousekeepingTask,
  deleteHousekeepingTask
} = require('@services/housekeeping-task/housekeeping-task.service');

describe('Housekeeping Task Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listHousekeepingTasks', () => {
    it('should list housekeeping tasks with pagination', async () => {
      const mockTasks = [
        { id: 'task-1', status: 'PENDING' },
        { id: 'task-2', status: 'IN_PROGRESS' }
      ];
      housekeepingTaskRepository.findMany.mockResolvedValue(mockTasks);
      housekeepingTaskRepository.count.mockResolvedValue(2);

      const result = await listHousekeepingTasks({}, 1, 20);

      expect(result.housekeepingTasks).toEqual([
        expect.objectContaining(mockTasks[0]),
        expect.objectContaining(mockTasks[1])
      ]);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should apply filters correctly', async () => {
      const mockTasks = [{ id: 'task-1', status: 'PENDING' }];
      housekeepingTaskRepository.findMany.mockResolvedValue(mockTasks);
      housekeepingTaskRepository.count.mockResolvedValue(1);

      await listHousekeepingTasks({ 
        facility_id: 'facility-123', 
        status: 'PENDING' 
      }, 1, 20);

      expect(housekeepingTaskRepository.findMany).toHaveBeenCalledWith(
        { facility_id: 'facility-123', status: 'PENDING' },
        0,
        20,
        { created_at: 'desc' },
        expect.any(Object)
      );
    });

    it('should calculate pagination correctly', async () => {
      housekeepingTaskRepository.findMany.mockResolvedValue([]);
      housekeepingTaskRepository.count.mockResolvedValue(100);

      const result = await listHousekeepingTasks({}, 2, 20);

      expect(result.pagination.totalPages).toBe(5);
      expect(result.pagination.hasNextPage).toBe(true);
      expect(result.pagination.hasPreviousPage).toBe(true);
    });
  });

  describe('getHousekeepingTaskById', () => {
    it('should get housekeeping task by ID', async () => {
      const mockTask = { id: 'task-123', status: 'PENDING' };
      housekeepingTaskRepository.findById.mockResolvedValue(mockTask);

      const result = await getHousekeepingTaskById('task-123');

      expect(result).toEqual(expect.objectContaining(mockTask));
      expect(housekeepingTaskRepository.findById).toHaveBeenCalledWith('task-123', expect.any(Object));
    });

    it('should throw error when housekeeping task not found', async () => {
      housekeepingTaskRepository.findById.mockResolvedValue(null);

      await expect(getHousekeepingTaskById('task-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createHousekeepingTask', () => {
    it('should create housekeeping task and audit log', async () => {
      const taskData = {
        facility_id: 'facility-123',
        status: 'PENDING'
      };
      const mockTask = { id: 'task-123', ...taskData };
      housekeepingTaskRepository.create.mockResolvedValue(mockTask);
      createAuditLog.mockResolvedValue({});

      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '127.0.0.1',
        user_agent: 'test-agent'
      };

      const result = await createHousekeepingTask(taskData, context);

      expect(result).toEqual(expect.objectContaining(mockTask));
      expect(housekeepingTaskRepository.create).toHaveBeenCalledWith(taskData, expect.any(Object));
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'HOUSEKEEPING_TASK_CREATED',
        entity: 'housekeeping_task',
        entity_id: 'task-123',
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '127.0.0.1',
        user_agent: 'test-agent',
        details: expect.any(Object)
      });
    });
  });

  describe('updateHousekeepingTask', () => {
    it('should update housekeeping task and create audit log', async () => {
      const beforeTask = { id: 'task-123', status: 'PENDING', facility_id: 'facility-123' };
      const updateData = { status: 'COMPLETED' };
      const afterTask = { id: 'task-123', status: 'COMPLETED', facility_id: 'facility-123' };
      
      housekeepingTaskRepository.findById.mockResolvedValue(beforeTask);
      housekeepingTaskRepository.update.mockResolvedValue(afterTask);
      createAuditLog.mockResolvedValue({});

      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '127.0.0.1',
        user_agent: 'test-agent'
      };

      const result = await updateHousekeepingTask('task-123', updateData, context);

      expect(result).toEqual(expect.objectContaining(afterTask));
      expect(housekeepingTaskRepository.update).toHaveBeenCalledWith('task-123', updateData, expect.any(Object));
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'HOUSEKEEPING_TASK_UPDATED',
        entity: 'housekeeping_task',
        entity_id: 'task-123',
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '127.0.0.1',
        user_agent: 'test-agent',
        details: expect.objectContaining({
          before: expect.any(Object),
          after: expect.any(Object)
        })
      });
    });

    it('should throw error when housekeeping task not found', async () => {
      housekeepingTaskRepository.findById.mockResolvedValue(null);

      await expect(updateHousekeepingTask('task-123', { status: 'COMPLETED' }, {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteHousekeepingTask', () => {
    it('should delete housekeeping task and create audit log', async () => {
      const mockTask = { id: 'task-123', status: 'PENDING', facility_id: 'facility-123' };
      housekeepingTaskRepository.findById.mockResolvedValue(mockTask);
      housekeepingTaskRepository.softDelete.mockResolvedValue(mockTask);
      createAuditLog.mockResolvedValue({});

      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '127.0.0.1',
        user_agent: 'test-agent'
      };

      await deleteHousekeepingTask('task-123', context);

      expect(housekeepingTaskRepository.softDelete).toHaveBeenCalledWith('task-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'HOUSEKEEPING_TASK_DELETED',
        entity: 'housekeeping_task',
        entity_id: 'task-123',
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '127.0.0.1',
        user_agent: 'test-agent',
        details: expect.any(Object)
      });
    });

    it('should throw error when housekeeping task not found', async () => {
      housekeepingTaskRepository.findById.mockResolvedValue(null);

      await expect(deleteHousekeepingTask('task-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });
});
