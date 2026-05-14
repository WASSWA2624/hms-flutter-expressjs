/**
 * Conversation repository tests
 *
 * @module tests/modules/conversation/repositories
 * @description Tests for conversation repository layer
 * Per testing.mdc: Mock Prisma client, test all CRUD operations
 */

const conversationRepository = require('@repositories/conversation/conversation.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  conversation: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Conversation Repository', () => {
  const mockConversation = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    tenant_id: '550e8400-e29b-41d4-a716-446655440001',
    subject: 'Test Conversation',
    created_by_user_id: '550e8400-e29b-41d4-a716-446655440002',
    created_at: new Date(),
    updated_at: new Date(),
    deleted_at: null,
    version: 1
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find conversation by id', async () => {
      prisma.conversation.findFirst.mockResolvedValue(mockConversation);
      
      const result = await conversationRepository.findById(mockConversation.id);
      
      expect(result).toEqual(mockConversation);
      expect(prisma.conversation.findFirst).toHaveBeenCalledWith({
        where: { id: mockConversation.id, deleted_at: null },
        include: {}
      });
    });

    it('should return null if not found', async () => {
      prisma.conversation.findFirst.mockResolvedValue(null);
      
      const result = await conversationRepository.findById('non-existent-id');
      
      expect(result).toBeNull();
    });

    it('should handle database errors', async () => {
      prisma.conversation.findFirst.mockRejectedValue(new Error('DB error'));
      
      await expect(conversationRepository.findById(mockConversation.id))
        .rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find multiple conversations', async () => {
      const mockConversations = [mockConversation];
      prisma.conversation.findMany.mockResolvedValue(mockConversations);
      
      const result = await conversationRepository.findMany({}, 0, 20);
      
      expect(result).toEqual(mockConversations);
      expect(prisma.conversation.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      prisma.conversation.findMany.mockResolvedValue([]);
      
      await conversationRepository.findMany({ tenant_id: mockConversation.tenant_id }, 0, 20);
      
      expect(prisma.conversation.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, tenant_id: mockConversation.tenant_id },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });
  });

  describe('count', () => {
    it('should count conversations', async () => {
      prisma.conversation.count.mockResolvedValue(5);
      
      const result = await conversationRepository.count({});
      
      expect(result).toBe(5);
      expect(prisma.conversation.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });
  });

  describe('create', () => {
    it('should create new conversation', async () => {
      const newData = {
        tenant_id: mockConversation.tenant_id,
        subject: mockConversation.subject
      };
      prisma.conversation.create.mockResolvedValue(mockConversation);
      
      const result = await conversationRepository.create(newData);
      
      expect(result).toEqual(mockConversation);
      expect(prisma.conversation.create).toHaveBeenCalledWith({ data: newData });
    });

    it('should handle unique constraint errors', async () => {
      prisma.conversation.create.mockRejectedValue({ code: 'P2002', meta: { target: ['field'] } });
      
      await expect(conversationRepository.create({}))
        .rejects.toThrow(HttpError);
    });

    it('should handle foreign key errors', async () => {
      prisma.conversation.create.mockRejectedValue({ code: 'P2003', meta: { field_name: 'tenant_id' } });
      
      await expect(conversationRepository.create({}))
        .rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update conversation', async () => {
      const updateData = { subject: 'Updated Subject' };
      const updatedConversation = { ...mockConversation, ...updateData };
      prisma.conversation.update.mockResolvedValue(updatedConversation);
      
      const result = await conversationRepository.update(mockConversation.id, updateData);
      
      expect(result).toEqual(updatedConversation);
      expect(prisma.conversation.update).toHaveBeenCalledWith({
        where: { id: mockConversation.id },
        data: updateData
      });
    });

    it('should handle not found errors', async () => {
      prisma.conversation.update.mockRejectedValue({ code: 'P2025' });
      
      await expect(conversationRepository.update('non-existent', {}))
        .rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete conversation', async () => {
      const deletedConversation = { ...mockConversation, deleted_at: new Date() };
      prisma.conversation.update.mockResolvedValue(deletedConversation);
      
      const result = await conversationRepository.softDelete(mockConversation.id);
      
      expect(result.deleted_at).toBeTruthy();
      expect(prisma.conversation.update).toHaveBeenCalledWith({
        where: { id: mockConversation.id },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should handle not found errors', async () => {
      prisma.conversation.update.mockRejectedValue({ code: 'P2025' });
      
      await expect(conversationRepository.softDelete('non-existent'))
        .rejects.toThrow(HttpError);
    });
  });
});
