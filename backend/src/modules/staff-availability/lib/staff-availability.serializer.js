/**
 * Staff availability API serializer.
 */
const { parseRecordSlots } = require('./availability-slots');

const serializeStaffAvailability = (record) => {
  if (!record) {
    return record;
  }

  const timeSlots = parseRecordSlots(record);

  return {
    ...record,
    display_id: record.human_friendly_id || record.id,
    time_slots: timeSlots,
  };
};

const serializeStaffAvailabilityList = (records = []) =>
  records.map((record) => serializeStaffAvailability(record));

module.exports = {
  serializeStaffAvailability,
  serializeStaffAvailabilityList,
};
