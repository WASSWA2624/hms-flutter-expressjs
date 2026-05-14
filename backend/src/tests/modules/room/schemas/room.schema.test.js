/**
 * Room schema validation tests
 *
 * @module tests/modules/room/schemas
 * Per testing.mdc: All schemas must have comprehensive tests
 */

const {
  createRoomSchema,
  updateRoomSchema,
  roomIdParamsSchema,
  listRoomsQuerySchema
} = require('@validations/room/room.schema');

describe('Room Schema Validation', () => {
  describe('createRoomSchema', () => {
    it('should validate correct room data', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        name: 'Room 101',
        floor: '1st Floor'
      };
      const result = createRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with minimal data (required fields only)', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Room 101'
      };
      const result = createRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null ward_id', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: null,
        name: 'Room 101'
      };
      const result = createRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null floor', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Room 101',
        floor: null
      };
      const result = createRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: '  Room 101  '
      };
      const result = createRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Room 101');
      }
    });

    it('should trim floor whitespace', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Room 101',
        floor: '  1st Floor  '
      };
      const result = createRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.floor).toBe('1st Floor');
      }
    });

    it('should reject missing tenant_id', () => {
      const invalidData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Room 101'
      };
      const result = createRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing facility_id', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        name: 'Room 101'
      };
      const result = createRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Room 101'
      };
      const result = createRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: 'not-a-uuid',
        name: 'Room 101'
      };
      const result = createRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ward_id UUID', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: 'not-a-uuid',
        name: 'Room 101'
      };
      const result = createRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = createRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty name', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: ''
      };
      const result = createRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 255 characters', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'a'.repeat(256)
      };
      const result = createRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty floor', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Room 101',
        floor: ''
      };
      const result = createRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject floor exceeding 50 characters', () => {
      const invalidData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        name: 'Room 101',
        floor: 'a'.repeat(51)
      };
      const result = createRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('updateRoomSchema', () => {
    it('should validate with all fields', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        name: 'Updated Room',
        floor: '2nd Floor'
      };
      const result = updateRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with empty object (all fields optional)', () => {
      const validData = {};
      const result = updateRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only name', () => {
      const validData = {
        name: 'Updated Room'
      };
      const result = updateRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only facility_id', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = updateRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only ward_id', () => {
      const validData = {
        ward_id: '123e4567-e89b-12d3-a456-426614174002'
      };
      const result = updateRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with only floor', () => {
      const validData = {
        floor: '3rd Floor'
      };
      const result = updateRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null ward_id', () => {
      const validData = {
        ward_id: null
      };
      const result = updateRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with null floor', () => {
      const validData = {
        floor: null
      };
      const result = updateRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should trim name whitespace', () => {
      const validData = {
        name: '  Updated Room  '
      };
      const result = updateRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.name).toBe('Updated Room');
      }
    });

    it('should trim floor whitespace', () => {
      const validData = {
        floor: '  2nd Floor  '
      };
      const result = updateRoomSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.floor).toBe('2nd Floor');
      }
    });

    it('should reject empty name', () => {
      const invalidData = {
        name: ''
      };
      const result = updateRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject name exceeding 255 characters', () => {
      const invalidData = {
        name: 'a'.repeat(256)
      };
      const result = updateRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty floor', () => {
      const invalidData = {
        floor: ''
      };
      const result = updateRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject floor exceeding 50 characters', () => {
      const invalidData = {
        floor: 'a'.repeat(51)
      };
      const result = updateRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = updateRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ward_id UUID', () => {
      const invalidData = {
        ward_id: 'not-a-uuid'
      };
      const result = updateRoomSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('roomIdParamsSchema', () => {
    it('should validate correct UUID room ID', () => {
      const validData = {
        id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = roomIdParamsSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid UUID format', () => {
      const invalidData = {
        id: 'not-a-uuid'
      };
      const result = roomIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject missing id', () => {
      const invalidData = {};
      const result = roomIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject empty string', () => {
      const invalidData = {
        id: ''
      };
      const result = roomIdParamsSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });

  describe('listRoomsQuerySchema', () => {
    it('should validate empty query params', () => {
      const validData = {};
      const result = listRoomsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with pagination params', () => {
      const validData = {
        page: 1,
        limit: 20
      };
      const result = listRoomsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with sorting params', () => {
      const validData = {
        sort_by: 'created_at',
        order: 'desc'
      };
      const result = listRoomsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with tenant_id filter', () => {
      const validData = {
        tenant_id: '123e4567-e89b-12d3-a456-426614174000'
      };
      const result = listRoomsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with facility_id filter', () => {
      const validData = {
        facility_id: '123e4567-e89b-12d3-a456-426614174001'
      };
      const result = listRoomsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with ward_id filter', () => {
      const validData = {
        ward_id: '123e4567-e89b-12d3-a456-426614174002'
      };
      const result = listRoomsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with search filter', () => {
      const validData = {
        search: 'room 101'
      };
      const result = listRoomsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should validate with all params', () => {
      const validData = {
        page: 2,
        limit: 50,
        sort_by: 'name',
        order: 'asc',
        tenant_id: '123e4567-e89b-12d3-a456-426614174000',
        facility_id: '123e4567-e89b-12d3-a456-426614174001',
        ward_id: '123e4567-e89b-12d3-a456-426614174002',
        search: 'room'
      };
      const result = listRoomsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('should reject invalid tenant_id UUID', () => {
      const invalidData = {
        tenant_id: 'not-a-uuid'
      };
      const result = listRoomsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid facility_id UUID', () => {
      const invalidData = {
        facility_id: 'not-a-uuid'
      };
      const result = listRoomsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid ward_id UUID', () => {
      const invalidData = {
        ward_id: 'not-a-uuid'
      };
      const result = listRoomsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject negative page number', () => {
      const invalidData = {
        page: -1
      };
      const result = listRoomsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject zero page number', () => {
      const invalidData = {
        page: 0
      };
      const result = listRoomsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should reject invalid sort order', () => {
      const invalidData = {
        order: 'invalid'
      };
      const result = listRoomsQuerySchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('should coerce string numbers for pagination', () => {
      const validData = {
        page: '2',
        limit: '30'
      };
      const result = listRoomsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(2);
        expect(result.data.limit).toBe(30);
      }
    });

    it('should trim search whitespace', () => {
      const validData = {
        search: '  room  '
      };
      const result = listRoomsQuerySchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.search).toBe('room');
      }
    });
  });
});
