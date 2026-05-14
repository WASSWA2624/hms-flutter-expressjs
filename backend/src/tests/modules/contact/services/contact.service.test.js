/**
 * Contact service tests
 *
 * @module tests/modules/contact/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');

// Mock dependencies
jest.mock('@repositories/contact/contact.repository');
jest.mock('@lib/audit');

const contactRepository = require('@repositories/contact/contact.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listContacts,
  getContactById,
  createContact,
  updateContact,
  deleteContact
} = require('@services/contact/contact.service');

describe('Contact Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listContacts', () => {
    it('should list contacts with default pagination', async () => {
      const mockContacts = [
        { id: 'contact-1', value: '+1234567890', contact_type: 'PHONE', tenant_id: 'tenant-123' },
        { id: 'contact-2', value: 'user@example.com', contact_type: 'EMAIL', tenant_id: 'tenant-123' }
      ];
      contactRepository.findMany.mockResolvedValue(mockContacts);
      contactRepository.count.mockResolvedValue(10);

      const result = await listContacts({}, 1, 20);

      expect(result.contacts).toEqual(mockContacts);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
      expect(contactRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by tenant_id', async () => {
      const mockContacts = [{ id: 'contact-1', value: '+1234567890' }];
      contactRepository.findMany.mockResolvedValue(mockContacts);
      contactRepository.count.mockResolvedValue(1);

      const result = await listContacts({ tenant_id: 'tenant-123' }, 1, 20);

      expect(result.contacts).toEqual(mockContacts);
      expect(contactRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by contact_type', async () => {
      const mockContacts = [{ id: 'contact-1', contact_type: 'EMAIL' }];
      contactRepository.findMany.mockResolvedValue(mockContacts);
      contactRepository.count.mockResolvedValue(1);

      const result = await listContacts({ contact_type: 'EMAIL' }, 1, 20);

      expect(result.contacts).toEqual(mockContacts);
      expect(contactRepository.findMany).toHaveBeenCalledWith(
        { contact_type: 'EMAIL' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by facility_id', async () => {
      const mockContacts = [{ id: 'contact-1', facility_id: 'facility-123' }];
      contactRepository.findMany.mockResolvedValue(mockContacts);
      contactRepository.count.mockResolvedValue(1);

      const result = await listContacts({ facility_id: 'facility-123' }, 1, 20);

      expect(result.contacts).toEqual(mockContacts);
      expect(contactRepository.findMany).toHaveBeenCalledWith(
        { facility_id: 'facility-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_primary as true', async () => {
      const mockContacts = [{ id: 'contact-1', is_primary: true }];
      contactRepository.findMany.mockResolvedValue(mockContacts);
      contactRepository.count.mockResolvedValue(1);

      const result = await listContacts({ is_primary: 'true' }, 1, 20);

      expect(result.contacts).toEqual(mockContacts);
      expect(contactRepository.findMany).toHaveBeenCalledWith(
        { is_primary: true },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by is_primary as false', async () => {
      const mockContacts = [{ id: 'contact-1', is_primary: false }];
      contactRepository.findMany.mockResolvedValue(mockContacts);
      contactRepository.count.mockResolvedValue(1);

      const result = await listContacts({ is_primary: 'false' }, 1, 20);

      expect(result.contacts).toEqual(mockContacts);
      expect(contactRepository.findMany).toHaveBeenCalledWith(
        { is_primary: false },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by search with contains', async () => {
      const mockContacts = [{ id: 'contact-1', value: 'user@example.com' }];
      contactRepository.findMany.mockResolvedValue(mockContacts);
      contactRepository.count.mockResolvedValue(1);

      const result = await listContacts({ search: 'example' }, 1, 20);

      expect(result.contacts).toEqual(mockContacts);
      expect(contactRepository.findMany).toHaveBeenCalledWith(
        { value: { contains: 'example' } },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should apply pagination correctly', async () => {
      const mockContacts = [{ id: 'contact-1' }];
      contactRepository.findMany.mockResolvedValue(mockContacts);
      contactRepository.count.mockResolvedValue(50);

      const result = await listContacts({}, 3, 10);

      expect(result.pagination).toEqual({
        page: 3,
        limit: 10,
        total: 50,
        totalPages: 5,
        hasNextPage: true,
        hasPreviousPage: true
      });
      expect(contactRepository.findMany).toHaveBeenCalledWith(
        {},
        20,
        10,
        { created_at: 'desc' }
      );
    });

    it('should apply custom sorting', async () => {
      const mockContacts = [];
      contactRepository.findMany.mockResolvedValue(mockContacts);
      contactRepository.count.mockResolvedValue(0);

      await listContacts({}, 1, 20, 'value', 'asc');

      expect(contactRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { value: 'asc' }
      );
    });

    it('should throw HttpError on repository error', async () => {
      contactRepository.findMany.mockRejectedValue(new Error('DB error'));

      await expect(listContacts({}, 1, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('getContactById', () => {
    it('should get contact by ID', async () => {
      const mockContact = {
        id: 'contact-123',
        tenant_id: 'tenant-123',
        contact_type: 'PHONE',
        value: '+1234567890',
        is_primary: true
      };
      contactRepository.findById.mockResolvedValue(mockContact);

      const result = await getContactById('contact-123', 'user-123', '127.0.0.1');

      expect(result).toEqual(mockContact);
      expect(contactRepository.findById).toHaveBeenCalledWith('contact-123');
    });

    it('should throw HttpError if contact not found', async () => {
      contactRepository.findById.mockResolvedValue(null);

      await expect(getContactById('contact-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on repository error', async () => {
      contactRepository.findById.mockRejectedValue(new Error('DB error'));

      await expect(getContactById('contact-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createContact', () => {
    it('should create new contact and log audit', async () => {
      const contactData = {
        tenant_id: 'tenant-123',
        contact_type: 'EMAIL',
        value: 'user@example.com',
        is_primary: true
      };
      const mockContact = {
        id: 'contact-123',
        ...contactData,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19')
      };
      contactRepository.create.mockResolvedValue(mockContact);
      createAuditLog.mockReturnValue(Promise.resolve());

      const result = await createContact(contactData, 'user-123', '127.0.0.1');

      expect(result).toEqual(mockContact);
      expect(contactRepository.create).toHaveBeenCalledWith(contactData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'CREATE',
        entity: 'contact',
        entity_id: 'contact-123',
        diff: { after: mockContact },
        ip_address: '127.0.0.1'
      });
    });

    it('should create contact even if audit log fails', async () => {
      const contactData = {
        tenant_id: 'tenant-123',
        contact_type: 'PHONE',
        value: '+1234567890'
      };
      const mockContact = { id: 'contact-123', ...contactData };
      contactRepository.create.mockResolvedValue(mockContact);
      createAuditLog.mockImplementation(() => Promise.reject(new Error('Audit failed')));

      const result = await createContact(contactData, 'user-123', '127.0.0.1');

      expect(result).toEqual(mockContact);
    });

    it('should throw HttpError on repository error', async () => {
      contactRepository.create.mockRejectedValue(new Error('DB error'));

      await expect(createContact({}, 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('updateContact', () => {
    it('should update contact and log audit', async () => {
      const updateData = { value: 'updated@example.com', is_primary: true };
      const beforeContact = {
        id: 'contact-123',
        value: 'old@example.com',
        is_primary: false
      };
      const updatedContact = {
        id: 'contact-123',
        value: 'updated@example.com',
        is_primary: true
      };
      contactRepository.findById.mockResolvedValue(beforeContact);
      contactRepository.update.mockResolvedValue(updatedContact);
      createAuditLog.mockReturnValue(Promise.resolve());

      const result = await updateContact('contact-123', updateData, 'user-123', '127.0.0.1');

      expect(result).toEqual(updatedContact);
      expect(contactRepository.findById).toHaveBeenCalledWith('contact-123');
      expect(contactRepository.update).toHaveBeenCalledWith('contact-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'UPDATE',
        entity: 'contact',
        entity_id: 'contact-123',
        diff: { before: beforeContact, after: updatedContact },
        ip_address: '127.0.0.1'
      });
    });

    it('should throw HttpError if contact not found', async () => {
      contactRepository.findById.mockResolvedValue(null);

      await expect(updateContact('contact-123', {}, 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should update contact even if audit log fails', async () => {
      const beforeContact = { id: 'contact-123', value: 'old@example.com' };
      const updatedContact = { id: 'contact-123', value: 'updated@example.com' };
      contactRepository.findById.mockResolvedValue(beforeContact);
      contactRepository.update.mockResolvedValue(updatedContact);
      createAuditLog.mockImplementation(() => Promise.reject(new Error('Audit failed')));

      const result = await updateContact('contact-123', { value: 'updated@example.com' }, 'user-123', '127.0.0.1');

      expect(result).toEqual(updatedContact);
    });

    it('should throw HttpError on repository error', async () => {
      contactRepository.findById.mockResolvedValue({ id: 'contact-123' });
      contactRepository.update.mockRejectedValue(new Error('DB error'));

      await expect(updateContact('contact-123', {}, 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('deleteContact', () => {
    it('should soft delete contact and log audit', async () => {
      const beforeContact = {
        id: 'contact-123',
        tenant_id: 'tenant-123',
        contact_type: 'EMAIL',
        value: 'user@example.com'
      };
      contactRepository.findById.mockResolvedValue(beforeContact);
      contactRepository.softDelete.mockResolvedValue();
      createAuditLog.mockReturnValue(Promise.resolve());

      await deleteContact('contact-123', 'user-123', '127.0.0.1');

      expect(contactRepository.findById).toHaveBeenCalledWith('contact-123');
      expect(contactRepository.softDelete).toHaveBeenCalledWith('contact-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'DELETE',
        entity: 'contact',
        entity_id: 'contact-123',
        diff: { before: beforeContact },
        ip_address: '127.0.0.1'
      });
    });

    it('should throw HttpError if contact not found', async () => {
      contactRepository.findById.mockResolvedValue(null);

      await expect(deleteContact('contact-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });

    it('should delete contact even if audit log fails', async () => {
      const beforeContact = { id: 'contact-123', value: 'user@example.com' };
      contactRepository.findById.mockResolvedValue(beforeContact);
      contactRepository.softDelete.mockResolvedValue();
      createAuditLog.mockImplementation(() => Promise.reject(new Error('Audit failed')));

      await expect(deleteContact('contact-123', 'user-123', '127.0.0.1'))
        .resolves
        .not
        .toThrow();
    });

    it('should throw HttpError on repository error', async () => {
      contactRepository.findById.mockResolvedValue({ id: 'contact-123' });
      contactRepository.softDelete.mockRejectedValue(new Error('DB error'));

      await expect(deleteContact('contact-123', 'user-123', '127.0.0.1'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
