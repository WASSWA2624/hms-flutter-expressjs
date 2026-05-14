#!/usr/bin/env node
const prisma = require('../../src/prisma/client');

const TARGET_TABLES = [
  { model: 'user', scope: ['tenant_id'], prefix: 'USR' },
  { model: 'staff_profile', scope: ['tenant_id'], prefix: 'STF' },
  { model: 'staff_position', scope: ['tenant_id'], prefix: 'SPO' },
  { model: 'patient', scope: ['tenant_id'], prefix: 'PAT' },
  { model: 'appointment', scope: ['tenant_id'], prefix: 'APT' },
  { model: 'visit_queue', scope: ['tenant_id'], prefix: 'VIS' },
  { model: 'encounter', scope: ['tenant_id'], prefix: 'ENC' },
  { model: 'provider_schedule', scope: ['tenant_id'], prefix: 'PRO' },
  { model: 'availability_slot', scope: ['schedule_id'], prefix: 'AVA' },
  { model: 'lab_test', scope: ['tenant_id'], prefix: 'LAB' },
  { model: 'lab_panel', scope: ['tenant_id'], prefix: 'LAB' },
  { model: 'lab_order', scope: [], prefix: 'LAB' },
  { model: 'lab_order_item', scope: [], prefix: 'LAB' },
  { model: 'lab_sample', scope: [], prefix: 'LAB' },
  { model: 'lab_result', scope: [], prefix: 'LAB' },
  { model: 'lab_qc_log', scope: [], prefix: 'LAB' },
];

const FRIENDLY_ID_PADDING = 7;

const normalizeFriendlyId = (value) => String(value || '').trim().toUpperCase();
const buildScopeKey = (row, scopeFields) =>
  scopeFields.map((field) => String(row[field] || '')).join('|');
const isCanonicalFriendlyId = (value) => /^[A-Z]{3}\d{7}$/.test(value);
const extractSequence = (value, prefix) => {
  if (!isCanonicalFriendlyId(value)) return null;
  if (!value.startsWith(prefix)) return null;
  const numericPart = Number(value.slice(prefix.length));
  if (!Number.isFinite(numericPart) || numericPart <= 0) return null;
  return numericPart;
};
const buildCandidate = (prefix, sequence) =>
  `${prefix}${String(sequence).padStart(FRIENDLY_ID_PADDING, '0')}`;

const resolveTable = async ({ model, scope, prefix }) => {
  const delegate = prisma[model];
  if (!delegate?.findMany || !delegate?.update) {
    throw new Error(`Prisma model "${model}" is not available`);
  }

  const normalizedPrefix = String(prefix || model || 'XXX')
    .replace(/[^A-Za-z0-9]/g, '')
    .toUpperCase()
    .slice(0, 3)
    .padEnd(3, 'X');

  const select = {
    id: true,
    human_friendly_id: true,
    created_at: true,
    deleted_at: true,
  };
  for (const field of scope) {
    select[field] = true;
  }

  const rows = await delegate.findMany({
    where: {
      deleted_at: null,
    },
    select,
    orderBy: [{ created_at: 'asc' }, { id: 'asc' }],
  });

  const scopeState = new Map();
  const keyToRows = new Map();

  const ensureScopeState = (scopeKey) => {
    const existing = scopeState.get(scopeKey);
    if (existing) return existing;
    const next = {
      used: new Set(),
      nextSequence: 1,
    };
    scopeState.set(scopeKey, next);
    return next;
  };

  for (const row of rows) {
    const scopeKey = buildScopeKey(row, scope);
    const state = ensureScopeState(scopeKey);
    const normalizedFriendlyId = normalizeFriendlyId(row.human_friendly_id);

    if (normalizedFriendlyId) {
      state.used.add(normalizedFriendlyId);

      const sequence = extractSequence(normalizedFriendlyId, normalizedPrefix);
      if (sequence && sequence >= state.nextSequence) {
        state.nextSequence = sequence + 1;
      }

      const collisionKey = `${scopeKey}|${normalizedFriendlyId}`;
      const existing = keyToRows.get(collisionKey) || [];
      existing.push(row);
      keyToRows.set(collisionKey, existing);
    }
  }

  const nextUniqueCandidate = (scopeKey) => {
    const state = ensureScopeState(scopeKey);
    let sequence = state.nextSequence;
    let candidate = buildCandidate(normalizedPrefix, sequence);

    while (state.used.has(candidate)) {
      sequence += 1;
      candidate = buildCandidate(normalizedPrefix, sequence);
    }

    state.nextSequence = sequence + 1;
    state.used.add(candidate);
    return candidate;
  };

  let collisionUpdates = 0;
  for (const entries of keyToRows.values()) {
    if (entries.length <= 1) continue;

    for (let index = 1; index < entries.length; index += 1) {
      const row = entries[index];
      const scopeKey = buildScopeKey(row, scope);
      const candidate = nextUniqueCandidate(scopeKey);

      await delegate.update({
        where: { id: row.id },
        data: { human_friendly_id: candidate },
      });

      collisionUpdates += 1;
      console.log(
        `[${model}] collision fix ${row.id}: ${normalizeFriendlyId(
          row.human_friendly_id
        )} -> ${candidate}`
      );
    }
  }

  let backfillUpdates = 0;
  for (const row of rows) {
    const normalizedFriendlyId = normalizeFriendlyId(row.human_friendly_id);
    if (normalizedFriendlyId) continue;

    const scopeKey = buildScopeKey(row, scope);
    const candidate = nextUniqueCandidate(scopeKey);

    await delegate.update({
      where: { id: row.id },
      data: { human_friendly_id: candidate },
    });

    backfillUpdates += 1;
    console.log(`[${model}] backfilled ${row.id}: <empty> -> ${candidate}`);
  }

  return {
    collisionUpdates,
    backfillUpdates,
  };
};

const main = async () => {
  try {
    let totalCollisionUpdates = 0;
    let totalBackfillUpdates = 0;

    for (const table of TARGET_TABLES) {
      const { collisionUpdates, backfillUpdates } = await resolveTable(table);
      totalCollisionUpdates += collisionUpdates;
      totalBackfillUpdates += backfillUpdates;
    }

    console.log(
      `Collision resolution complete. Collision updates: ${totalCollisionUpdates}. Backfilled rows: ${totalBackfillUpdates}.`
    );
  } catch (error) {
    console.error(`Collision resolution failed: ${error.message}`);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect().catch(() => {});
  }
};

main();
