/**
 * Therapy flow repository
 *
 * @module modules/therapy-flow/repositories
 */

const prisma = require('@prisma/client');
const { HttpError } = require('@lib/errors');

const PATIENT_SELECT = {
  id: true,
  human_friendly_id: true,
  first_name: true,
  last_name: true,
  gender: true,
  contacts: {
    where: { deleted_at: null, contact_type: 'PHONE' },
    orderBy: [{ is_primary: 'desc' }, { created_at: 'asc' }],
    take: 1,
    select: { value: true }}};

const ENCOUNTER_SELECT = {
  id: true,
  human_friendly_id: true,
  tenant_id: true,
  facility_id: true,
  patient_id: true,
  encounter_type: true,
  status: true,
  started_at: true,
  ended_at: true,
  patient: { select: PATIENT_SELECT }};

const THERAPIST_SELECT = {
  id: true,
  human_friendly_id: true,
  email: true,
  profile: {
    select: {
      first_name: true,
      middle_name: true,
      last_name: true}}};

const SESSION_INCLUDE = {
  where: { deleted_at: null },
  orderBy: { scheduled_start_at: 'desc' },
  include: {
    therapist: { select: THERAPIST_SELECT }}};

const BASE_INCLUDE = {
  encounter: { select: ENCOUNTER_SELECT },
  admission: {
    select: {
      id: true,
      human_friendly_id: true,
      status: true,
      bed_assignments: {
        where: { deleted_at: null, released_at: null },
        orderBy: { assigned_at: 'desc' },
        take: 1,
        select: {
          bed: {
            select: {
              id: true,
              human_friendly_id: true,
              label: true,
              ward: {
                select: {
                  id: true,
                  human_friendly_id: true,
                  name: true}}}}}}}},
  referral: {
    select: {
      id: true,
      human_friendly_id: true,
      reason: true,
      status: true}},
  therapist: { select: THERAPIST_SELECT },
  sessions: SESSION_INCLUDE};

const findById = async (id, include = {}) => {
  try {
    return await prisma.therapy_episode.findFirst({
      where: { id, deleted_at: null },
      include: { ...BASE_INCLUDE, ...include }});
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message }]);
  }
};

const findMany = async (
  filters = {},
  skip = 0,
  take = 20,
  orderBy = { updated_at: 'desc' },
  include = {}
) => {
  try {
    return await prisma.therapy_episode.findMany({
      where: { deleted_at: null, ...filters },
      skip,
      take,
      orderBy,
      include: { ...BASE_INCLUDE, ...include }});
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message }]);
  }
};

const count = async (filters = {}) => {
  try {
    return await prisma.therapy_episode.count({
      where: { deleted_at: null, ...filters }});
  } catch (error) {
    throw new HttpError('errors.database.unexpected', 500, [
      { originalError: error.message }]);
  }
};

module.exports = {
  findById,
  findMany,
  count,
  BASE_INCLUDE,
  SESSION_INCLUDE};
