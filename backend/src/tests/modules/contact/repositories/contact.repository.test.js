/**
 * Contact repository tests
 *
 * @module tests/modules/contact/repositories
 * Per testing.mdc: Mock all Prisma operations
 */

const { HttpError } = require('@lib/errors');

// Mock Prisma instance before requiring the repository
jest.mock('@prisma/client', () => ({
  contact: {
    findFirst: jest.fn(),
    findMany: jest.fn(),
    count: jest.fn(),
    create: jest.fn(),
    update: jest.fn()
  }
}));

const {
  findById,
  findMany,
  count,
  create,
  update,
  softDelete
} = require('@repositories/contact/contact.repository');

const prisma = require('@prisma/client');

describe('Contact Repository', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('findById', () => {
    it('should find contact by ID', async () => {
      const mockContact = {
        id: 'contact-123',
        tenant_id: 'tenant-123',
        contact_type: 'PHONE',
        value: '+1234567890',
        is_primary: true,
        facility_id: null,
        branch_id: null,
        patient_id: null,
        user_profile_id: null,
        staff_profile_id: null,
        supplier_id: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.contact.findFirst.mockResolvedValue(mockContact);

      const result = await findById('contact-123');

      expect(result).toEqual(mockContact);
      expect(prisma.contact.findFirst).toHaveBeenCalledWith({
        where: {
          id: 'contact-123',
          deleted_at: null
        }
      });
    });

    it('should return null if contact not found', async () => {
      prisma.contact.findFirst.mockResolvedValue(null);

      const result = await findById('contact-123');

      expect(result).toBeNull();
    });

    it('should throw HttpError on database error', async () => {
      prisma.contact.findFirst.mockRejectedValue(new Error('DB error'));

      await expect(findById('contact-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('findMany', () => {
    it('should find many contacts with default pagination', async () => {
      const mockContacts = [
        {
          id: 'contact-1',
          tenant_id: 'tenant-123',
          contact_type: 'PHONE',
          value: '+1234567890',
          is_primary: true
        },
        {
          id: 'contact-2',
          tenant_id: 'tenant-123',
          contact_type: 'EMAIL',
          value: 'user@example.com',
          is_primary: false
        }
      ];
      prisma.contact.findMany.mockResolvedValue(mockContacts);

      const result = await findMany({}, 0, 20);

      expect(result).toEqual(mockContacts);
      expect(prisma.contact.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find contacts with filters', async () => {
      const mockContacts = [
        {
          id: 'contact-1',
          tenant_id: 'tenant-123',
          contact_type: 'PHONE',
          value: '+1234567890',
          is_primary: true
        }
      ];
      prisma.contact.findMany.mockResolvedValue(mockContacts);

      const result = await findMany({ 
        tenant_id: 'tenant-123', 
        contact_type: 'PHONE',
        is_primary: true
      }, 0, 10);

      expect(result).toEqual(mockContacts);
      expect(prisma.contact.findMany).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          contact_type: 'PHONE',
          is_primary: true
        },
        skip: 0,
        take: 10,
        orderBy: { created_at: 'desc' }
      });
    });

    it('should find contacts with custom sort order', async () => {
      const mockContacts = [];
      prisma.contact.findMany.mockResolvedValue(mockContacts);

      await findMany({}, 0, 20, { value: 'asc' });

      expect(prisma.contact.findMany).toHaveBeenCalledWith({
        where: { deleted_at: null },
        skip: 0,
        take: 20,
        orderBy: { value: 'asc' }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.contact.findMany.mockRejectedValue(new Error('DB error'));

      await expect(findMany({}, 0, 20))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('count', () => {
    it('should count contacts without filters', async () => {
      prisma.contact.count.mockResolvedValue(42);

      const result = await count({});

      expect(result).toBe(42);
      expect(prisma.contact.count).toHaveBeenCalledWith({
        where: { deleted_at: null }
      });
    });

    it('should count contacts with filters', async () => {
      prisma.contact.count.mockResolvedValue(5);

      const result = await count({ 
        tenant_id: 'tenant-123',
        contact_type: 'EMAIL'
      });

      expect(result).toBe(5);
      expect(prisma.contact.count).toHaveBeenCalledWith({
        where: {
          deleted_at: null,
          tenant_id: 'tenant-123',
          contact_type: 'EMAIL'
        }
      });
    });

    it('should throw HttpError on database error', async () => {
      prisma.contact.count.mockRejectedValue(new Error('DB error'));

      await expect(count({}))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('create', () => {
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
        facility_id: null,
        branch_id: null,
        patient_id: null,
        user_profile_id: null,
        staff_profile_id: null,
        supplier_id: null,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19'),
        deleted_at: null,
        version: 1
      };
      prisma.contact.create.mockResolvedValue(mockContact);

      const result = await create(contactData);

      expect(result).toEqual(mockContact);
      expect(prisma.contact.create).toHaveBeenCalledWith({
        data: contactData
      });
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const contactData = {
        tenant_id: 'tenant-123',
        contact_type: 'EMAIL',
        value: 'duplicate@example.com'
      };
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['value'] };
      prisma.contact.create.mockRejectedValue(error);

      await expect(create(contactData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const contactData = {
        tenant_id: 'invalid-tenant',
        contact_type: 'PHONE',
        value: '+1234567890'
      };
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'tenant_id' };
      prisma.contact.create.mockRejectedValue(error);

      await expect(create(contactData))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      const contactData = {
        tenant_id: 'tenant-123',
        contact_type: 'PHONE',
        value: '+1234567890'
      };
      prisma.contact.create.mockRejectedValue(new Error('DB error'));

      await expect(create(contactData))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('update', () => {
    it('should update contact', async () => {
      const updateData = {
        value: 'updated@example.com',
        is_primary: true
      };
      const mockUpdatedContact = {
        id: 'contact-123',
        tenant_id: 'tenant-123',
        contact_type: 'EMAIL',
        value: 'updated@example.com',
        is_primary: true,
        updated_at: new Date('2026-01-19')
      };
      prisma.contact.update.mockResolvedValue(mockUpdatedContact);

      const result = await update('contact-123', updateData);

      expect(result).toEqual(mockUpdatedContact);
      expect(prisma.contact.update).toHaveBeenCalledWith({
        where: { id: 'contact-123' },
        data: updateData
      });
    });

    it('should throw HttpError if contact not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.contact.update.mockRejectedValue(error);

      await expect(update('contact-123', { value: 'test@example.com' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on unique constraint violation', async () => {
      const error = new Error('Unique constraint failed');
      error.code = 'P2002';
      error.meta = { target: ['value'] };
      prisma.contact.update.mockRejectedValue(error);

      await expect(update('contact-123', { value: 'duplicate@example.com' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on foreign key constraint violation', async () => {
      const error = new Error('Foreign key constraint failed');
      error.code = 'P2003';
      error.meta = { field_name: 'facility_id' };
      prisma.contact.update.mockRejectedValue(error);

      await expect(update('contact-123', { facility_id: 'invalid-id' }))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.contact.update.mockRejectedValue(new Error('DB error'));

      await expect(update('contact-123', { value: 'test@example.com' }))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('softDelete', () => {
    it('should soft delete contact', async () => {
      const mockDeletedContact = {
        id: 'contact-123',
        tenant_id: 'tenant-123',
        contact_type: 'EMAIL',
        value: 'user@example.com',
        deleted_at: new Date('2026-01-19')
      };
      prisma.contact.update.mockResolvedValue(mockDeletedContact);

      const result = await softDelete('contact-123');

      expect(result).toEqual(mockDeletedContact);
      expect(prisma.contact.update).toHaveBeenCalledWith({
        where: { id: 'contact-123' },
        data: {
          deleted_at: expect.any(Date)
        }
      });
    });

    it('should throw HttpError if contact not found', async () => {
      const error = new Error('Record not found');
      error.code = 'P2025';
      prisma.contact.update.mockRejectedValue(error);

      await expect(softDelete('contact-123'))
        .rejects
        .toThrow(HttpError);
    });

    it('should throw HttpError on database error', async () => {
      prisma.contact.update.mockRejectedValue(new Error('DB error'));

      await expect(softDelete('contact-123'))
        .rejects
        .toThrow(HttpError);
    });
  });
});
