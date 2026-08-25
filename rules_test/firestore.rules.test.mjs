// Firestore Security Rules tests — run with the emulator:
//   cd rules_test && npm install && npm test
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'fingenius-rules-test',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

const alice = () => env.authenticatedContext('alice').firestore();
const mallory = () => env.authenticatedContext('mallory').firestore();
const anon = () => env.unauthenticatedContext().firestore();

const validTx = {
  clientId: 'c1', type: 'expense', amountMinor: 1500, currency: 'LKR',
  categoryId: 'groceries', accountId: 'a1', occurredAt: '2026-07-01T10:00:00Z',
  merchant: 'Keells', note: '', source: 'manual', schemaVersion: 1,
};

test('owner can create a valid transaction', async () => {
  await assertSucceeds(
    alice().doc('users/alice/transactions/t1').set(validTx),
  );
});

test('another user cannot read someone else\'s transaction', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc('users/alice/transactions/t2').set(validTx);
  });
  await assertFails(mallory().doc('users/alice/transactions/t2').get());
});

test('another user cannot write into someone else\'s subtree', async () => {
  await assertFails(mallory().doc('users/alice/transactions/evil').set(validTx));
});

test('unauthenticated access is denied everywhere', async () => {
  await assertFails(anon().doc('users/alice').get());
  await assertFails(anon().doc('users/alice/transactions/t1').get());
});

test('negative transaction amounts are rejected', async () => {
  await assertFails(
    alice().doc('users/alice/transactions/neg').set({ ...validTx, amountMinor: -500 }),
  );
});

test('invalid transaction type is rejected', async () => {
  await assertFails(
    alice().doc('users/alice/transactions/bad').set({ ...validTx, type: 'transfer' }),
  );
});

test('oversized merchant string is rejected', async () => {
  await assertFails(
    alice().doc('users/alice/transactions/big').set({ ...validTx, merchant: 'x'.repeat(200) }),
  );
});

test('budget with zero limit is rejected; positive succeeds', async () => {
  await assertFails(alice().doc('users/alice/budgets/b0').set({
    categoryId: 'dining', periodKey: '2026-07', limitMinor: 0, currency: 'LKR',
  }));
  await assertSucceeds(alice().doc('users/alice/budgets/b1').set({
    categoryId: 'dining', periodKey: '2026-07', limitMinor: 50000, currency: 'LKR',
  }));
});

test('owner can manage own profile; foreign profile writes fail', async () => {
  await assertSucceeds(alice().doc('users/alice').set({
    email: 'a@example.com', displayName: 'Alice', schemaVersion: 1,
    prefs: { theme: 'dark' }, consent: { analytics: false },
  }));
  await assertFails(mallory().doc('users/alice').set({ displayName: 'Hacked' }));
});

test('unknown top-level collections are denied', async () => {
  await assertFails(alice().doc('admin/config').get());
  await assertFails(alice().doc('admin/config').set({ x: 1 }));
});
