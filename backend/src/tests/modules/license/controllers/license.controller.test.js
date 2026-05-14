/**
 * License controller tests
 *
 * @module tests/modules/license/controllers
 * Per testing.mdc: Mock all service dependencies
 */

jest.mock('@services/license/license.service');
jest.mock('@lib/response');
jest.mock('@lib/i18n');

const licenseService = require('@services/license/license.service');
const { sendSuccess, sendPaginated } = require('@lib/response');
const { getLocale } = require('@lib/i18n');
const {
  listLicenses,
  getLicenseById,
  createLicense,
  updateLicense,
  deleteLicense
} = require('@controllers/license/license.controller');

describe('License Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    getLocale.mockReturnValue('en');
    req = {
      query: {},
      params: {},
      body: {},
      user: { id: 'user-123', tenant_id: 'tenant-123' },
      ip: '192.168.1.1'
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listLicenses', () => {
    it('should list licenses with pagination', async () => {
      const mockResult = {
        licenses: [
          { id: 'license-1', tenant_id: 'tenant-1' },
          { id: 'license-2', tenant_id: 'tenant-2' }
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
      licenseService.listLicenses.mockResolvedValue(mockResult);

      req.query = { page: 1, limit: 20 };

      await listLicenses(req, res);

      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.license.list.success',
        mockResult.licenses,
        mockResult.pagination,
        'en'
      );
    });
  });

  describe('getLicenseById', () => {
    it('should get license by ID', async () => {
      const mockLicense = { id: 'license-123', tenant_id: 'tenant-123' };
      licenseService.getLicenseById.mockResolvedValue(mockLicense);

      req.params = { id: 'license-123' };

      await getLicenseById(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.license.get.success',
        mockLicense,
        'en'
      );
    });
  });

  describe('createLicense', () => {
    it('should create license', async () => {
      const data = {
        tenant_id: 'tenant-123',
        license_type: 'PER_USER',
        status: 'ACTIVE'
      };
      const mockCreated = { id: 'license-new', ...data };
      licenseService.createLicense.mockResolvedValue(mockCreated);

      req.body = data;

      await createLicense(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.license.create.success',
        mockCreated,
        'en'
      );
    });
  });

  describe('updateLicense', () => {
    it('should update license', async () => {
      const updateData = { status: 'CANCELLED' };
      const mockUpdated = { id: 'license-123', status: 'CANCELLED' };
      licenseService.updateLicense.mockResolvedValue(mockUpdated);

      req.params = { id: 'license-123' };
      req.body = updateData;

      await updateLicense(req, res);

      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.license.update.success',
        mockUpdated,
        'en'
      );
    });
  });

  describe('deleteLicense', () => {
    it('should delete license', async () => {
      licenseService.deleteLicense.mockResolvedValue({});

      req.params = { id: 'license-123' };

      await deleteLicense(req, res);

      expect(res.status).toHaveBeenCalledWith(204);
      expect(res.send).toHaveBeenCalled();
    });
  });
});
