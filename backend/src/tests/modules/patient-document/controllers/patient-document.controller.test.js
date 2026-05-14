/**
 * Patient Document controller tests
 *
 * @module tests/modules/patient-document/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/patient-document/patient-document.service');
jest.mock('@lib/response');

const patientDocumentService = require('@services/patient-document/patient-document.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { HttpError } = require('@lib/errors');
const {
  listPatientDocuments,
  getPatientDocumentById,
  createPatientDocument,
  updatePatientDocument,
  deletePatientDocument
} = require('@controllers/patient-document/patient-document.controller');

describe('Patient Document Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123'
      },
      ip: '192.168.1.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listPatientDocuments', () => {
    it('should list patient documents with default pagination', async () => {
      const mockResult = {
        items: [
          { id: 'doc-1', patient_id: 'patient-123', document_type: 'Lab Report' },
          { id: 'doc-2', patient_id: 'patient-123', document_type: 'X-Ray' }
        ],
        pagination: {
          page: 1,
          limit: 20,
          total: 2,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      patientDocumentService.listPatientDocuments.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listPatientDocuments(req, res);

      expect(patientDocumentService.listPatientDocuments).toHaveBeenCalled();
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.patient_document.list.success',
        mockResult.items,
        mockResult.pagination
      );
    });

    it('should list patient documents with filters', async () => {
      const mockResult = {
        items: [{ id: 'doc-1', patient_id: 'patient-123', document_type: 'Lab Report' }],
        pagination: { page: 1, limit: 20, total: 1 }
      };
      patientDocumentService.listPatientDocuments.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = { patient_id: 'patient-123', document_type: 'Lab Report' };

      await listPatientDocuments(req, res);

      expect(patientDocumentService.listPatientDocuments).toHaveBeenCalledWith(
        { patient_id: 'patient-123', document_type: 'Lab Report' },
        1,
        20,
        'created_at',
        'desc'
      );
    });

    it('should handle custom sort parameters', async () => {
      const mockResult = { items: [], pagination: {} };
      patientDocumentService.listPatientDocuments.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation(() => {});

      req.query = { sort_by: 'document_type', order: 'asc' };

      await listPatientDocuments(req, res);

      expect(patientDocumentService.listPatientDocuments).toHaveBeenCalledWith(
        {},
        1,
        20,
        'document_type',
        'asc'
      );
    });
  });

  describe('getPatientDocumentById', () => {
    it('should get patient document by ID', async () => {
      const mockDocument = { id: 'doc-123', document_type: 'Lab Report' };
      patientDocumentService.getPatientDocumentById.mockResolvedValue(mockDocument);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'doc-123' };

      await getPatientDocumentById(req, res);

      expect(patientDocumentService.getPatientDocumentById).toHaveBeenCalledWith('doc-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.patient_document.get.success',
        mockDocument
      );
    });

    it('should throw HttpError when patient document not found', async () => {
      patientDocumentService.getPatientDocumentById.mockResolvedValue(null);

      req.params = { id: 'doc-123' };

      await expect(getPatientDocumentById(req, res))
        .rejects
        .toThrow();
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
      patientDocumentService.createPatientDocument.mockResolvedValue(mockCreated);
      sendSuccess.mockImplementation(() => {});

      req.body = newDocument;

      await createPatientDocument(req, res);

      expect(patientDocumentService.createPatientDocument).toHaveBeenCalledWith(
        newDocument,
        {
          user_id: 'user-123',
          ip: '192.168.1.1'
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.patient_document.create.success',
        mockCreated
      );
    });

    it('should pass audit context from request', async () => {
      const newDocument = { document_type: 'X-Ray', storage_key: 'docs/xray.jpg' };
      const mockCreated = { id: 'doc-456', ...newDocument };
      patientDocumentService.createPatientDocument.mockResolvedValue(mockCreated);
      sendSuccess.mockImplementation(() => {});

      req.body = newDocument;
      req.user = { id: 'user-456' };
      req.ip = '10.0.0.1';

      await createPatientDocument(req, res);

      expect(patientDocumentService.createPatientDocument).toHaveBeenCalledWith(
        newDocument,
        {
          user_id: 'user-456',
          ip: '10.0.0.1'
        }
      );
    });
  });

  describe('updatePatientDocument', () => {
    it('should update patient document', async () => {
      const updateData = { document_type: 'Updated Report', file_name: 'updated.pdf' };
      const mockUpdated = { id: 'doc-123', document_type: 'Updated Report', file_name: 'updated.pdf' };
      patientDocumentService.updatePatientDocument.mockResolvedValue(mockUpdated);
      sendSuccess.mockImplementation(() => {});

      req.params = { id: 'doc-123' };
      req.body = updateData;

      await updatePatientDocument(req, res);

      expect(patientDocumentService.updatePatientDocument).toHaveBeenCalledWith(
        'doc-123',
        updateData,
        {
          user_id: 'user-123',
          ip: '192.168.1.1'
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.patient_document.update.success',
        mockUpdated
      );
    });
  });

  describe('deletePatientDocument', () => {
    it('should delete patient document and return 204', async () => {
      patientDocumentService.deletePatientDocument.mockResolvedValue({});

      req.params = { id: 'doc-123' };

      await deletePatientDocument(req, res);

      expect(patientDocumentService.deletePatientDocument).toHaveBeenCalledWith(
        'doc-123',
        {
          user_id: 'user-123',
          ip: '192.168.1.1'
        }
      );
      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });
  });
});
