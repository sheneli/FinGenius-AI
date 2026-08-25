// Storage Security Rules tests — run with the emulator (see package.json).
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
    storage: { rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

const jpegBytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);

test('owner can upload a small jpeg receipt', async () => {
  const storage = env.authenticatedContext('alice').storage();
  await assertSucceeds(
    storage.ref('receipts/alice/r1.jpg').put(jpegBytes, { contentType: 'image/jpeg' }),
  );
});

test('cross-user receipt upload is denied', async () => {
  const storage = env.authenticatedContext('mallory').storage();
  await assertFails(
    storage.ref('receipts/alice/evil.jpg').put(jpegBytes, { contentType: 'image/jpeg' }),
  );
});

test('non-image content type is denied', async () => {
  const storage = env.authenticatedContext('alice').storage();
  await assertFails(
    storage.ref('receipts/alice/r2.jpg').put(jpegBytes, { contentType: 'application/pdf' }),
  );
});

test('unauthenticated reads are denied', async () => {
  const storage = env.unauthenticatedContext().storage();
  await assertFails(storage.ref('receipts/alice/r1.jpg').getDownloadURL());
});

test('paths outside the schema are denied', async () => {
  const storage = env.authenticatedContext('alice').storage();
  await assertFails(
    storage.ref('random/alice/file.jpg').put(jpegBytes, { contentType: 'image/jpeg' }),
  );
});
