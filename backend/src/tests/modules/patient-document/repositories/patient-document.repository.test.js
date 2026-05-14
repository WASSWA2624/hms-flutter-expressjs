/**
 * Patient Document repository tests
 *
 * @module tests/modules/patient-document/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  patient_document: {
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
} = require('@repositories/patient-document/patient-document.repository');

const prisma = require('@prisma/client');

describe('Patient Document Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find patient document by ID', async () => {
      const mockDocument = {
        id: 'doc-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        document_type: 'Lab Report',
        storage_key: 'documents/patient-001/lab-report.pdf',
        file_name: 'lab-report.pdf',
        content_type: 'application/pdf',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.patient_document.findFirst.mockResolvedValue(mockDocument);

      const result = await findById('doc-123');

      expect(result).toEqual(mockDocument);
      expect(prisma.patient_document.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'doc-123',
          deleted_at: null
        },
        include: {}
      });
    });

    it('should return null if patient document not found', async () => {
      prisma.patient_document.findFirst.mockResolvedValue(null);

      const result = await findById('doc-123');

      expect(result).toBeNull();
    });

    it('should find patient document with includes', async () => {
      const mockDocument = { id: 'doc-123', document_type: 'X-Ray' };
      prisma.patient_document.findFirst.mockResolvedValue(mockDocument);

      await findById('doc-123', { patient: true });

      expect(prisma.patient_document.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'doc-123',
          deleted_at: null
        },
        include: { patient: true }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.patient_document.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('doc-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many patient documents with default pagination', async () => {
      const mockDocuments = [
        {
          id: 'doc-1',
          patient_id: 'patient-123',
          document_type: 'Lab Report',
          storage_key: 'documents/lab-1.pdf'
        },
        {
          id: 'doc-2',
          patient_id: 'patient-123',
          document_type: 'X-Ray',
          storage_key: 'documents/xray-1.jpg'
        }
      ];
      prisma.patient_document.findMany.mockResolvedValue(mockDocuments);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockDocuments);
      expect(prisma.patient_document.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find patient documents with filters', async () => {
      const mockDocuments = [
        {
          id: 'doc-1',
          patient_id: 'patient-123',
          document_type: 'Lab Report'
        }
      ];
      prisma.patient_document.findMany.mockResolvedValue(mockDocuments);

      const result = await findMany({ 
        patient_id: 'patient-123', 
        document_type: 'Lab Report'
      }, 0, 10);

      expect(result).toEqual(mockDocuments);
      expect(prisma.patient_document.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          patient_id: 'patient-123',
          document_type: 'Lab Report'
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find patient documents with custom pagination', async () => {
      const mockDocuments = [];
      prisma.patient_document.findMany.mockResolvedValue(mockDocuments);

      const result = await findMany({}, 20, 50);

      expect(result).toEqual(mockDocuments);
      expect(prisma.patient_document.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 20,
        take: 50,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should find patient documents with custom order', async () => {
      const mockDocuments = [];
      prisma.patient_document.findMany.mockResolvedValue(mockDocuments);

      const result = await findMany({}, 0, 20, { document_type: 'asc' });

      expect(result).toEqual(mockDocuments);
      expect(prisma.patient_document.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { document_type: 'asc' },
        include: {}
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.patient_document.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count patient documents', async () => {
      prisma.patient_document.count.mockResolvedValue(5);

      const result = await count({});

      expect(result).toBe(5);
      expect(prisma.patient_document.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count patient documents with filters', async () => {
      prisma.patient_document.count.mockResolvedValue(2);

      const result = await count({ 
        patient_id: 'patient-123',
        document_type: 'Lab Report'
      });

      expect(result).toBe(2);
      expect(prisma.patient_document.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          patient_id: 'patient-123',
          document_type: 'Lab Report'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.patient_document.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
    it('should create new patient document', async () => {
      const newDocument = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        document_type: 'Lab Report',
        storage_key: 'documents/patient-001/lab-report.pdf',
        file_name: 'lab-report.pdf',
        content_type: 'application/pdf'
      };
      const mockCreated = {
        id: 'doc-123',
        ...newDocument,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.patient_document.create.mockResolvedValue(mockCreated);

      const result = await create(newDocument);

      expect(result).toEqual(mockCreated);
      expect(prisma.patient_document.create).toHaveBeenCalledWith({
        data: newDocument
      });
    });

    it('should throw HttpError on unique constraint violation (P2002)', async () => {
      const newDocument = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        document_type: 'Lab Report',
        storage_key: 'documents/duplicate.pdf'
      };
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['storage_key'] };
      prisma.patient_document.create.mockRejectedValue(error);

      await expect(create(newDocument))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation (P2003)', async () => {
      const newDocument = {
        tenant_id: 'tenant-123',
        patient_id: 'invalid-patient',
        document_type: 'Lab Report',
        storage_key: 'documents/lab.pdf'
      };
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.patient_document.create.mockRejectedValue(error);

      await expect(create(newDocument))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      const newDocument = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        document_type: 'Lab Report',
        storage_key: 'documents/lab.pdf'
      };
      prisma.patient_document.create.mockRejectedValue(new Error('DB error'));

      await expect(create(newDocument))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update patient document', async () => {
      const updateData = {
        document_type: 'Updated Lab Report',
        file_name: 'updated-lab-report.pdf'
      };
      const mockUpdated = {
        id: 'doc-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        document_type: 'Updated Lab Report',
        storage_key: 'documents/patient-001/lab-report.pdf',
        file_name: 'updated-lab-report.pdf',
        content_type: 'application/pdf',
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 2
      };
      prisma.patient_document.update.mockResolvedValue(mockUpdated);

      const result = await update('doc-123', updateData);

      expect(result).toEqual(mockUpdated);
      expect(prisma.patient_document.update).toHaveBeenCalledWith({
        where: { id: 'doc-123' },
        data: updateData
      });
    });

    it('should throw HttpError when patient document not found (P2025)', async () => {
      const updateData = { document_type: 'X-Ray' };
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.patient_document.update.mockRejectedValue(error);

      await expect(update('doc-123', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation (P2002)', async () => {
      const updateData = { storage_key: 'duplicate.pdf' };
      const error = new Error('Unique constraint');
      error.code = 'P2002';
      error.meta = { target: ['storage_key'] };
      prisma.patient_document.update.mockRejectedValue(error);

      await expect(update('doc-123', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation (P2003)', async () => {
      const updateData = { patient_id: 'invalid-patient' };
      const error = new Error('Foreign key constraint');
      error.code = 'P2003';
      error.meta = { field_name: 'patient_id' };
      prisma.patient_document.update.mockRejectedValue(error);

      await expect(update('doc-123', updateData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      const updateData = { document_type: 'X-Ray' };
      prisma.patient_document.update.mockRejectedValue(new Error('DB error'));

      await expect(update('doc-123', updateData))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete patient document', async () => {
      const mockDeleted = {
        id: 'doc-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        document_type: 'Lab Report',
        deleted_at: new Date('2026-01-19')
      };
      prisma.patient_document.update.mockResolvedValue(mockDeleted);

      const result = await softDelete('doc-123');

      expect(result).toEqual(mockDeleted);
      expect(prisma.patient_document.update).toHaveBeenCalledWith({
        where: { id: 'doc-123' },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should throw HttpError when patient document not found (P2025)', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.patient_document.update.mockRejectedValue(error);

      await expect(softDelete('doc-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on other database errors', async () => {
      prisma.patient_document.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('doc-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
