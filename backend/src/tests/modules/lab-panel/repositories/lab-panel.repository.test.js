/**
 * Lab panel repository tests
 *
 * @module tests/modules/lab-panel/repositories
 * @description Tests for lab panel repository operations
 * Per testing.mdc: All repositories must be tested with mocked Prisma
 */

const labPanelRepository = require('@repositories/lab-panel/lab-panel.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  lab_panel: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Lab Panel Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find lab panel by ID successfully', async () => {
      const mockLabPanel = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        tenant_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Complete Metabolic Panel',
        code: 'CMP',
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };

      prisma.lab_panel.findFirst.mockResolvedValue(mockLabPanel);

      const result = await labPanelRepository.findById('123e4567-e89b-12d3-a456-426614174000');

      expect(result).toEqual(mockLabPanel);
      expect(prisma.lab_panel.findFirst).toHaveBeenCalledWith({
        where: {
          id: '123e4567-e89b-12d3-a456-426614174000',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null when lab panel not found', async () => {
      prisma.lab_panel.findFirst.mockResolvedValue(null);

      const result = await labPanelRepository.findById('123e4567-e89b-12d3-a456-426614174000');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_panel.findFirst.mockRejectedValue(new Error('Database error'));

      await expect(labPanelRepository.findById('123e4567-e89b-12d3-a456-426614174000'))
        .rejects.toThrow(HttpError);
    });

    it('should include relations when specified', async () => {
      const mockLabPanel = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Metabolic Panel'
      };

      prisma.lab_panel.findFirst.mockResolvedValue(mockLabPanel);

      await labPanelRepository.findById('123e4567-e89b-12d3-a456-426614174000', { tenant: true });

      expect(prisma.lab_panel.findFirst).toHaveBeenCalledWith({
        where: {
          id: '123e4567-e89b-12d3-a456-426614174000',
          deleted_at: null
        },
        include: { tenant: true }
      });
    });
  });

  describe('findMany', () => {
    it('should find many lab panels successfully', async () => {
      const mockLabPanels = [
        {
          id: '123e4567-e89b-12d3-a456-426614174000',
          name: 'Complete Metabolic Panel',
          deleted_at: null
        },
        {
          id: '123e4567-e89b-12d3-a456-426614174001',
          name: 'Basic Metabolic Panel',
          deleted_at: null
        }
      ];

      prisma.lab_panel.findMany.mockResolvedValue(mockLabPanels);

      const result = await labPanelRepository.findMany();

      expect(result).toEqual(mockLabPanels);
      expect(prisma.lab_panel.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters correctly', async () => {
      prisma.lab_panel.findMany.mockResolvedValue([]);

      await labPanelRepository.findMany({ tenant_id: '123e4567-e89b-12d3-a456-426614174000' });

      expect(prisma.lab_panel.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: '123e4567-e89b-12d3-a456-426614174000'
        },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply pagination correctly', async () => {
      prisma.lab_panel.findMany.mockResolvedValue([]);

      await labPanelRepository.findMany({}, 10, 5);

      expect(prisma.lab_panel.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 10,
        take: 5,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply custom order by', async () => {
      prisma.lab_panel.findMany.mockResolvedValue([]);

      await labPanelRepository.findMany({}, 0, 20, { name: 'asc' });

      expect(prisma.lab_panel.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { name: 'asc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_panel.findMany.mockRejectedValue(new Error('Database error'));

      await expect(labPanelRepository.findMany())
        .rejects.toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count lab panels successfully', async () => {
      prisma.lab_panel.count.mockResolvedValue(10);

      const result = await labPanelRepository.count();

      expect(result).toBe(10);
      expect(prisma.lab_panel.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should apply filters when counting', async () => {
      prisma.lab_panel.count.mockResolvedValue(5);

      await labPanelRepository.count({ tenant_id: '123e4567-e89b-12d3-a456-426614174000' });

      expect(prisma.lab_panel.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: '123e4567-e89b-12d3-a456-426614174000'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_panel.count.mockRejectedValue(new Error('Database error'));

      await expect(labPanelRepository.count())
        .rejects.toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create lab panel successfully', async () => {
      const newLabPanel = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Complete Metabolic Panel',
        code: 'CMP'
      };

      const createdLabPanel = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        ...newLabPanel,
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 1
      };

      prisma.lab_panel.create.mockResolvedValue(createdLabPanel);

      const result = await labPanelRepository.create(newLabPanel);

      expect(result).toEqual(createdLabPanel);
      expect(prisma.lab_panel.create).toHaveBeenCalledWith({
        data: newLabPanel
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['code'] };

      prisma.lab_panel.create.mockRejectedValue(error);

      await expect(labPanelRepository.create({ name: 'Test' }))
        .rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };

      prisma.lab_panel.create.mockRejectedValue(error);

      await expect(labPanelRepository.create({ name: 'Test' }))
        .rejects.toThrow(HttpError);
    });

    it('should throw HttpError on generic database error', async () => {
      prisma.lab_panel.create.mockRejectedValue(new Error('Database error'));

      await expect(labPanelRepository.create({ name: 'Test' }))
        .rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update lab panel successfully', async () => {
      const updateData = {
        name: 'Updated Lab Panel'
      };

      const updatedLabPanel = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        tenant_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Updated Lab Panel',
        code: 'CMP',
        created_at: new Date(),
        updated_at: new Date(),
        deleted_at: null,
        version: 2
      };

      prisma.lab_panel.update.mockResolvedValue(updatedLabPanel);

      const result = await labPanelRepository.update('123e4567-e89b-12d3-a456-426614174000', updateData);

      expect(result).toEqual(updatedLabPanel);
      expect(prisma.lab_panel.update).toHaveBeenCalledWith({
        where: { id: '123e4567-e89b-12d3-a456-426614174000' },
        data: updateData
      });
    });

    it('should throw HttpError when lab panel not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.lab_panel.update.mockRejectedValue(error);

      await expect(labPanelRepository.update('123e4567-e89b-12d3-a456-426614174000', { name: 'Test' }))
        .rejects.toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['code'] };

      prisma.lab_panel.update.mockRejectedValue(error);

      await expect(labPanelRepository.update('123e4567-e89b-12d3-a456-426614174000', { name: 'Test' }))
        .rejects.toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };

      prisma.lab_panel.update.mockRejectedValue(error);

      await expect(labPanelRepository.update('123e4567-e89b-12d3-a456-426614174000', { name: 'Test' }))
        .rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete lab panel successfully', async () => {
      const deletedLabPanel = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Metabolic Panel',
        deleted_at: new Date()
      };

      prisma.lab_panel.update.mockResolvedValue(deletedLabPanel);

      const result = await labPanelRepository.softDelete('123e4567-e89b-12d3-a456-426614174000');

      expect(result).toEqual(deletedLabPanel);
      expect(prisma.lab_panel.update).toHaveBeenCalledWith({
        where: { id: '123e4567-e89b-12d3-a456-426614174000' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError when lab panel not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';

      prisma.lab_panel.update.mockRejectedValue(error);

      await expect(labPanelRepository.softDelete('123e4567-e89b-12d3-a456-426614174000'))
        .rejects.toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.lab_panel.update.mockRejectedValue(new Error('Database error'));

      await expect(labPanelRepository.softDelete('123e4567-e89b-12d3-a456-426614174000'))
        .rejects.toThrow(HttpError);
    });
  });
});
