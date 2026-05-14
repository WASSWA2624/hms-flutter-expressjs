/**
 * Vital Sign service tests
 *
 * @module tests/modules/vital-sign/services
 * @description Tests for vital sign service
 * Per testing.mdc: Service tests with mocked repository
 */

const vitalSignService = require('@services/vital-sign/vital-sign.service');
const vitalSignRepository = require('@repositories/vital-sign/vital-sign.repository');
const { createAuditLog } = require('@lib/audit');

jest.mock('@repositories/vital-sign/vital-sign.repository');
jest.mock('@lib/audit');

describe('Vital Sign Service', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  const mockUserId = 'user-id-123';
  const mockIpAddress = '127.0.0.1';

  describe('listVitalSigns', () => {
    it('should list vital signs with pagination', async () => {
      const mockVitalSigns = [{ id: '1', vital_type: 'TEMPERATURE' }];
      vitalSignRepository.findMany.mockResolvedValue(mockVitalSigns);
      vitalSignRepository.count.mockResolvedValue(1);

      const result = await vitalSignService.listVitalSigns({}, 1, 20, null, 'asc', mockUserId, mockIpAddress);

      expect(result.vitalSigns).toEqual(mockVitalSigns);
      expect(result.pagination.total).toBe(1);
    });
  });

  describe('getVitalSignById', () => {
    it('should get vital sign by ID', async () => {
      const mockVitalSign = { id: '1', vital_type: 'TEMPERATURE' };
      vitalSignRepository.findById.mockResolvedValue(mockVitalSign);

      const result = await vitalSignService.getVitalSignById('1', mockUserId, mockIpAddress);

      expect(result).toEqual(mockVitalSign);
    });

    it('should throw error when vital sign not found', async () => {
      vitalSignRepository.findById.mockResolvedValue(null);

      await expect(vitalSignService.getVitalSignById('1', mockUserId, mockIpAddress))
        .rejects.toThrow();
    });
  });

  describe('createVitalSign', () => {
    it('should create vital sign and audit log', async () => {
      const newVitalSign = { vital_type: 'TEMPERATURE', value: '98.6' };
      const createdVitalSign = { id: '1', ...newVitalSign };
      vitalSignRepository.create.mockResolvedValue(createdVitalSign);
      createAuditLog.mockResolvedValue({});

      const result = await vitalSignService.createVitalSign(newVitalSign, mockUserId, mockIpAddress);

      expect(result).toEqual(createdVitalSign);
      expect(vitalSignRepository.create).toHaveBeenCalledWith({
        ...newVitalSign,
        systolic_value: null,
        diastolic_value: null,
        map_value: null,
      });
    });

    it('normalizes blood pressure payload and computes MAP when missing', async () => {
      const newVitalSign = { vital_type: 'BLOOD_PRESSURE', value: '120/80' };
      const createdVitalSign = {
        id: '2',
        ...newVitalSign,
        systolic_value: 120,
        diastolic_value: 80,
        map_value: 93.33,
      };
      vitalSignRepository.create.mockResolvedValue(createdVitalSign);
      createAuditLog.mockResolvedValue({});

      await vitalSignService.createVitalSign(newVitalSign, mockUserId, mockIpAddress);

      expect(vitalSignRepository.create).toHaveBeenCalledWith({
        vital_type: 'BLOOD_PRESSURE',
        value: '120/80',
        systolic_value: 120,
        diastolic_value: 80,
        map_value: 93.33,
      });
    });
  });

  describe('updateVitalSign', () => {
    it('should update vital sign and create audit log', async () => {
      const existingVitalSign = { id: '1', vital_type: 'TEMPERATURE', value: '98.6' };
      const updateData = { value: '99.0' };
      const updatedVitalSign = { ...existingVitalSign, ...updateData };

      vitalSignRepository.findById.mockResolvedValue(existingVitalSign);
      vitalSignRepository.update.mockResolvedValue(updatedVitalSign);
      createAuditLog.mockResolvedValue({});

      const result = await vitalSignService.updateVitalSign('1', updateData, mockUserId, mockIpAddress);

      expect(result).toEqual(updatedVitalSign);
    });
  });

  describe('deleteVitalSign', () => {
    it('should soft delete vital sign and create audit log', async () => {
      const existingVitalSign = { id: '1', vital_type: 'TEMPERATURE' };
      vitalSignRepository.findById.mockResolvedValue(existingVitalSign);
      vitalSignRepository.softDelete.mockResolvedValue({ ...existingVitalSign, deleted_at: new Date() });
      createAuditLog.mockResolvedValue({});

      await vitalSignService.deleteVitalSign('1', mockUserId, mockIpAddress);

      expect(vitalSignRepository.softDelete).toHaveBeenCalledWith('1');
    });
  });
});
