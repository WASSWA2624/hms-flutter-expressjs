/**
 * Message service tests
 *
 * @module tests/modules/message/services
 * @description Tests for message service layer
 * Per testing.mdc: Mock repository, test business logic
 */

const messageService = require('@services/message/message.service');
const messageRepository = require('@repositories/message/message.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/message/message.repository');
jest.mock('@lib/audit');

describe('Message Service', () => {
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

  const mockUser = {
    id: '550e8400-e29b-41d4-a716-446655440003',
    ip: '127.0.0.1',
    user_agent: 'test-agent'
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getMessageById', () => {
    it('should return message if found', async () => {
      messageRepository.findById.mockResolvedValue(mockMessage);
      
      const result = await messageService.getMessageById(mockMessage.id);
      
      expect(result).toEqual(mockMessage);
      expect(messageRepository.findById).toHaveBeenCalledWith(mockMessage.id, {});
    });

    it('should throw error if message not found', async () => {
      messageRepository.findById.mockResolvedValue(null);
      
      await expect(messageService.getMessageById('non-existent'))
        .rejects.toThrow(HttpError);
    });
  });

  describe('listMessages', () => {
    it('should list messages with pagination', async () => {
      const mockMessages = [mockMessage];
      messageRepository.findMany.mockResolvedValue(mockMessages);
      messageRepository.count.mockResolvedValue(1);
      
      const result = await messageService.listMessages({}, 1, 20);
      
      expect(result).toEqual({
        messages: mockMessages,
        total: 1,
        page: 1,
        limit: 20,
        totalPages: 1
      });
    });

    it('should handle search filter', async () => {
      messageRepository.findMany.mockResolvedValue([]);
      messageRepository.count.mockResolvedValue(0);
      
      await messageService.listMessages({ search: 'test' }, 1, 20);
      
      expect(messageRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            expect.objectContaining({ content: expect.any(Object) })
          ])
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object),
        expect.any(Object)
      );
    });
  });

  describe('createMessage', () => {
    it('should create message and log audit', async () => {
      const newData = { conversation_id: mockMessage.conversation_id, content: mockMessage.content };
      messageRepository.create.mockResolvedValue(mockMessage);
      createAuditLog.mockResolvedValue({});
      
      const result = await messageService.createMessage(newData, mockUser);
      
      expect(result).toEqual(mockMessage);
      expect(messageRepository.create).toHaveBeenCalledWith(newData);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        user_id: mockUser.id,
        action: 'CREATE',
        entity: 'message',
        entity_id: mockMessage.id
      }));
    });

    it('should not fail if audit log fails', async () => {
      messageRepository.create.mockResolvedValue(mockMessage);
      createAuditLog.mockRejectedValue(new Error('Audit error'));
      
      const result = await messageService.createMessage({}, mockUser);
      
      expect(result).toEqual(mockMessage);
    });
  });

  describe('updateMessage', () => {
    it('should update message and log audit', async () => {
      const updateData = { content: 'Updated' };
      const updatedMessage = { ...mockMessage, ...updateData };
      messageRepository.findById.mockResolvedValue(mockMessage);
      messageRepository.update.mockResolvedValue(updatedMessage);
      createAuditLog.mockResolvedValue({});
      
      const result = await messageService.updateMessage(mockMessage.id, updateData, mockUser);
      
      expect(result).toEqual(updatedMessage);
      expect(messageRepository.update).toHaveBeenCalledWith(mockMessage.id, updateData);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'UPDATE',
        old_values: mockMessage,
        new_values: updatedMessage
      }));
    });
  });

  describe('deleteMessage', () => {
    it('should soft delete message and log audit', async () => {
      const deletedMessage = { ...mockMessage, deleted_at: new Date() };
      messageRepository.findById.mockResolvedValue(mockMessage);
      messageRepository.softDelete.mockResolvedValue(deletedMessage);
      createAuditLog.mockResolvedValue({});
      
      const result = await messageService.deleteMessage(mockMessage.id, mockUser);
      
      expect(result).toEqual(deletedMessage);
      expect(messageRepository.softDelete).toHaveBeenCalledWith(mockMessage.id);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'DELETE',
        old_values: mockMessage
      }));
    });
  });
});
