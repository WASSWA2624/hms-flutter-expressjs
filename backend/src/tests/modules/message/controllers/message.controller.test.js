/**
 * Message controller tests
 *
 * @module tests/modules/message/controllers
 * @description Tests for message controller layer
 * Per testing.mdc: Mock service, test request/response handling
 */

const messageController = require('@controllers/message/message.controller');
const messageService = require('@services/message/message.service');
const { sendSuccess, sendPaginated } = require('@lib/response');

// Mock dependencies
jest.mock('@services/message/message.service');
jest.mock('@lib/response');

describe('Message Controller', () => {
  const mockMessage = {
    id: '550e8400-e29b-41d4-a716-446655440000',
    conversation_id: '550e8400-e29b-41d4-a716-446655440001',
    content: 'Test message'
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

  describe('getMessage', () => {
    it('should get message by id', async () => {
      mockReq.params.id = mockMessage.id;
      messageService.getMessageById.mockResolvedValue(mockMessage);
      
      await messageController.getMessage(mockReq, mockRes);
      
      expect(messageService.getMessageById).toHaveBeenCalledWith(mockMessage.id);
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.message.retrieved', mockMessage);
    });
  });

  describe('listMessages', () => {
    it('should list messages with default pagination', async () => {
      const mockResult = {
        messages: [mockMessage],
        total: 1,
        page: 1,
        limit: 20,
        totalPages: 1
      };
      messageService.listMessages.mockResolvedValue(mockResult);
      
      await messageController.listMessages(mockReq, mockRes);
      
      expect(messageService.listMessages).toHaveBeenCalledWith(
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
        conversation_id: mockMessage.conversation_id,
        search: 'test'
      };
      messageService.listMessages.mockResolvedValue({
        messages: [],
        total: 0,
        page: 1,
        limit: 20,
        totalPages: 0
      });
      
      await messageController.listMessages(mockReq, mockRes);
      
      expect(messageService.listMessages).toHaveBeenCalledWith(
        expect.objectContaining({
          conversation_id: mockMessage.conversation_id,
          search: 'test'
        }),
        expect.any(Number),
        expect.any(Number),
        expect.any(String),
        expect.any(String)
      );
    });
  });

  describe('getMessagesByConversation', () => {
    it('should get messages by conversation id', async () => {
      mockReq.params.conversationId = mockMessage.conversation_id;
      const mockResult = {
        messages: [mockMessage],
        total: 1,
        page: 1,
        limit: 20,
        totalPages: 1
      };
      messageService.listMessages.mockResolvedValue(mockResult);
      
      await messageController.getMessagesByConversation(mockReq, mockRes);
      
      expect(messageService.listMessages).toHaveBeenCalledWith(
        expect.objectContaining({ conversation_id: mockMessage.conversation_id }),
        1,
        20,
        'created_at',
        'desc'
      );
      expect(sendPaginated).toHaveBeenCalled();
    });
  });

  describe('createMessage', () => {
    it('should create message', async () => {
      mockReq.body = { conversation_id: mockMessage.conversation_id, content: mockMessage.content };
      messageService.createMessage.mockResolvedValue(mockMessage);
      
      await messageController.createMessage(mockReq, mockRes);
      
      expect(messageService.createMessage).toHaveBeenCalledWith(
        mockReq.body,
        expect.objectContaining({ id: mockReq.user.id })
      );
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 201, 'messages.message.created', mockMessage);
    });
  });

  describe('updateMessage', () => {
    it('should update message', async () => {
      mockReq.params.id = mockMessage.id;
      mockReq.body = { content: 'Updated' };
      messageService.updateMessage.mockResolvedValue(mockMessage);
      
      await messageController.updateMessage(mockReq, mockRes);
      
      expect(messageService.updateMessage).toHaveBeenCalledWith(
        mockMessage.id,
        mockReq.body,
        expect.objectContaining({ id: mockReq.user.id })
      );
      expect(sendSuccess).toHaveBeenCalledWith(mockRes, 200, 'messages.message.updated', mockMessage);
    });
  });

  describe('deleteMessage', () => {
    it('should delete message', async () => {
      mockReq.params.id = mockMessage.id;
      messageService.deleteMessage.mockResolvedValue({});
      
      await messageController.deleteMessage(mockReq, mockRes);
      
      expect(messageService.deleteMessage).toHaveBeenCalledWith(
        mockMessage.id,
        expect.objectContaining({ id: mockReq.user.id })
      );
      expect(mockRes.status).toHaveBeenCalledWith(204);
      expect(mockRes.send).toHaveBeenCalled();
    });
  });
});
