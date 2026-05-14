/**
 * Conversation controller tests
 *
 * @module tests/modules/conversation/controllers
 * @description Tests for conversation controller layer
 * Per testing.mdc: Mock service, test request/response handling
 */

const conversationController = require('@controllers/conversation/conversation.controller');
const conversationService = require('@services/conversation/conversation.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

// Mock dependencies
jest.mock('@services/conversation/conversation.service');
jest.mock('@lib/response');

describe('Conversation Controller', () => {
  const mockConversation = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    tenant_id: '550e8400-e29b-41d4-a716-446655440001',
    subject: 'Test Conversation'
  };

  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.clearAllMocks();
    mockReq = {
      params: {},
      query: {},
      body: {},
      user: { id: '550e8400-e29b-41d4-a716-446655440002' },
      ip: '127.0.0.1',
      get: jest.fn().mockReturnValue('test-agent')
    };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      send: jest.fn()
    };
  });

  describe('getConversation', () => {
    it('should get conversation by id', async () => {
      mockReq.params.id = mockConversation.id;
      conversationService.getConversationById.mockResolvedValue(mockConversation);
      
      await conversationController.getConversation(mockReq, mockRes);
      
      expect(conversationService.getConversationById).toHaveBeenCalledWith(mockConversation.id);
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.conversation.retrieved', mockConversation);
    });
  });

  describe('listConversations', () => {
    it('should list conversations with default pagination', async () => {
      const mockResult = {
        conversations: [mockConversation],
        total: 1,
        page: 1,
        limit: 20,
        totalPages: 1
      };
      conversationService.listConversations.mockResolvedValue(mockResult);
      
      await conversationController.listConversations(mockReq, mockRes);
      
      expect(conversationService.listConversations).toHaveBeenCalledWith(
        {},
        1,
        20,
        'created_at',
        'desc'
      );
      expect(sendPaginated).toHaveBeenCalled();
    });

    it('should apply filters from query params', async () => {
      mockReq.query = {
        tenant_id: mockConversation.tenant_id,
        subject: 'Test'
      };
      conversationService.listConversations.mockResolvedValue({
        conversations: [],
        total: 0,
        page: 1,
        limit: 20,
        totalPages: 0
      });
      
      await conversationController.listConversations(mockReq, mockRes);
      
      expect(conversationService.listConversations).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: mockConversation.tenant_id,
          subject: expect.any(Object)
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(String),
        expect.any(String)
      );
    });
  });

  describe('createConversation', () => {
    it('should create conversation', async () => {
      mockReq.body = { tenant_id: mockConversation.tenant_id, subject: mockConversation.subject };
      conversationService.createConversation.mockResolvedValue(mockConversation);
      
      await conversationController.createConversation(mockReq, mockRes);
      
      expect(conversationService.createConversation).toHaveBeenCalledWith(
        mockReq.body,
        expect.objectContaining({ id: mockReq.user.id })
      );
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.conversation.created', mockConversation);
    });
  });

  describe('updateConversation', () => {
    it('should update conversation', async () => {
      mockReq.params.id = mockConversation.id;
      mockReq.body = { subject: 'Updated' };
      conversationService.updateConversation.mockResolvedValue(mockConversation);
      
      await conversationController.updateConversation(mockReq, mockRes);
      
      expect(conversationService.updateConversation).toHaveBeenCalledWith(
        mockConversation.id,
        mockReq.body,
        expect.objectContaining({ id: mockReq.user.id })
      );
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.conversation.updated', mockConversation);
    });
  });

  describe('deleteConversation', () => {
    it('should delete conversation', async () => {
      mockReq.params.id = mockConversation.id;
      conversationService.deleteConversation.mockResolvedValue({});
      
      await conversationController.deleteConversation(mockReq, mockRes);
      
      expect(conversationService.deleteConversation).toHaveBeenCalledWith(
        mockConversation.id,
        expect.objectContaining({ id: mockReq.user.id })
      );
      expect(mockRes.status).toHaveBeenCalledWith(204);
      expect(mockRes.send).toHaveBeenCalled();
    });
  });
});
