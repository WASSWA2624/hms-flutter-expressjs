/**
 * Lab test controller tests
 *
 * @module tests/modules/lab-test/controllers
 * @description Tests for lab test controller operations
 * Per testing.mdc: All controllers must be tested with mocked services
 */

const labTestController = require('@controllers/lab-test/lab-test.controller');
const labTestService = require('@services/lab-test/lab-test.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

// Mock dependencies
jest.mock('@services/lab-test/lab-test.service');
jest.mock('@lib/response');

describe('Lab Test Controller', () => {
  let mockReq;
  let mockRes;
  let mockNext;

  beforeEach(() => {
    mockReq = {
      query: {},
      params: {},
      body: {},
      user: { id: '123e4567-e89b-12d3-a456-426614174000' },
      ip: '127.0.0.1'
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
    mockNext = jest.fn();
    jest.clearAllMocks();
  });

  describe('listLabTests', () => {
    it('should list lab tests successfully', async () => {
      const mockLabTests = [
        { id: '1', name: 'Complete Blood Count', code: 'CBC' },
        { id: '2', name: 'Hemoglobin', code: 'HGB' }
      ];
      const mockPagination = {
        page: 1,
        limit: 20,
        total: 2,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      };

      mockReq.query = {
        page: '1',
        limit: '20',
        order: 'asc'
      };

      labTestService.listLabTests.mockResolvedValue({
        labTests: mockLabTests,
        pagination: mockPagination
      });

      await labTestController.listLabTests(mockReq, mockRes);

      expect(labTestService.listLabTests).toHaveBeenCalledWith(
        expect.any(Object),
        1,
        20,
        undefined,
        'asc',
        mockReq.user.id,
        mockReq.ip
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        mockRes,
        'messages.lab_test.list.success',
        mockLabTests,
        mockPagination
      );
    });

    it('should apply filters correctly', async () => {
      mockReq.query = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Blood',
        code: 'CBC',
        search: 'test',
        page: '1',
        limit: '20'
      };

      labTestService.listLabTests.mockResolvedValue({
        labTests: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      });

      await labTestController.listLabTests(mockReq, mockRes);

      expect(labTestService.listLabTests).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: '123e4567-e89b-12d3-a456-426614174001',
          name: 'Blood',
          code: 'CBC',
          search: 'test'
        }),
        1,
        20,
        undefined,
        'asc',
        mockReq.user.id,
        mockReq.ip
      );
    });

    it('should use default pagination values', async () => {
      mockReq.query = {};

      labTestService.listLabTests.mockResolvedValue({
        labTests: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      });

      await labTestController.listLabTests(mockReq, mockRes);

      expect(labTestService.listLabTests).toHaveBeenCalledWith(
        expect.any(Object),
        1,
        20,
        undefined,
        'asc',
        mockReq.user.id,
        mockReq.ip
      );
    });
  });

  describe('getLabTestById', () => {
    it('should get lab test by ID successfully', async () => {
      const mockLabTest = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Blood Count',
        code: 'CBC'
      };

      mockReq.params = { id: '123e4567-e89b-12d3-a456-426614174000' };

      labTestService.getLabTestById.mockResolvedValue(mockLabTest);

      await labTestController.getLabTestById(mockReq, mockRes);

      expect(labTestService.getLabTestById).toHaveBeenCalledWith(
        '123e4567-e89b-12d3-a456-426614174000',
        mockReq.user.id,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.lab_test.get.success',
        mockLabTest
      );
    });
  });

  describe('createLabTest', () => {
    it('should create lab test successfully', async () => {
      const newLabTest = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Complete Blood Count',
        code: 'CBC'
      };

      const createdLabTest = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        ...newLabTest,
        created_at: new Date(),
        updated_at: new Date()
      };

      mockReq.body = newLabTest;

      labTestService.createLabTest.mockResolvedValue(createdLabTest);

      await labTestController.createLabTest(mockReq, mockRes);

      expect(labTestService.createLabTest).toHaveBeenCalledWith(
        newLabTest,
        mockReq.user.id,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.lab_test.create.success',
        createdLabTest
      );
    });
  });

  describe('updateLabTest', () => {
    it('should update lab test successfully', async () => {
      const updateData = { name: 'Updated Lab Test' };
      const updatedLabTest = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        tenant_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Updated Lab Test',
        code: 'CBC',
        updated_at: new Date()
      };

      mockReq.params = { id: '123e4567-e89b-12d3-a456-426614174000' };
      mockReq.body = updateData;

      labTestService.updateLabTest.mockResolvedValue(updatedLabTest);

      await labTestController.updateLabTest(mockReq, mockRes);

      expect(labTestService.updateLabTest).toHaveBeenCalledWith(
        '123e4567-e89b-12d3-a456-426614174000',
        updateData,
        mockReq.user.id,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.lab_test.update.success',
        updatedLabTest
      );
    });
  });

  describe('deleteLabTest', () => {
    it('should delete lab test successfully', async () => {
      mockReq.params = { id: '123e4567-e89b-12d3-a456-426614174000' };

      labTestService.deleteLabTest.mockResolvedValue({
        id: '123e4567-e89b-12d3-a456-426614174000',
        deleted_at: new Date()
      });

      await labTestController.deleteLabTest(mockReq, mockRes);

      expect(labTestService.deleteLabTest).toHaveBeenCalledWith(
        '123e4567-e89b-12d3-a456-426614174000',
        mockReq.user.id,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        204,
        null,
        null
      );
    });
  });
});
