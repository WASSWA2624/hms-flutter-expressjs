/**
 * Care Plan service tests
 *
 * @module tests/modules/care-plan/services
 * @description Tests for care plan service
 * Per testing.mdc: Service tests with mocked repository
 */

const carePlanService = require('@services/care-plan/care-plan.service');
const carePlanRepository = require('@repositories/care-plan/care-plan.repository');
const { createAuditLog } = require('@lib/audit');

jest.mock('@repositories/care-plan/care-plan.repository');
jest.mock('@lib/audit');

describe('Care Plan Service', () => {
  const mockUserId = 'user-id-123';
  const mockIpAddress = '127.0.0.1';

  afterEach(() => jest.clearAllMocks());

  it('should list care plans', async () => {
    const mockCarePlans = [{ id: '1', plan: 'Test plan' }];
    carePlanRepository.findMany.mockResolvedValue(mockCarePlans);
    carePlanRepository.count.mockResolvedValue(1);

    const result = await carePlanService.listCarePlans({}, 1, 20, null, 'asc', mockUserId, mockIpAddress);

    expect(result.carePlans).toEqual(mockCarePlans);
  });

  it('should create care plan', async () => {
    const newCarePlan = { plan: 'New plan' };
    const createdCarePlan = { id: '1', ...newCarePlan };
    carePlanRepository.create.mockResolvedValue(createdCarePlan);
    createAuditLog.mockReturnValue(Promise.resolve({}));

    const result = await carePlanService.createCarePlan(newCarePlan, mockUserId, mockIpAddress);

    expect(result).toEqual(createdCarePlan);
  });

  it('should update care plan', async () => {
    const existing = { id: '1', plan: 'Old plan' };
    const updated = { id: '1', plan: 'Updated plan' };
    carePlanRepository.findById.mockResolvedValue(existing);
    carePlanRepository.update.mockResolvedValue(updated);
    createAuditLog.mockResolvedValue({});

    const result = await carePlanService.updateCarePlan('1', { plan: 'Updated plan' }, mockUserId, mockIpAddress);

    expect(result).toEqual(updated);
  });
});
