/**
 * Housekeeping task repository tests
 *
 * @module tests/modules/housekeeping-task/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  housekeeping_task: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/housekeeping-task/housekeeping-task.repository');

const prisma = require('@prisma/client');

describe('Housekeeping Task Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find housekeeping task by ID', async () => {
      const mockTask = {
        id: 'task-123',
        facility_id: 'facility-123',
        room_id: 'room-123',
        assigned_to_staff_id: 'staff-123',
        status: 'PENDING',
        scheduled_at: new Date('2026-01-20'),
        completed_at: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.housekeeping_task.findFirst.mockResolvedValue(mockTask);

      const result = await findById('task-123');

      expect(result).toEqual(mockTask);
      expect(prisma.housekeeping_task.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'task-123',
          deleted_at: null
        }
      });
    });

    it('should return null if housekeeping task not found', async () => {
      prisma.housekeeping_task.findFirst.mockResolvedValue(null);

      const result = await findById('task-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.housekeeping_task.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('task-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many housekeeping tasks with default pagination', async () => {
      const mockTasks = [
        {
          id: 'task-1',
          facility_id: 'facility-123',
          status: 'PENDING'
        },
        {
          id: 'task-2',
          facility_id: 'facility-123',
          status: 'IN_PROGRESS'
        }
      ];
      prisma.housekeeping_task.findMany.mockResolvedValue(mockTasks);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockTasks);
      expect(prisma.housekeeping_task.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find housekeeping tasks with filters', async () => {
      const mockTasks = [
        {
          id: 'task-1',
          facility_id: 'facility-123',
          room_id: 'room-123',
          status: 'PENDING'
        }
      ];
      prisma.housekeeping_task.findMany.mockResolvedValue(mockTasks);

      const result = await findMany({ 
        facility_id: 'facility-123', 
        room_id: 'room-123',
        status: 'PENDING'
      }, 0, 10);

      expect(result).toEqual(mockTasks);
      expect(prisma.housekeeping_task.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          facility_id: 'facility-123',
          room_id: 'room-123',
          status: 'PENDING'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find housekeeping tasks with custom sort order', async () => {
      const mockTasks = [];
      prisma.housekeeping_task.findMany.mockResolvedValue(mockTasks);

      await findMany({}, 0, 20, { scheduled_at: 'asc' });

      expect(prisma.housekeeping_task.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { scheduled_at: 'asc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.housekeeping_task.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count housekeeping tasks without filters', async () => {
      prisma.housekeeping_task.count.mockResolvedValue(10);

      const result = await count();

      expect(result).toBe(10);
      expect(prisma.housekeeping_task.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count housekeeping tasks with filters', async () => {
      prisma.housekeeping_task.count.mockResolvedValue(5);

      const result = await count({ facility_id: 'facility-123', status: 'PENDING' });

      expect(result).toBe(5);
      expect(prisma.housekeeping_task.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          facility_id: 'facility-123',
          status: 'PENDING'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.housekeeping_task.count.mockRejectedValue(new Error('DB error'));

      await expect(count())
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create a new housekeeping task', async () => {
      const taskData = {
        facility_id: 'facility-123',
        room_id: 'room-123',
        assigned_to_staff_id: 'staff-123',
        status: 'PENDING',
        scheduled_at: new Date('2026-01-20')
      };
      const mockCreatedTask = {
        id: 'task-new',
        ...taskData,
        completed_at: null,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };
      prisma.housekeeping_task.create.mockResolvedValue(mockCreatedTask);

      const result = await create(taskData);

      expect(result).toEqual(mockCreatedTask);
      expect(prisma.housekeeping_task.create).toHaveBeenCalledWith({
        data: taskData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const taskData = {
        status: 'PENDING'
      };
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.housekeeping_task.create.mockRejectedValue(error);

      await expect(create(taskData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const taskData = {
        facility_id: 'invalid-facility',
        status: 'PENDING'
      };
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'facility_id' };
      prisma.housekeeping_task.create.mockRejectedValue(error);

      await expect(create(taskData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.housekeeping_task.create.mockRejectedValue(new Error('DB error'));

      await expect(create({ status: 'PENDING' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update a housekeeping task', async () => {
      const updateData = {
        status: 'COMPLETED',
        completed_at: new Date('2026-01-20')
      };
      const mockUpdatedTask = {
        id: 'task-123',
        facility_id: 'facility-123',
        room_id: 'room-123',
        assigned_to_staff_id: 'staff-123',
        ...updateData,
        scheduled_at: new Date('2026-01-20'),
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };
      prisma.housekeeping_task.update.mockResolvedValue(mockUpdatedTask);

      const result = await update('task-123', updateData);

      expect(result).toEqual(mockUpdatedTask);
      expect(prisma.housekeeping_task.update).toHaveBeenCalledWith({
        where: { id: 'task-123' },
        data: updateData
      });
    });

    it('should throw HttpError when housekeeping task not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.housekeeping_task.update.mockRejectedValue(error);

      await expect(update('task-123', { status: 'COMPLETED' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['name'] };
      prisma.housekeeping_task.update.mockRejectedValue(error);

      await expect(update('task-123', { status: 'COMPLETED' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'facility_id' };
      prisma.housekeeping_task.update.mockRejectedValue(error);

      await expect(update('task-123', { facility_id: 'invalid-facility' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.housekeeping_task.update.mockRejectedValue(new Error('DB error'));

      await expect(update('task-123', { status: 'COMPLETED' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete a housekeeping task', async () => {
      const mockDeletedTask = {
        id: 'task-123',
        facility_id: 'facility-123',
        room_id: 'room-123',
        assigned_to_staff_id: 'staff-123',
        status: 'PENDING',
        scheduled_at: new Date('2026-01-20'),
        completed_at: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date(),
        deleted_at: new Date(),
        version: 1
      };
      prisma.housekeeping_task.update.mockResolvedValue(mockDeletedTask);

      const result = await softDelete('task-123');

      expect(result).toEqual(mockDeletedTask);
      expect(prisma.housekeeping_task.update).toHaveBeenCalledWith({
        where: { id: 'task-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when housekeeping task not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.housekeeping_task.update.mockRejectedValue(error);

      await expect(softDelete('task-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.housekeeping_task.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('task-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
