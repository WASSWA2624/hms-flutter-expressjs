/**
 * Contact controller tests
 *
 * @module tests/modules/contact/controllers
 * Per testing.mdc: Mock all service dependencies
 */

// Mock dependencies
jest.mock('@services/contact/contact.service');
jest.mock('@lib/response');

const contactService = require('@services/contact/contact.service');
const { sendSuccess, sendPaginated, sendNoContent } = require('@lib/response');
const {
  listContacts,
  getContactById,
  createContact,
  updateContact,
  deleteContact
} = require('@controllers/contact/contact.controller');

describe('Contact Controller', () => {
  let req, res;

  beforeEach(() => {
    jest.clearAllMocks();
    req = {
      query: {},
      params: {},
      body: {},
      user: {
        id: 'user-123',
        tenant_id: 'tenant-123'
      },
      ip: '192.168.1.1',
      get: jest.fn((header) => {
        if (header === 'user-agent') return 'Mozilla/5.0';
        return null;
      })
    };
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis()
    };
  });

  describe('listContacts', () => {
    it('should list contacts with default pagination', async () => {
      const mockResult = {
        contacts: [
          { id: 'contact-1', value: '+1234567890', contact_type: 'PHONE', tenant_id: 'tenant-123' },
          { id: 'contact-2', value: 'user@example.com', contact_type: 'EMAIL', tenant_id: 'tenant-123' }
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
      contactService.listContacts.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listContacts(req, res);

      expect(contactService.listContacts).toHaveBeenCalledWith(
        {},
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '192.168.1.1'
      );
      expect(sendPaginated).toHaveBeenCalledWith(
        res,
        'messages.contact.list.success',
        mockResult.contacts,
        mockResult.pagination
      );
    });

    it('should list contacts with filters', async () => {
      const mockResult = {
        contacts: [{ id: 'contact-1', value: '+1234567890' }],
        pagination: {
          page: 1,
          limit: 20,
          total: 1,
          totalPages: 1,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      contactService.listContacts.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        tenant_id: 'tenant-123',
        contact_type: 'PHONE',
        facility_id: 'facility-123',
        is_primary: 'true',
        search: '1234'
      };

      await listContacts(req, res);

      expect(contactService.listContacts).toHaveBeenCalledWith(
        {
          tenant_id: 'tenant-123',
          contact_type: 'PHONE',
          facility_id: 'facility-123',
          is_primary: 'true',
          search: '1234'
        },
        1,
        20,
        undefined,
        'asc',
        'user-123',
        '192.168.1.1'
      );
    });

    it('should list contacts with sorting', async () => {
      const mockResult = {
        contacts: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      contactService.listContacts.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = {
        page: 1,
        limit: 20,
        sort_by: 'value',
        order: 'desc'
      };

      await listContacts(req, res);

      expect(contactService.listContacts).toHaveBeenCalledWith(
        {},
        1,
        20,
        'value',
        'desc',
        'user-123',
        '192.168.1.1'
      );
    });

    it('should handle missing user context', async () => {
      req.user = undefined;
      const mockResult = {
        contacts: [],
        pagination: {
          page: 1,
          limit: 20,
          total: 0,
          totalPages: 0,
          hasNextPage: false,
          hasPreviousPage: false
        }
      };
      contactService.listContacts.mockResolvedValue(mockResult);
      sendPaginated.mockImplementation((res, message, data, pagination) => {
        res.status(200).json({ message, data, pagination });
      });

      req.query = { page: 1, limit: 20 };

      await listContacts(req, res);

      expect(contactService.listContacts).toHaveBeenCalledWith(
        {},
        1,
        20,
        undefined,
        'asc',
        undefined,
        '192.168.1.1'
      );
    });
  });

  describe('getContactById', () => {
    it('should get contact by ID', async () => {
      const mockContact = {
        id: 'contact-123',
        tenant_id: 'tenant-123',
        contact_type: 'EMAIL',
        value: 'user@example.com',
        is_primary: true
      };
      contactService.getContactById.mockResolvedValue(mockContact);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'contact-123' };

      await getContactById(req, res);

      expect(contactService.getContactById).toHaveBeenCalledWith(
        'contact-123',
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.contact.get.success',
        mockContact
      );
    });

    it('should handle missing user context', async () => {
      req.user = undefined;
      const mockContact = { id: 'contact-123', value: 'user@example.com' };
      contactService.getContactById.mockResolvedValue(mockContact);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'contact-123' };

      await getContactById(req, res);

      expect(contactService.getContactById).toHaveBeenCalledWith(
        'contact-123',
        undefined,
        '192.168.1.1'
      );
    });
  });

  describe('createContact', () => {
    it('should create new contact', async () => {
      const contactData = {
        tenant_id: 'tenant-123',
        contact_type: 'PHONE',
        value: '+1234567890',
        is_primary: true
      };
      const mockContact = {
        id: 'contact-123',
        ...contactData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19')
      };
      contactService.createContact.mockResolvedValue(mockContact);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = contactData;

      await createContact(req, res);

      expect(contactService.createContact).toHaveBeenCalledWith(
        contactData,
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        201,
        'messages.contact.create.success',
        mockContact
      );
    });

    it('should create contact with minimal data', async () => {
      const contactData = {
        tenant_id: 'tenant-123',
        contact_type: 'EMAIL',
        value: 'user@example.com'
      };
      const mockContact = { id: 'contact-123', ...contactData };
      contactService.createContact.mockResolvedValue(mockContact);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = contactData;

      await createContact(req, res);

      expect(contactService.createContact).toHaveBeenCalledWith(
        contactData,
        'user-123',
        '192.168.1.1'
      );
    });

    it('should handle missing user context', async () => {
      req.user = undefined;
      const contactData = {
        tenant_id: 'tenant-123',
        contact_type: 'PHONE',
        value: '+1234567890'
      };
      const mockContact = { id: 'contact-123', ...contactData };
      contactService.createContact.mockResolvedValue(mockContact);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.body = contactData;

      await createContact(req, res);

      expect(contactService.createContact).toHaveBeenCalledWith(
        contactData,
        undefined,
        '192.168.1.1'
      );
    });
  });

  describe('updateContact', () => {
    it('should update contact', async () => {
      const updateData = {
        value: 'updated@example.com',
        is_primary: true
      };
      const mockContact = {
        id: 'contact-123',
        tenant_id: 'tenant-123',
        contact_type: 'EMAIL',
        value: 'updated@example.com',
        is_primary: true,
        updated_at: new Date('2026-01-19')
      };
      contactService.updateContact.mockResolvedValue(mockContact);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'contact-123' };
      req.body = updateData;

      await updateContact(req, res);

      expect(contactService.updateContact).toHaveBeenCalledWith(
        'contact-123',
        updateData,
        'user-123',
        '192.168.1.1'
      );
      expect(sendSuccess).toHaveBeenCalledWith(
        res,
        200,
        'messages.contact.update.success',
        mockContact
      );
    });

    it('should update with partial data', async () => {
      const updateData = { is_primary: false };
      const mockContact = {
        id: 'contact-123',
        is_primary: false
      };
      contactService.updateContact.mockResolvedValue(mockContact);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'contact-123' };
      req.body = updateData;

      await updateContact(req, res);

      expect(contactService.updateContact).toHaveBeenCalledWith(
        'contact-123',
        updateData,
        'user-123',
        '192.168.1.1'
      );
    });

    it('should handle missing user context', async () => {
      req.user = undefined;
      const updateData = { value: 'test@example.com' };
      const mockContact = { id: 'contact-123', value: 'test@example.com' };
      contactService.updateContact.mockResolvedValue(mockContact);
      sendSuccess.mockImplementation((res, status, message, data) => {
        res.status(status).json({ message, data });
      });

      req.params = { id: 'contact-123' };
      req.body = updateData;

      await updateContact(req, res);

      expect(contactService.updateContact).toHaveBeenCalledWith(
        'contact-123',
        updateData,
        undefined,
        '192.168.1.1'
      );
    });
  });

  describe('deleteContact', () => {
    it('should delete contact', async () => {
      contactService.deleteContact.mockResolvedValue();
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'contact-123' };

      await deleteContact(req, res);

      expect(contactService.deleteContact).toHaveBeenCalledWith(
        'contact-123',
        'user-123',
        '192.168.1.1'
      );
      expect(sendNoContent).toHaveBeenCalledWith(res);
    });

    it('should handle missing user context', async () => {
      req.user = undefined;
      contactService.deleteContact.mockResolvedValue();
      sendNoContent.mockImplementation((res) => {
        res.status(204).send();
      });

      req.params = { id: 'contact-123' };

      await deleteContact(req, res);

      expect(contactService.deleteContact).toHaveBeenCalledWith(
        'contact-123',
        undefined,
        '192.168.1.1'
      );
    });
  });
});
