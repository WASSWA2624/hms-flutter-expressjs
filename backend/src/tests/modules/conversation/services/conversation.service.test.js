/**
 * Conversation service tests
 *
 * @module tests/modules/conversation/services
 * @description Tests for conversation service layer
 * Per testing.mdc: Mock repository, test business logic
 */

const conversationService = require('@services/conversation/conversation.service');
const conversationRepository = require('@repositories/conversation/conversation.repository');
const { createAuditLog } = require('@lib/audit');
const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/conversation/conversation.repository');
jest.mock('@lib/audit');

describe('Conversation Service', () => {
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

  const mockUser = {
    id: '550e8400-e29b-41d4-a716-446655440003',
    ip: '127.0.0.1',
    user_agent: 'test-agent'
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('getConversationById', () => {
    it('should return conversation if found', async () => {
      conversationRepository.findById.mockResolvedValue(mockConversation);
      
      const result = await conversationService.getConversationById(mockConversation.id);
      
      expect(result).toEqual(mockConversation);
      expect(conversationRepository.findById).toHaveBeenCalledWith(mockConversation.id, {});
    });

    it('should throw error if conversation not found', async () => {
      conversationRepository.findById.mockResolvedValue(null);
      
      await expect(conversationService.getConversationById('non-existent'))
        .rejects.toThrow(HttpError);
    });
  });

  describe('listConversations', () => {
    it('should list conversations with pagination', async () => {
      const mockConversations = [mockConversation];
      conversationRepository.findMany.mockResolvedValue(mockConversations);
      conversationRepository.count.mockResolvedValue(1);
      
      const result = await conversationService.listConversations({}, 1, 20);
      
      expect(result).toEqual({
        conversations: mockConversations,
        total: 1,
        page: 1,
        limit: 20,
        totalPages: 1
      });
    });

    it('should handle search filter', async () => {
      conversationRepository.findMany.mockResolvedValue([]);
      conversationRepository.count.mockResolvedValue(0);
      
      await conversationService.listConversations({ search: 'test' }, 1, 20);
      
      expect(conversationRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            expect.objectContaining({ subject: expect.any(Object) })
          ])
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(Object),
        expect.any(Object)
      );
    });
  });

  describe('createConversation', () => {
    it('should create conversation and log audit', async () => {
      const newData = { tenant_id: mockConversation.tenant_id, subject: mockConversation.subject };
      conversationRepository.create.mockResolvedValue(mockConversation);
      createAuditLog.mockResolvedValue({});
      
      const result = await conversationService.createConversation(newData, mockUser);
      
      expect(result).toEqual(mockConversation);
      expect(conversationRepository.create).toHaveBeenCalledWith(newData);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        user_id: mockUser.id,
        action: 'CREATE',
        entity: 'conversation',
        entity_id: mockConversation.id
      }));
    });

    it('should not fail if audit log fails', async () => {
      conversationRepository.create.mockResolvedValue(mockConversation);
      createAuditLog.mockRejectedValue(new Error('Audit error'));
      
      const result = await conversationService.createConversation({}, mockUser);
      
      expect(result).toEqual(mockConversation);
    });
  });

  describe('updateConversation', () => {
    it('should update conversation and log audit', async () => {
      const updateData = { subject: 'Updated' };
      const updatedConversation = { ...mockConversation, ...updateData };
      conversationRepository.findById.mockResolvedValue(mockConversation);
      conversationRepository.update.mockResolvedValue(updatedConversation);
      createAuditLog.mockResolvedValue({});
      
      const result = await conversationService.updateConversation(mockConversation.id, updateData, mockUser);
      
      expect(result).toEqual(updatedConversation);
      expect(conversationRepository.update).toHaveBeenCalledWith(mockConversation.id, updateData);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'UPDATE',
        old_values: mockConversation,
        new_values: updatedConversation
      }));
    });
  });

  describe('deleteConversation', () => {
    it('should soft delete conversation and log audit', async () => {
      const deletedConversation = { ...mockConversation, deleted_at: new Date() };
      conversationRepository.findById.mockResolvedValue(mockConversation);
      conversationRepository.softDelete.mockResolvedValue(deletedConversation);
      createAuditLog.mockResolvedValue({});
      
      const result = await conversationService.deleteConversation(mockConversation.id, mockUser);
      
      expect(result).toEqual(deletedConversation);
      expect(conversationRepository.softDelete).toHaveBeenCalledWith(mockConversation.id);
      expect(createAuditLog).toHaveBeenCalledWith(expect.objectContaining({
        action: 'DELETE',
        old_values: mockConversation
      }));
    });
  });
});
