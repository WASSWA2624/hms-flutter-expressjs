/**
 * Patient Document service tests
 *
 * @module tests/modules/patient-document/services
 * Per testing.mdc: Mock all external dependencies
 */

// Mock dependencies
jest.mock('@repositories/patient-document/patient-document.repository');
jest.mock('@lib/audit');

const patientDocumentRepository = require('@repositories/patient-document/patient-document.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listPatientDocuments,
  getPatientDocumentById,
  createPatientDocument,
  updatePatientDocument,
  deletePatientDocument
} = require('@services/patient-document/patient-document.service');

describe('Patient Document Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listPatientDocuments', () => {
    it('should list patient documents with default pagination', async () => {
      const mockDocuments = [
        { id: 'doc-1', patient_id: 'patient-123', document_type: 'Lab Report' },
        { id: 'doc-2', patient_id: 'patient-123', document_type: 'X-Ray' }
      ];
      patientDocumentRepository.findMany.mockResolvedValue(mockDocuments);
      patientDocumentRepository.count.mockResolvedValue(10);

      const result = await listPatientDocuments({}, 1, 20);

      expect(result.items).toEqual(mockDocuments);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should filter by patient_id', async () => {
      const mockDocuments = [{ id: 'doc-1', patient_id: 'patient-123' }];
      patientDocumentRepository.findMany.mockResolvedValue(mockDocuments);
      patientDocumentRepository.count.mockResolvedValue(1);

      await listPatientDocuments({ patient_id: 'patient-123' }, 1, 20);

      expect(patientDocumentRepository.findMany).toHaveBeenCalledWith(
        { patient_id: 'patient-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by document_type', async () => {
      const mockDocuments = [{ id: 'doc-1', document_type: 'Lab Report' }];
      patientDocumentRepository.findMany.mockResolvedValue(mockDocuments);
      patientDocumentRepository.count.mockResolvedValue(1);

      await listPatientDocuments({ document_type: 'Lab Report' }, 1, 20);

      expect(patientDocumentRepository.findMany).toHaveBeenCalledWith(
        { document_type: 'Lab Report' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle search query', async () => {
      const mockDocuments = [{ id: 'doc-1', document_type: 'Lab Report' }];
      patientDocumentRepository.findMany.mockResolvedValue(mockDocuments);
      patientDocumentRepository.count.mockResolvedValue(1);

      await listPatientDocuments({ search: 'test' }, 1, 20);

      expect(patientDocumentRepository.findMany).toHaveBeenCalledWith(
        {
          OR: [
            { document_type: { contains: 'test', mode: 'insensitive' } },
            { file_name: { contains: 'test', mode: 'insensitive' } }
          ]
        },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should calculate pagination correctly', async () => {
      const mockDocuments = [];
      patientDocumentRepository.findMany.mockResolvedValue(mockDocuments);
      patientDocumentRepository.count.mockResolvedValue(45);

      const result = await listPatientDocuments({}, 2, 20);

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 45,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true
      });
    });
  });

  describe('getPatientDocumentById', () => {
    it('should get patient document by ID', async () => {
      const mockDocument = { id: 'doc-123', document_type: 'Lab Report' };
      patientDocumentRepository.findById.mockResolvedValue(mockDocument);

      const result = await getPatientDocumentById('doc-123');

      expect(result).toEqual(mockDocument);
      expect(patientDocumentRepository.findById).toHaveBeenCalledWith('doc-123');
    });

    it('should return null if patient document not found', async () => {
      patientDocumentRepository.findById.mockResolvedValue(null);

      const result = await getPatientDocumentById('doc-123');

      expect(result).toBeNull();
    });
  });

  describe('createPatientDocument', () => {
    it('should create new patient document', async () => {
      const newDocument = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        document_type: 'Lab Report',
        storage_key: 'documents/lab-report.pdf',
        file_name: 'lab-report.pdf'
      };
      const mockCreated = { id: 'doc-123', ...newDocument };
      patientDocumentRepository.create.mockResolvedValue(mockCreated);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      const result = await createPatientDocument(newDocument, auditContext);

      expect(result).toEqual(mockCreated);
      expect(patientDocumentRepository.create).toHaveBeenCalledWith(newDocument);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'CREATE',
        entity: 'patient_document',
        entity_id: 'doc-123',
        diff: { after: mockCreated },
        ip: '127.0.0.1'
      });
    });

    it('should create audit log after creation', async () => {
      const newDocument = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        document_type: 'X-Ray',
        storage_key: 'documents/xray.jpg'
      };
      const mockCreated = { id: 'doc-456', ...newDocument };
      patientDocumentRepository.create.mockResolvedValue(mockCreated);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-456', ip: '192.168.1.1' };
      await createPatientDocument(newDocument, auditContext);

      expect(createAuditLog).toHaveBeenCalledTimes(1);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'CREATE',
          entity: 'patient_document',
          entity_id: 'doc-456'
        })
      );
    });
  });

  describe('updatePatientDocument', () => {
    it('should update patient document', async () => {
      const updateData = { document_type: 'Updated Report', file_name: 'updated.pdf' };
      const mockBefore = { id: 'doc-123', document_type: 'Lab Report' };
      const mockUpdated = { id: 'doc-123', document_type: 'Updated Report', file_name: 'updated.pdf' };
      patientDocumentRepository.findById.mockResolvedValue(mockBefore);
      patientDocumentRepository.update.mockResolvedValue(mockUpdated);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      const result = await updatePatientDocument('doc-123', updateData, auditContext);

      expect(result).toEqual(mockUpdated);
      expect(patientDocumentRepository.update).toHaveBeenCalledWith('doc-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'UPDATE',
        entity: 'patient_document',
        entity_id: 'doc-123',
        diff: { before: mockBefore, after: mockUpdated },
        ip: '127.0.0.1'
      });
    });

    it('should fetch before state for audit', async () => {
      const updateData = { document_type: 'CT Scan' };
      const mockBefore = { id: 'doc-123', document_type: 'X-Ray' };
      const mockUpdated = { id: 'doc-123', document_type: 'CT Scan' };
      patientDocumentRepository.findById.mockResolvedValue(mockBefore);
      patientDocumentRepository.update.mockResolvedValue(mockUpdated);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      await updatePatientDocument('doc-123', updateData, auditContext);

      expect(patientDocumentRepository.findById).toHaveBeenCalledWith('doc-123');
    });
  });

  describe('deletePatientDocument', () => {
    it('should soft delete patient document', async () => {
      const mockBefore = { id: 'doc-123', document_type: 'Lab Report', deleted_at: null };
      const mockDeleted = { id: 'doc-123', document_type: 'Lab Report', deleted_at: new Date() };
      patientDocumentRepository.findById.mockResolvedValue(mockBefore);
      patientDocumentRepository.softDelete.mockResolvedValue(mockDeleted);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      const result = await deletePatientDocument('doc-123', auditContext);

      expect(result).toEqual(mockDeleted);
      expect(patientDocumentRepository.softDelete).toHaveBeenCalledWith('doc-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'DELETE',
        entity: 'patient_document',
        entity_id: 'doc-123',
        diff: { before: mockBefore, after: mockDeleted },
        ip: '127.0.0.1'
      });
    });

    it('should fetch before state for audit', async () => {
      const mockBefore = { id: 'doc-123', document_type: 'X-Ray' };
      const mockDeleted = { id: 'doc-123', deleted_at: new Date() };
      patientDocumentRepository.findById.mockResolvedValue(mockBefore);
      patientDocumentRepository.softDelete.mockResolvedValue(mockDeleted);
      createAuditLog.mockResolvedValue({});

      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };
      await deletePatientDocument('doc-123', auditContext);

      expect(patientDocumentRepository.findById).toHaveBeenCalledWith('doc-123');
    });
  });
});
