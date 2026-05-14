jest.mock('@prisma/client', () => ({
  report_definition: {
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
} = require('@repositories/report-definition/report-definition.repository');

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

describe('Report Definition Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('loads a report definition with the current include shape', async () => {
      const mockReportDefinition = {
        id: 'report-123',
        human_friendly_id: 'RD-001',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'Monthly Report',
        dataset_key: 'patient_registrations',
        created_by: 'user-123',
        tenant: { id: 'tenant-123', human_friendly_id: 'TEN-001', name: 'Test Tenant' },
        facility: { id: 'facility-123', human_friendly_id: 'FAC-001', name: 'Test Facility' },
        creator: { id: 'user-123', human_friendly_id: 'USR-001', email: 'test@example.com' },
        schedules: [],
        runs: [],
        _count: { schedules: 0 },
      };
      prisma.report_definition.findFirst.mockResolvedValue(mockReportDefinition);

      const result = await findById('report-123');

      expect(result).toEqual(mockReportDefinition);
      expect(prisma.report_definition.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'report-123',
          deleted_at: null,
        },
        include: expect.objectContaining({
          tenant: {
            select: { id: true, human_friendly_id: true, name: true },
          },
          facility: {
            select: { id: true, human_friendly_id: true, name: true },
          },
          creator: {
            select: { id: true, human_friendly_id: true, email: true },
          },
          schedules: expect.any(Object),
          runs: expect.any(Object),
          _count: expect.any(Object),
        }),
      });
    });

    it('returns null when the report definition does not exist', async () => {
      prisma.report_definition.findFirst.mockResolvedValue(null);

      const result = await findById('report-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.report_definition.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('report-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('uses the object-based query contract for list calls', async () => {
      const mockReportDefinitions = [
        { id: 'report-1', name: 'Report 1', tenant_id: 'tenant-123' },
        { id: 'report-2', name: 'Report 2', tenant_id: 'tenant-123' },
      ];
      prisma.report_definition.findMany.mockResolvedValue(mockReportDefinitions);

      const result = await findMany({
        where: { tenant_id: 'tenant-123' },
        skip: 10,
        take: 5,
        orderBy: { name: 'asc' },
      });

      expect(result).toEqual(mockReportDefinitions);
      expect(prisma.report_definition.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
        },
        skip: 10,
        take: 5,
        orderBy: { name: 'asc' },
        include: expect.objectContaining({
          tenant: expect.any(Object),
          facility: expect.any(Object),
          creator: expect.any(Object),
          schedules: expect.any(Object),
          runs: expect.any(Object),
          _count: expect.any(Object),
        }),
      });
    });

    it('counts with the deleted-at guard preserved', async () => {
      prisma.report_definition.count.mockResolvedValue(2);

      const result = await count({ tenant_id: 'tenant-123' });

      expect(result).toBe(2);
      expect(prisma.report_definition.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
        },
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.report_definition.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('creates using the enriched include shape', async () => {
      const newData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        name: 'New Report',
        dataset_key: 'patient_registrations',
        created_by: 'user-123',
      };
      const mockCreated = { id: 'report-123', ...newData };
      prisma.report_definition.create.mockResolvedValue(mockCreated);

      const result = await create(newData);

      expect(result).toEqual(mockCreated);
      expect(prisma.report_definition.create).toHaveBeenCalledWith({
        data: newData,
        include: expect.objectContaining({
          tenant: expect.any(Object),
          facility: expect.any(Object),
          creator: expect.any(Object),
          schedules: expect.any(Object),
          runs: expect.any(Object),
          _count: expect.any(Object),
        }),
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = {
        code: 'P2002',
        meta: { target: ['name'] }
      };
      prisma.report_definition.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = {
        code: 'P2003',
        meta: { field_name: 'tenant_id' }
      };
      prisma.report_definition.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('updates using the enriched include shape', async () => {
      const updateData = { name: 'Updated Report' };
      const mockUpdated = { id: 'report-123', name: 'Updated Report' };
      prisma.report_definition.update.mockResolvedValue(mockUpdated);

      const result = await update('report-123', updateData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.report_definition.update).toHaveBeenCalledWith({
        where: { id: 'report-123' },
        data: updateData,
        include: expect.objectContaining({
          tenant: expect.any(Object),
          facility: expect.any(Object),
          creator: expect.any(Object),
          schedules: expect.any(Object),
          runs: expect.any(Object),
          _count: expect.any(Object),
        }),
      });
    });

    it('should throw HttpError if report definition not found', async () => {
      const error = { code: 'P2025' };
      prisma.report_definition.update.mockRejectedValue(error);

      await expect(update('report-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete report definition', async () => {
      const mockDeleted = { id: 'report-123', deleted_at: new Date() };
      prisma.report_definition.update.mockResolvedValue(mockDeleted);

      const result = await softDelete('report-123');

      expect(result).toEqual(mockDeleted);
      expect(prisma.report_definition.update).toHaveBeenCalledWith({
        where: { id: 'report-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if report definition not found', async () => {
      const error = { code: 'P2025' };
      prisma.report_definition.update.mockRejectedValue(error);

      await expect(softDelete('report-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
