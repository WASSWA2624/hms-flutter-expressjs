/**
 * Message repository tests
 *
 * @module tests/modules/message/repositories
 * @description Tests for message repository layer
 * Per testing.mdc: Mock Prisma client, test all CRUD operations
 */

const messageRepository = require('@repositories/message/message.repository');
const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

// Mock Prisma client
jest.mock('@prisma/client', () => ({
  message: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

describe('Message Repository', () => {
  const mockMessage = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    conversation_id: '550e8400-e29b-41d4-a716-446655440001',
    sender_user_id: '550e8400-e29b-41d4-a716-446655440002',
    content: 'Test message',
    sent_at: new Date(),
    created_at: new Date(),
    updated_at: new Date(),
    deleted_at: null,
    version: 1
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find message by id', async () => {
      prisma.message.findFirst.mockResolvedValue(mockMessage);
      
      const result = await messageRepository.findById(mockMessage.id);
      
      expect(result).toEqual(mockMessage);
      expect(prisma.message.findFirst).toHaveBeenCalledWith({
        where: { id: mockMessage.id, deleted_at: null },
        include: {}
      });
    });

    it('should return null if not found', async () => {
      prisma.message.findFirst.mockResolvedValue(null);
      
      const result = await messageRepository.findById('non-existent-id');
      
      expect(result).toBeNull();
    });

    it('should handle database errors', async () => {
      prisma.message.findFirst.mockRejectedValue(new Error('DB error'));
      
      await expect(messageRepository.findById(mockMessage.id))
        .rejects.toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find multiple messages', async () => {
      const mockMessages = [mockMessage];
      prisma.message.findMany.mockResolvedValue(mockMessages);
      
      const result = await messageRepository.findMany({}, 0, 20);
      
      expect(result).toEqual(mockMessages);
      expect(prisma.message.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });

    it('should apply filters', async () => {
      prisma.message.findMany.mockResolvedValue([]);
      
      await messageRepository.findMany({ conversation_id: mockMessage.conversation_id }, 0, 20);
      
      expect(prisma.message.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null, conversation_id: mockMessage.conversation_id },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' },
        include: {}
      });
    });
  });

  describe('count', () => {
    it('should count messages', async () => {
      prisma.message.count.mockResolvedValue(10);
      
      const result = await messageRepository.count({});
      
      expect(result).toBe(10);
      expect(prisma.message.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });
  });

  describe('create', () => {
    it('should create new message', async () => {
      const newData = {
        conversation_id: mockMessage.conversation_id,
        content: mockMessage.content
      };
      prisma.message.create.mockResolvedValue(mockMessage);
      
      const result = await messageRepository.create(newData);
      
      expect(result).toEqual(mockMessage);
      expect(prisma.message.create).toHaveBeenCalledWith({ data: newData });
    });

    it('should handle foreign key errors', async () => {
      prisma.message.create.mockRejectedValue({ code: 'P2003', meta: { field_name: 'conversation_id' } });
      
      await expect(messageRepository.create({}))
        .rejects.toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update message', async () => {
      const updateData = { content: 'Updated content' };
      const updatedMessage = { ...mockMessage, ...updateData };
      prisma.message.update.mockResolvedValue(updatedMessage);
      
      const result = await messageRepository.update(mockMessage.id, updateData);
      
      expect(result).toEqual(updatedMessage);
      expect(prisma.message.update).toHaveBeenCalledWith({
        where: { id: mockMessage.id },
        data: updateData
      });
    });

    it('should handle not found errors', async () => {
      prisma.message.update.mockRejectedValue({ code: 'P2025' });
      
      await expect(messageRepository.update('non-existent', {}))
        .rejects.toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete message', async () => {
      const deletedMessage = { ...mockMessage, deleted_at: new Date() };
      prisma.message.update.mockResolvedValue(deletedMessage);
      
      const result = await messageRepository.softDelete(mockMessage.id);
      
      expect(result.deleted_at).toBeTruthy();
      expect(prisma.message.update).toHaveBeenCalledWith({
        where: { id: mockMessage.id },
        data: { deleted_at: expect.any(Date) }
      });
    });

    it('should handle not found errors', async () => {
      prisma.message.update.mockRejectedValue({ code: 'P2025' });
      
      await expect(messageRepository.softDelete('non-existent'))
        .rejects.toThrow(HttpError);
    });
  });
});
