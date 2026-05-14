const formularyItemRepository = require('@repositories/formulary-item/formulary-item.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

jest.mock('@prisma/client', () => ({
  formulary_item: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Formulary Item Repository', () => {
  beforeEach(() => jest.clearAllMocks());

  describe('findById', () => {
    it('should find formulary item by id', async () => {
      const mock = { id: '123', drug_id: '456', is_active: true };
      prisma.formulary_item.findFirst.mockResolvedValue(mock);
      expect(await formularyItemRepository.findById('123')).toEqual(mock);
    });

    it('should return null if not found', async () => {
      prisma.formulary_item.findFirst.mockResolvedValue(null);
      expect(await formularyItemRepository.findById('123')).toBeNull();
    });

    it('should throw HttpError on error', async () => {
      prisma.formulary_item.findFirst.mockRejectedValue(new Error('DB Error'));
      await expect(formularyItemRepository.findById('123')).rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many formulary items', async () => {
      const mocks = [{ id: '1' }, { id: '2' }];
      prisma.formulary_item.findMany.mockResolvedValue(mocks);
      expect(await formularyItemRepository.findMany({}, 0, 20)).toEqual(mocks);
    });
  });

  describe('count', () => {
    it('should count formulary items', async () => {
      prisma.formulary_item.count.mockResolvedValue(42);
      expect(await formularyItemRepository.count({})).toBe(42);
    });
  });

  describe('create', () => {
    it('should create formulary item', async () => {
      const mock = { id: '123', drug_id: '456', is_active: true };
      prisma.formulary_item.create.mockResolvedValue(mock);
      expect(await formularyItemRepository.create({ drug_id: '456' })).toEqual(mock);
    });

    it('should handle constraint errors', async () => {
      const error = new Error('Constraint');
      error.code = 'P2002';
      error.meta = { target: ['drug_id'] };
      prisma.formulary_item.create.mockRejectedValue(error);
      await expect(formularyItemRepository.create({})).rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update formulary item', async () => {
      const mock = { id: '123', is_active: false };
      prisma.formulary_item.update.mockResolvedValue(mock);
      expect(await formularyItemRepository.update('123', { is_active: false })).toEqual(mock);
    });

    it('should throw on not found', async () => {
      const error = new Error('Not found');
      error.code = 'P2025';
      prisma.formulary_item.update.mockRejectedValue(error);
      await expect(formularyItemRepository.update('123', {})).rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete formulary item', async () => {
      const mock = { id: '123', deleted_at: new Date() };
      prisma.formulary_item.update.mockResolvedValue(mock);
      expect(await formularyItemRepository.softDelete('123')).toEqual(mock);
    });
  });
});
