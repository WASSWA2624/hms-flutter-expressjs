/**
 * Visit queue service tests
 *
 * @module tests/modules/visit-queue/services
 * Per testing.mdc: Mock all external dependencies
 */

const { HttpError } = require('@lib/errors');
const {
  resolveModelIdByIdentifier,
  resolveModelRecordByIdentifier,
} = require('@lib/identifiers/resolve-entity-id');

// Mock dependencies
jest.mock('@repositories/visit-queue/visit-queue.repository');
jest.mock('@lib/audit');
jest.mock('@lib/identifiers/resolve-entity-id', () => ({
  resolveModelIdByIdentifier: jest.fn(),
  resolveModelRecordByIdentifier: jest.fn(),
}));

const visitQueueRepository = require('@repositories/visit-queue/visit-queue.repository');
const { createAuditLog } = require('@lib/audit');
const {
  listVisitQueues,
  getVisitQueueById,
  createVisitQueue,
  updateVisitQueue,
  deleteVisitQueue
} = require('@services/visit-queue/visit-queue.service');

describe('Visit Queue Service', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    resolveModelIdByIdentifier.mockImplementation(async ({ identifier }) => identifier);
    resolveModelRecordByIdentifier.mockImplementation(async ({ identifier }) =>
      identifier ? { id: identifier } : null
    );
  });

  describe('listVisitQueues', () => {
    it('should list visit queue entries with default pagination', async () => {
      const mockEntries = [
        { id: 'queue-1', patient_id: 'patient-123', status: 'SCHEDULED' },
        { id: 'queue-2', patient_id: 'patient-456', status: 'CONFIRMED' }
      ];
      visitQueueRepository.findMany.mockResolvedValue(mockEntries);
      visitQueueRepository.count.mockResolvedValue(10);

      const result = await listVisitQueues({}, 1, 20);

      expect(result.entries).toEqual(mockEntries);
      expect(result.pagination).toEqual({
        page: 1,
        limit: 20,
        total: 10,
        totalPages: 1,
        hasNextPage: false,
        hasPreviousPage: false
      });
    });

    it('should filter by tenant_id', async () => {
      const mockEntries = [{ id: 'queue-1', tenant_id: 'tenant-123' }];
      visitQueueRepository.findMany.mockResolvedValue(mockEntries);
      visitQueueRepository.count.mockResolvedValue(1);

      await listVisitQueues({ tenant_id: 'tenant-123' }, 1, 20);

      expect(visitQueueRepository.findMany).toHaveBeenCalledWith(
        { tenant_id: 'tenant-123' },
        0,
        20,
        { queued_at: 'desc' }
      );
    });

    it('should filter by facility_id', async () => {
      const mockEntries = [{ id: 'queue-1', facility_id: 'facility-123' }];
      visitQueueRepository.findMany.mockResolvedValue(mockEntries);
      visitQueueRepository.count.mockResolvedValue(1);

      await listVisitQueues({ facility_id: 'facility-123' }, 1, 20);

      expect(visitQueueRepository.findMany).toHaveBeenCalledWith(
        { facility_id: 'facility-123' },
        0,
        20,
        { queued_at: 'desc' }
      );
    });

    it('should filter by patient_id', async () => {
      const mockEntries = [{ id: 'queue-1', patient_id: 'patient-123' }];
      visitQueueRepository.findMany.mockResolvedValue(mockEntries);
      visitQueueRepository.count.mockResolvedValue(1);

      await listVisitQueues({ patient_id: 'patient-123' }, 1, 20);

      expect(visitQueueRepository.findMany).toHaveBeenCalledWith(
        { patient_id: 'patient-123' },
        0,
        20,
        { queued_at: 'desc' }
      );
    });

    it('should filter by appointment_id', async () => {
      const mockEntries = [{ id: 'queue-1', appointment_id: 'appointment-123' }];
      visitQueueRepository.findMany.mockResolvedValue(mockEntries);
      visitQueueRepository.count.mockResolvedValue(1);

      await listVisitQueues({ appointment_id: 'appointment-123' }, 1, 20);

      expect(visitQueueRepository.findMany).toHaveBeenCalledWith(
        { appointment_id: 'appointment-123' },
        0,
        20,
        { queued_at: 'desc' }
      );
    });

    it('should filter by provider_user_id', async () => {
      const mockEntries = [{ id: 'queue-1', provider_user_id: 'user-123' }];
      visitQueueRepository.findMany.mockResolvedValue(mockEntries);
      visitQueueRepository.count.mockResolvedValue(1);

      await listVisitQueues({ provider_user_id: 'user-123' }, 1, 20);

      expect(visitQueueRepository.findMany).toHaveBeenCalledWith(
        { provider_user_id: 'user-123' },
        0,
        20,
        { queued_at: 'desc' }
      );
    });

    it('should filter by status', async () => {
      const mockEntries = [{ id: 'queue-1', status: 'SCHEDULED' }];
      visitQueueRepository.findMany.mockResolvedValue(mockEntries);
      visitQueueRepository.count.mockResolvedValue(1);

      await listVisitQueues({ status: 'SCHEDULED' }, 1, 20);

      expect(visitQueueRepository.findMany).toHaveBeenCalledWith(
        { status: 'SCHEDULED' },
        0,
        20,
        { queued_at: 'desc' }
      );
    });

    it('should apply search across queue-linked identities', async () => {
      const mockEntries = [{ id: 'queue-1', status: 'SCHEDULED' }];
      visitQueueRepository.findMany.mockResolvedValue(mockEntries);
      visitQueueRepository.count.mockResolvedValue(1);

      await listVisitQueues({ search: 'pat-001' }, 1, 20);

      expect(visitQueueRepository.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          OR: expect.arrayContaining([
            expect.objectContaining({
              human_friendly_id: { contains: 'PAT-001' }
            })
          ])
        }),
        0,
        20,
        { queued_at: 'desc' }
      );
    });

    it('should apply multiple filters', async () => {
      const mockEntries = [{ id: 'queue-1' }];
      visitQueueRepository.findMany.mockResolvedValue(mockEntries);
      visitQueueRepository.count.mockResolvedValue(1);

      await listVisitQueues({
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        status: 'SCHEDULED'
      }, 1, 20);

      expect(visitQueueRepository.findMany).toHaveBeenCalledWith(
        {
          tenant_id: 'tenant-123',
          patient_id: 'patient-123',
          status: 'SCHEDULED'
        },
        0,
        20,
        { queued_at: 'desc' }
      );
    });

    it('should handle pagination correctly', async () => {
      visitQueueRepository.findMany.mockResolvedValue([]);
      visitQueueRepository.count.mockResolvedValue(50);

      const result = await listVisitQueues({}, 2, 20);

      expect(result.pagination).toEqual({
        page: 2,
        limit: 20,
        total: 50,
        totalPages: 3,
        hasNextPage: true,
        hasPreviousPage: true
      });
    });

    it('should support custom sort order', async () => {
      visitQueueRepository.findMany.mockResolvedValue([]);
      visitQueueRepository.count.mockResolvedValue(0);

      await listVisitQueues({}, 1, 20, 'created_at', 'asc');

      expect(visitQueueRepository.findMany).toHaveBeenCalledWith(
        {},
        0,
        20,
        { created_at: 'asc' }
      );
    });
  });

  describe('getVisitQueueById', () => {
    it('should get visit queue entry by ID', async () => {
      const mockEntry = { id: 'queue-123', patient_id: 'patient-123', status: 'SCHEDULED' };
      visitQueueRepository.findById.mockResolvedValue(mockEntry);

      const result = await getVisitQueueById('queue-123');

      expect(result).toEqual(mockEntry);
      expect(visitQueueRepository.findById).toHaveBeenCalledWith('queue-123');
    });

    it('should throw HttpError if entry not found', async () => {
      visitQueueRepository.findById.mockResolvedValue(null);

      await expect(getVisitQueueById('queue-123'))
        .rejects
        .toThrow(HttpError);
    });
  });

  describe('createVisitQueue', () => {
    it('should create visit queue entry', async () => {
      const entryData = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        status: 'SCHEDULED'
      };
      const mockCreated = {
        id: 'queue-123',
        ...entryData,
        queued_at: expect.any(Date),
        created_at: new Date()
      };
      visitQueueRepository.create.mockResolvedValue(mockCreated);
      createAuditLog.mockResolvedValue({});

      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '192.168.1.1'
      };

      const result = await createVisitQueue(entryData, context);

      expect(result).toEqual(mockCreated);
      expect(visitQueueRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          tenant_id: 'tenant-123',
          patient_id: 'patient-123',
          status: 'SCHEDULED',
          queued_at: expect.any(Date)
        })
      );
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'VISIT_QUEUE_CREATED',
          entity: 'visit_queue',
          entity_id: 'queue-123',
          user_id: 'user-123'
        })
      );
    });

    it('should set queued_at to current time if not provided', async () => {
      const entryData = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        status: 'SCHEDULED'
      };
      const mockCreated = { id: 'queue-123', ...entryData };
      visitQueueRepository.create.mockResolvedValue(mockCreated);
      createAuditLog.mockResolvedValue({});

      await createVisitQueue(entryData, {});

      expect(visitQueueRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          queued_at: expect.any(Date)
        })
      );
    });

    it('should use provided queued_at', async () => {
      const queuedAt = new Date('2026-01-19T10:00:00.000Z');
      const entryData = {
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        status: 'SCHEDULED',
        queued_at: queuedAt
      };
      const mockCreated = { id: 'queue-123', ...entryData };
      visitQueueRepository.create.mockResolvedValue(mockCreated);
      createAuditLog.mockResolvedValue({});

      await createVisitQueue(entryData, {});

      expect(visitQueueRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          queued_at: queuedAt
        })
      );
    });

    it('should create audit log with full context', async () => {
      const entryData = {
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        patient_id: 'patient-123',
        appointment_id: 'appointment-123',
        provider_user_id: 'provider-123',
        status: 'SCHEDULED'
      };
      const mockCreated = { id: 'queue-123', ...entryData };
      visitQueueRepository.create.mockResolvedValue(mockCreated);
      createAuditLog.mockResolvedValue({});

      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0'
      };

      await createVisitQueue(entryData, context);

      expect(createAuditLog).toHaveBeenCalledWith({
        action: 'VISIT_QUEUE_CREATED',
        entity: 'visit_queue',
        entity_id: 'queue-123',
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        ip_address: '192.168.1.1',
        user_agent: 'Mozilla/5.0',
        details: expect.objectContaining({
          tenant_id: 'tenant-123',
          patient_id: 'patient-123',
          status: 'SCHEDULED'
        })
      });
    });
  });

  describe('updateVisitQueue', () => {
    it('should update visit queue entry', async () => {
      const beforeEntry = {
        id: 'queue-123',
        tenant_id: 'tenant-123',
        patient_id: 'patient-123',
        status: 'SCHEDULED',
        facility_id: 'facility-123',
        appointment_id: null,
        provider_user_id: null,
        queued_at: new Date('2026-01-19T10:00:00.000Z')
      };
      const updateData = { status: 'IN_PROGRESS' };
      const mockUpdated = { ...beforeEntry, ...updateData };
      visitQueueRepository.findById.mockResolvedValue(beforeEntry);
      visitQueueRepository.update.mockResolvedValue(mockUpdated);
      createAuditLog.mockResolvedValue({});

      const context = { user_id: 'user-123', tenant_id: 'tenant-123' };

      const result = await updateVisitQueue('queue-123', updateData, context);

      expect(result).toEqual(mockUpdated);
      expect(visitQueueRepository.findById).toHaveBeenCalledWith('queue-123');
      expect(visitQueueRepository.update).toHaveBeenCalledWith('queue-123', updateData);
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'VISIT_QUEUE_UPDATED',
          entity: 'visit_queue',
          entity_id: 'queue-123',
          user_id: 'user-123'
        })
      );
    });

    it('should throw HttpError if entry not found', async () => {
      visitQueueRepository.findById.mockResolvedValue(null);

      await expect(updateVisitQueue('queue-123', { status: 'COMPLETED' }, {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should include before and after states in audit log', async () => {
      const beforeEntry = {
        id: 'queue-123',
        facility_id: 'facility-123',
        appointment_id: 'appointment-123',
        provider_user_id: 'user-123',
        status: 'SCHEDULED',
        queued_at: new Date('2026-01-19T10:00:00.000Z')
      };
      const updateData = { status: 'IN_PROGRESS', provider_user_id: 'user-456' };
      const mockUpdated = { ...beforeEntry, ...updateData };
      visitQueueRepository.findById.mockResolvedValue(beforeEntry);
      visitQueueRepository.update.mockResolvedValue(mockUpdated);
      createAuditLog.mockResolvedValue({});

      await updateVisitQueue('queue-123', updateData, { user_id: 'user-123' });

      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          details: {
            before: expect.objectContaining({
              status: 'SCHEDULED',
              provider_user_id: 'user-123'
            }),
            after: expect.objectContaining({
              status: 'IN_PROGRESS',
              provider_user_id: 'user-456'
            })
          }
        })
      );
    });
  });

  describe('deleteVisitQueue', () => {
    it('should soft delete visit queue entry', async () => {
      const mockEntry = {
        id: 'queue-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        patient_id: 'patient-123',
        appointment_id: 'appointment-123',
        provider_user_id: 'user-123',
        status: 'SCHEDULED',
        queued_at: new Date('2026-01-19')
      };
      visitQueueRepository.findById.mockResolvedValue(mockEntry);
      visitQueueRepository.softDelete.mockResolvedValue(mockEntry);
      createAuditLog.mockResolvedValue({});

      const context = {
        user_id: 'user-123',
        tenant_id: 'tenant-123',
        ip_address: '192.168.1.1'
      };

      await deleteVisitQueue('queue-123', context);

      expect(visitQueueRepository.findById).toHaveBeenCalledWith('queue-123');
      expect(visitQueueRepository.softDelete).toHaveBeenCalledWith('queue-123');
      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'VISIT_QUEUE_DELETED',
          entity: 'visit_queue',
          entity_id: 'queue-123',
          user_id: 'user-123',
          details: expect.objectContaining({
            patient_id: 'patient-123',
            status: 'SCHEDULED'
          })
        })
      );
    });

    it('should throw HttpError if entry not found', async () => {
      visitQueueRepository.findById.mockResolvedValue(null);

      await expect(deleteVisitQueue('queue-123', {}))
        .rejects
        .toThrow(HttpError);
    });

    it('should not call softDelete if entry not found', async () => {
      visitQueueRepository.findById.mockResolvedValue(null);

      try {
        await deleteVisitQueue('queue-123', {});
      } catch (error) {
        // Expected error
      }

      expect(visitQueueRepository.softDelete).not.toHaveBeenCalled();
    });

    it('should create audit log with full entry details', async () => {
      const mockEntry = {
        id: 'queue-123',
        tenant_id: 'tenant-123',
        facility_id: 'facility-123',
        patient_id: 'patient-123',
        appointment_id: 'appointment-123',
        provider_user_id: 'user-123',
        status: 'CANCELLED',
        queued_at: new Date('2026-01-19')
      };
      visitQueueRepository.findById.mockResolvedValue(mockEntry);
      visitQueueRepository.softDelete.mockResolvedValue(mockEntry);
      createAuditLog.mockResolvedValue({});

      await deleteVisitQueue('queue-123', { user_id: 'user-123' });

      expect(createAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          details: {
            tenant_id: 'tenant-123',
            facility_id: 'facility-123',
            patient_id: 'patient-123',
            appointment_id: 'appointment-123',
            provider_user_id: 'user-123',
            status: 'CANCELLED',
            queued_at: expect.any(Date)
          }
        })
      );
    });
  });
});
