/**
 * Adverse Event service tests
 *
 * @module tests/modules/adverse-event/services
 * Per testing.mdc: Mock all external dependencies
 */

// Mock dependencies
jest.mock('@repositories/adverse-event/adverse-event.repository');
jest.mock('@lib/audit');

const adverseEventRepository = require('@repositories/adverse-event/adverse-event.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listAdverseEvents,
  getAdverseEventById,
  createAdverseEvent,
  updateAdverseEvent,
  deleteAdverseEvent
} = require('@services/adverse-event/adverse-event.service');

describe('Adverse Event Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('listAdverseEvents', () => {
    it('should list adverse events with default pagination', async () => {
      const mockAdverseEvents = [
        { id: 'event-1', patient_id: 'patient-123', severity: 'MILD' },
        { id: 'event-2', patient_id: 'patient-123', severity: 'SEVERE' }
      ];
      adverseEventRepository.findMany.mockResolvedValue(mockAdverseEvents);
      adverseEventRepository.count.mockResolvedValue(10);

      const result = await listAdverseEvents({}, 1, 20);

      expect(result.items).toEqual(mockAdverseEvents);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should filter by patient_id', async () => {
      const mockAdverseEvents = [{ id: 'event-1', patient_id: 'patient-123' }];
      adverseEventRepository.findMany.mockResolvedValue(mockAdverseEvents);
      adverseEventRepository.count.mockResolvedValue(1);

      await listAdverseEvents({ patient_id: 'patient-123' }, 1, 20);

      expect(adverseEventRepository.findMany).toHaveBeenCalledWith(
        { patient_id: 'patient-123' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by severity', async () => {
      const mockAdverseEvents = [{ id: 'event-1', severity: 'SEVERE' }];
      adverseEventRepository.findMany.mockResolvedValue(mockAdverseEvents);
      adverseEventRepository.count.mockResolvedValue(1);

      await listAdverseEvents({ severity: 'SEVERE' }, 1, 20);

      expect(adverseEventRepository.findMany).toHaveBeenCalledWith(
        { severity: 'SEVERE' },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should filter by date range', async () => {
      const mockAdverseEvents = [{ id: 'event-1' }];
      adverseEventRepository.findMany.mockResolvedValue(mockAdverseEvents);
      adverseEventRepository.count.mockResolvedValue(1);

      await listAdverseEvents({
        reported_at_from: '2026-01-01',
        reported_at_to: '2026-12-31'
      }, 1, 20);

      expect(adverseEventRepository.findMany).toHaveBeenCalledWith(
        {
          reported_at: {
            gte: new Date('2026-01-01'),
            lte: new Date('2026-12-31')
          }
        },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should handle search query', async () => {
      const mockAdverseEvents = [{ id: 'event-1' }];
      adverseEventRepository.findMany.mockResolvedValue(mockAdverseEvents);
      adverseEventRepository.count.mockResolvedValue(1);

      await listAdverseEvents({ search: 'headache' }, 1, 20);

      expect(adverseEventRepository.findMany).toHaveBeenCalledWith(
        { description: { contains: 'headache', mode: 'insensitive' } },
        0,
        20,
        { created_at: 'desc' }
      );
    });

    it('should calculate pagination correctly', async () => {
      const mockAdverseEvents = [];
      adverseEventRepository.findMany.mockResolvedValue(mockAdverseEvents);
      adverseEventRepository.count.mockResolvedValue(45);

      const result = await listAdverseEvents({}, 2, 20);

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 45,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true
      });
    });
  });

  describe('getAdverseEventById', () => {
    it('should get adverse event by ID', async () => {
      const mockAdverseEvent = { id: 'event-123', severity: 'MODERATE' };
      adverseEventRepository.findById.mockResolvedValue(mockAdverseEvent);

      const result = await getAdverseEventById('event-123');

      expect(result).toEqual(mockAdverseEvent);
      expect(adverseEventRepository.findById).toHaveBeenCalledWith('event-123');
    });

    it('should return null if adverse event not found', async () => {
      adverseEventRepository.findById.mockResolvedValue(null);

      const result = await getAdverseEventById('event-123');

      expect(result).toBeNull();
    });
  });

  describe('createAdverseEvent', () => {
    it('should create adverse event and log audit', async () => {
      const newAdverseEvent = {
        patient_id: 'patient-123',
        severity: 'MODERATE',
        description: 'Test'
      };
      const mockCreatedAdverseEvent = {
        id: 'event-123',
        ...newAdverseEvent,
        created_at: new Date('2026-01-19'),
        updated_at: new Date('2026-01-19')
      };
      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };

      adverseEventRepository.create.mockResolvedValue(mockCreatedAdverseEvent);
      createAuditLog.mockResolvedValue({});

      const result = await createAdverseEvent(newAdverseEvent, auditContext);

      expect(result).toEqual(mockCreatedAdverseEvent);
      expect(adverseEventRepository.create).toHaveBeenCalledWith(newAdverseEvent);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'CREATE',
        entity: 'adverse_event',
        entity_id: 'event-123',
        diff: { after: mockCreatedAdverseEvent },
        ip: '127.0.0.1'
      });
    });
  });

  describe('updateAdverseEvent', () => {
    it('should update adverse event and log audit', async () => {
      const beforeAdverseEvent = {
        id: 'event-123',
        severity: 'MILD'
      };
      const updateData = { severity: 'SEVERE', description: 'Updated' };
      const afterAdverseEvent = {
        id: 'event-123',
        severity: 'SEVERE',
        description: 'Updated'
      };
      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };

      adverseEventRepository.findById.mockResolvedValue(beforeAdverseEvent);
      adverseEventRepository.update.mockResolvedValue(afterAdverseEvent);
      createAuditLog.mockResolvedValue({});

      const result = await updateAdverseEvent('event-123', updateData, auditContext);

      expect(result).toEqual(afterAdverseEvent);
      expect(adverseEventRepository.findById).toHaveBeenCalledWith('event-123');
      expect(adverseEventRepository.update).toHaveBeenCalledWith('event-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'UPDATE',
        entity: 'adverse_event',
        entity_id: 'event-123',
        diff: { before: beforeAdverseEvent, after: afterAdverseEvent },
        ip: '127.0.0.1'
      });
    });
  });

  describe('deleteAdverseEvent', () => {
    it('should soft delete adverse event and log audit', async () => {
      const beforeAdverseEvent = {
        id: 'event-123',
        severity: 'MODERATE',
        deleted_at: null
      };
      const afterAdverseEvent = {
        id: 'event-123',
        severity: 'MODERATE',
        deleted_at: new Date('2026-01-19')
      };
      const auditContext = { user_id: 'user-123', ip: '127.0.0.1' };

      adverseEventRepository.findById.mockResolvedValue(beforeAdverseEvent);
      adverseEventRepository.softDelete.mockResolvedValue(afterAdverseEvent);
      createAuditLog.mockResolvedValue({});

      const result = await deleteAdverseEvent('event-123', auditContext);

      expect(result).toEqual(afterAdverseEvent);
      expect(adverseEventRepository.findById).toHaveBeenCalledWith('event-123');
      expect(adverseEventRepository.softDelete).toHaveBeenCalledWith('event-123');
      expect(createAuditLog).toHaveBeenCalledWith({
        user_id: 'user-123',
        action: 'DELETE',
        entity: 'adverse_event',
        entity_id: 'event-123',
        diff: { before: beforeAdverseEvent, after: afterAdverseEvent },
        ip: '127.0.0.1'
      });
    });
  });
});
