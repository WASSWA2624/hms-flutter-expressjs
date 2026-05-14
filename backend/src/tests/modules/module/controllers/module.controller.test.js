/**
 * Module controller tests
 *
 * @module tests/modules/module/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/module/module.service');
jest.mock('@lib/response');
jest.mock('@lib/i18n');

const moduleService = require('@services/module/module.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { getLocale } = require('@lib/i18n');
const {
  listModules,
  getModuleById,
  createModule,
  updateModule,
  deleteModule
} = require('@controllers/module/module.controller');

describe('Module Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    getLocale.mockReturnValue('en');
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

  describe('listModules', () => {
    it('should list modules with default pagination', async () => {
      const mockResult = {
        modules: [
          { id: 'module-1', name: 'Module A' },
          { id: 'module-2', name: 'Module B' }
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
      moduleService.listModules.mockResolvedValue(mockResult);

      req.query = { page: 1, limit: 20 };

      await listModules(req, res);

      expect(moduleService.listModules).toHaveBeenCalledWith(
        {},
        1,
        20,
        'created_at',
        'desc'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.module.list.success',
        mockResult.modules,
        mockResult.pagination,
        'en'
      );
    });

    it('should list modules with filters', async () => {
      const mockResult = {
        modules: [{ id: 'module-1', name: 'Module A' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      moduleService.listModules.mockResolvedValue(mockResult);

      req.query = {
        page: 1,
        limit: 20,
        search: 'module'
      };

      await listModules(req, res);

      expect(moduleService.listModules).toHaveBeenCalledWith(
        { search: 'module' },
        1,
        20,
        'created_at',
        'desc'
      );
    });

    it('should list modules with custom sorting', async () => {
      const mockResult = {
        modules: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      moduleService.listModules.mockResolvedValue(mockResult);

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'name',
        order: 'asc'
      };

      await listModules(req, res);

      expect(moduleService.listModules).toHaveBeenCalledWith(
        {},
        1,
        20,
        'name',
        'asc'
      );
    });
  });

  describe('getModuleById', () => {
    it('should get module by ID', async () => {
      const mockModule = {
        id: 'module-123',
        name: 'Test Module',
        description: 'Test description'
      };
      moduleService.getModuleById.mockResolvedValue(mockModule);

      req.params = { id: 'module-123' };

      await getModuleById(req, res);

      expect(moduleService.getModuleById).toHaveBeenCalledWith('module-123');
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.module.get.success',
        mockModule,
        'en'
      );
    });
  });

  describe('createModule', () => {
    it('should create a new module', async () => {
      const moduleData = {
        name: 'New Module',
        description: 'New description'
      };
      const mockCreatedModule = {
        id: 'module-new',
        ...moduleData
      };
      moduleService.createModule.mockResolvedValue(mockCreatedModule);

      req.body = moduleData;

      await createModule(req, res);

      expect(moduleService.createModule).toHaveBeenCalledWith(
        moduleData,
        {
          user: req.user,
          ip: req.ip,
          tenant_id: 'tenant-123'
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.module.create.success',
        mockCreatedModule,
        'en'
      );
    });
  });

  describe('updateModule', () => {
    it('should update a module', async () => {
      const updateData = {
        name: 'Updated Module',
        description: 'Updated description'
      };
      const mockUpdatedModule = {
        id: 'module-123',
        ...updateData
      };
      moduleService.updateModule.mockResolvedValue(mockUpdatedModule);

      req.params = { id: 'module-123' };
      req.body = updateData;

      await updateModule(req, res);

      expect(moduleService.updateModule).toHaveBeenCalledWith(
        'module-123',
        updateData,
        {
          user: req.user,
          ip: req.ip,
          tenant_id: 'tenant-123'
        }
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.module.update.success',
        mockUpdatedModule,
        'en'
      );
    });
  });

  describe('deleteModule', () => {
    it('should delete a module', async () => {
      moduleService.deleteModule.mockResolvedValue({});

      req.params = { id: 'module-123' };

      await deleteModule(req, res);

      expect(moduleService.deleteModule).toHaveBeenCalledWith(
        'module-123',
        {
          user: req.user,
          ip: req.ip,
          tenant_id: 'tenant-123'
        }
      );
      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });
  });
});
