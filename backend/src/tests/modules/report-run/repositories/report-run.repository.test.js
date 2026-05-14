jest.mock('@prisma/client', () => ({
  report_run: {
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
} = require('@repositories/report-run/report-run.repository');

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

describe('Report Run Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('loads a report run with the current include shape', async () => {
      const mockReportRun = {
        id: 'run-123',
        human_friendly_id: 'RR-001',
        tenant_id: 'tenant-123',
        report_definition_id: 'report-def-123',
        format: 'PDF',
        status: 'COMPLETED',
        output_storage_path: '/reports/report-123.pdf',
        report_definition: {
          id: 'report-def-123',
          human_friendly_id: 'RD-001',
          name: 'Monthly Report',
          dataset_key: 'patient_registrations',
          default_format: 'PDF',
          facility_id: 'facility-123',
        },
        requested_by: {
          id: 'user-123',
          human_friendly_id: 'USR-001',
          email: 'test@example.com',
          profile: { first_name: 'Test' },
        },
        facility: { id: 'facility-123', human_friendly_id: 'FAC-001', name: 'Main Facility' },
        schedule: {
          id: 'schedule-123',
          human_friendly_id: 'SCH-001',
          name: 'Nightly',
          retention_days: 30,
          status: 'ACTIVE',
        },
      };
      prisma.report_run.findFirst.mockResolvedValue(mockReportRun);

      const result = await findById('run-123');

      expect(result).toEqual(mockReportRun);
      expect(prisma.report_run.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'run-123',
          deleted_at: null,
        },
        include: expect.objectContaining({
          facility: expect.any(Object),
          report_definition: expect.any(Object),
          requested_by: expect.any(Object),
          schedule: expect.any(Object),
        }),
      });
    });

    it('should return null if report run not found', async () => {
      prisma.report_run.findFirst.mockResolvedValue(null);

      const result = await findById('run-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.report_run.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('run-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('uses the object-based query contract for list calls', async () => {
      const mockReportRuns = [
        { id: 'run-1', report_definition_id: 'report-1', status: 'COMPLETED' },
        { id: 'run-2', report_definition_id: 'report-2', status: 'PENDING' },
      ];
      prisma.report_run.findMany.mockResolvedValue(mockReportRuns);

      const result = await findMany({
        where: { tenant_id: 'tenant-123', status: 'COMPLETED' },
        skip: 5,
        take: 10,
        orderBy: { queued_at: 'asc' },
      });

      expect(result).toEqual(mockReportRuns);
      expect(prisma.report_run.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          status: 'COMPLETED',
        },
        skip: 5,
        take: 10,
        orderBy: { queued_at: 'asc' },
        include: expect.objectContaining({
          facility: expect.any(Object),
          report_definition: expect.any(Object),
          requested_by: expect.any(Object),
          schedule: expect.any(Object),
        }),
      });
    });

    it('counts with the deleted-at guard preserved', async () => {
      prisma.report_run.count.mockResolvedValue(2);

      const result = await count({ status: 'FAILED' });

      expect(result).toBe(2);
      expect(prisma.report_run.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          status: 'FAILED',
        },
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.report_run.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('creates using the enriched include shape', async () => {
      const newData = {
        tenant_id: 'tenant-123',
        report_definition_id: 'report-def-123',
        format: 'PDF',
        requested_by_user_id: 'user-123',
      };
      const mockCreated = { id: 'run-123', ...newData };
      prisma.report_run.create.mockResolvedValue(mockCreated);

      const result = await create(newData);

      expect(result).toEqual(mockCreated);
      expect(prisma.report_run.create).toHaveBeenCalledWith({
        data: newData,
        include: expect.objectContaining({
          facility: expect.any(Object),
          report_definition: expect.any(Object),
          requested_by: expect.any(Object),
          schedule: expect.any(Object),
        }),
      });
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = {
        code: 'P2003',
        meta: { field_name: 'report_definition_id' }
      };
      prisma.report_run.create.mockRejectedValue(error);

      await expect(create({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('updates using the enriched include shape', async () => {
      const updateData = { status: 'COMPLETED' };
      const mockUpdated = { id: 'run-123', status: 'COMPLETED' };
      prisma.report_run.update.mockResolvedValue(mockUpdated);

      const result = await update('run-123', updateData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.report_run.update).toHaveBeenCalledWith({
        where: { id: 'run-123' },
        data: updateData,
        include: expect.objectContaining({
          facility: expect.any(Object),
          report_definition: expect.any(Object),
          requested_by: expect.any(Object),
          schedule: expect.any(Object),
        }),
      });
    });

    it('should throw HttpError if report run not found', async () => {
      const error = { code: 'P2025' };
      prisma.report_run.update.mockRejectedValue(error);

      await expect(update('run-123', {}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete report run', async () => {
      const mockDeleted = { id: 'run-123', deleted_at: new Date() };
      prisma.report_run.update.mockResolvedValue(mockDeleted);

      const result = await softDelete('run-123');

      expect(result).toEqual(mockDeleted);
      expect(prisma.report_run.update).toHaveBeenCalledWith({
        where: { id: 'run-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError if report run not found', async () => {
      const error = { code: 'P2025' };
      prisma.report_run.update.mockRejectedValue(error);

      await expect(softDelete('run-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
