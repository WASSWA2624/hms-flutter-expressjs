/**
 * Purchase request repository tests
 */

const purchaseRequestRepository = require('@modules/purchase-request/repositories/purchase-request.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  purchase_request: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Purchase Request Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find purchase request by ID', async () => {
      const mockPurchaseRequest = {
        id: '550e8400-e29b-41d4-a716-446655440000',
        tenant_id: '660e8400-e29b-41d4-a716-446655440000',
        status: 'PENDING',
        deleted_at: null
      };

      prisma.purchase_request.findFirst.mockResolvedValue(mockPurchaseRequest);

      const result = await purchaseRequestRepository.findById('550e8400-e29b-41d4-a716-446655440000');

      expect(result).toEqual(mockPurchaseRequest);
    });

    it('should return null if not found', async () => {
      prisma.purchase_request.findFirst.mockResolvedValue(null);
      const result = await purchaseRequestRepository.findById('non-existent-id');
      expect(result).toBeNull();
    });
  });

  describe('findMany', () => {
    it('should find multiple purchase requests', async () => {
      const mockRequests = [{ id: '1', status: 'PENDING' }, { id: '2', status: 'APPROVED' }];
      prisma.purchase_request.findMany.mockResolvedValue(mockRequests);

      const result = await purchaseRequestRepository.findMany({}, 0, 20);

      expect(result).toEqual(mockRequests);
    });
  });

  describe('count', () => {
    it('should count purchase requests', async () => {
      prisma.purchase_request.count.mockResolvedValue(42);
      const result = await purchaseRequestRepository.count();
      expect(result).toBe(42);
    });
  });

  describe('create', () => {
    it('should create new purchase request', async () => {
      const data = { tenant_id: '660e8400-e29b-41d4-a716-446655440000', status: 'PENDING' };
      const mockCreated = { id: '550e8400-e29b-41d4-a716-446655440000', ...data };

      prisma.purchase_request.create.mockResolvedValue(mockCreated);

      const result = await purchaseRequestRepository.create(data);

      expect(result).toEqual(mockCreated);
    });
  });

  describe('update', () => {
    it('should update purchase request', async () => {
      const mockUpdated = { id: '550e8400-e29b-41d4-a716-446655440000', status: 'APPROVED' };
      prisma.purchase_request.update.mockResolvedValue(mockUpdated);

      const result = await purchaseRequestRepository.update('550e8400-e29b-41d4-a716-446655440000', { status: 'APPROVED' });

      expect(result).toEqual(mockUpdated);
    });
  });

  describe('softDelete', () => {
    it('should soft delete purchase request', async () => {
      const mockDeleted = { id: '550e8400-e29b-41d4-a716-446655440000', deleted_at: new Date() };
      prisma.purchase_request.update.mockResolvedValue(mockDeleted);

      const result = await purchaseRequestRepository.softDelete('550e8400-e29b-41d4-a716-446655440000');

      expect(result).toEqual(mockDeleted);
    });
  });
});
