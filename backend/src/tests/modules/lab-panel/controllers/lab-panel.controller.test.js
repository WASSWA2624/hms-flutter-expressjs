/**
 * Lab panel controller tests
 *
 * @module tests/modules/lab-panel/controllers
 * @description Tests for lab panel controller operations
 * Per testing.mdc: All controllers must be tested with mocked services
 */

const labPanelController = require('@controllers/lab-panel/lab-panel.controller');
const labPanelService = require('@services/lab-panel/lab-panel.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

// Mock dependencies
jest.mock('@services/lab-panel/lab-panel.service');
jest.mock('@lib/response');

describe('Lab Panel Controller', () => {
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

  describe('listLabPanels', () => {
    it('should list lab panels successfully', async () => {
      const mockLabPanels = [
        { id: '1', name: 'Complete Metabolic Panel', code: 'CMP' },
        { id: '2', name: 'Basic Metabolic Panel', code: 'BMP' }
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

      labPanelService.listLabPanels.mockResolvedValue({
        labPanels: mockLabPanels,
        pagination: mockPagination
      });

      await labPanelController.listLabPanels(mockReq, mockRes);

      expect(labPanelService.listLabPanels).toHaveBeenCalledWith(
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
        'messages.lab_panel.list.success',
        mockLabPanels,
        mockPagination
      );
    });

    it('should apply filters correctly', async () => {
      mockReq.query = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Metabolic',
        code: 'CMP',
        search: 'test',
        page: '1',
        limit: '20'
      };

      labPanelService.listLabPanels.mockResolvedValue({
        labPanels: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      });

      await labPanelController.listLabPanels(mockReq, mockRes);

      expect(labPanelService.listLabPanels).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: '123e4567-e89b-12d3-a456-426614174001',
          name: 'Metabolic',
          code: 'CMP',
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

      labPanelService.listLabPanels.mockResolvedValue({
        labPanels: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      });

      await labPanelController.listLabPanels(mockReq, mockRes);

      expect(labPanelService.listLabPanels).toHaveBeenCalledWith(
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

  describe('getLabPanelById', () => {
    it('should get lab panel by ID successfully', async () => {
      const mockLabPanel = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Complete Metabolic Panel',
        code: 'CMP'
      };

      mockReq.params = { id: '123e4567-e89b-12d3-a456-426614174000' };

      labPanelService.getLabPanelById.mockResolvedValue(mockLabPanel);

      await labPanelController.getLabPanelById(mockReq, mockRes);

      expect(labPanelService.getLabPanelById).toHaveBeenCalledWith(
        '123e4567-e89b-12d3-a456-426614174000',
        mockReq.user.id,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.lab_panel.get.success',
        mockLabPanel
      );
    });
  });

  describe('createLabPanel', () => {
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
        updated_at: new Date()
      };

      mockReq.body = newLabPanel;

      labPanelService.createLabPanel.mockResolvedValue(createdLabPanel);

      await labPanelController.createLabPanel(mockReq, mockRes);

      expect(labPanelService.createLabPanel).toHaveBeenCalledWith(
        newLabPanel,
        mockReq.user.id,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        201,
        'messages.lab_panel.create.success',
        createdLabPanel
      );
    });
  });

  describe('updateLabPanel', () => {
    it('should update lab panel successfully', async () => {
      const updateData = { name: 'Updated Lab Panel' };
      const updatedLabPanel = {
        id: '123e4567-e89b-12d3-a456-426614174000',
        tenant_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Updated Lab Panel',
        code: 'CMP',
        updated_at: new Date()
      };

      mockReq.params = { id: '123e4567-e89b-12d3-a456-426614174000' };
      mockReq.body = updateData;

      labPanelService.updateLabPanel.mockResolvedValue(updatedLabPanel);

      await labPanelController.updateLabPanel(mockReq, mockRes);

      expect(labPanelService.updateLabPanel).toHaveBeenCalledWith(
        '123e4567-e89b-12d3-a456-426614174000',
        updateData,
        mockReq.user.id,
        mockReq.ip
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        mockRes,
        200,
        'messages.lab_panel.update.success',
        updatedLabPanel
      );
    });
  });

  describe('deleteLabPanel', () => {
    it('should delete lab panel successfully', async () => {
      mockReq.params = { id: '123e4567-e89b-12d3-a456-426614174000' };

      labPanelService.deleteLabPanel.mockResolvedValue({
        id: '123e4567-e89b-12d3-a456-426614174000',
        deleted_at: new Date()
      });

      await labPanelController.deleteLabPanel(mockReq, mockRes);

      expect(labPanelService.deleteLabPanel).toHaveBeenCalledWith(
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
