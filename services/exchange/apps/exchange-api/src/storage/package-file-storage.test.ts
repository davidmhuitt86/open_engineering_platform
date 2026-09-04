import { createHash } from 'node:crypto';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, beforeEach, describe, expect, test } from 'vitest';
import { LocalPackageFileStorage } from './package-file-storage.js';

describe('LocalPackageFileStorage', () => {
  let root: string;
  let storage: LocalPackageFileStorage;

  beforeEach(async () => {
    root = await mkdtemp(join(tmpdir(), 'oep-exchange-storage-test-'));
    storage = new LocalPackageFileStorage(root);
  });

  afterEach(async () => {
    await rm(root, { recursive: true, force: true });
  });

  test('writes the buffer to a content-addressable, sha256-sharded path', async () => {
    const buffer = Buffer.from('fake package archive bytes', 'utf8');
    const sha256 = createHash('sha256').update(buffer).digest('hex');

    const result = await storage.store(buffer, sha256);

    expect(result.sha256).toBe(sha256);
    expect(result.sizeBytes).toBe(buffer.length);
    expect(result.storagePath).toBe(join(root, sha256.slice(0, 2), `${sha256}.oep`));

    const written = await readFile(result.storagePath);
    expect(written.equals(buffer)).toBe(true);
  });

  test('two different hashes land in different shard directories', async () => {
    const bufferA = Buffer.from('archive A', 'utf8');
    const bufferB = Buffer.from('archive B', 'utf8');
    const shaA = createHash('sha256').update(bufferA).digest('hex');
    const shaB = createHash('sha256').update(bufferB).digest('hex');

    const resultA = await storage.store(bufferA, shaA);
    const resultB = await storage.store(bufferB, shaB);

    expect(resultA.storagePath).not.toBe(resultB.storagePath);
  });

  test('creates nested shard directories that do not yet exist', async () => {
    const buffer = Buffer.from('another archive', 'utf8');
    const sha256 = createHash('sha256').update(buffer).digest('hex');

    await expect(storage.store(buffer, sha256)).resolves.toBeTruthy();
  });

  test('retrieve reads back exactly what was stored', async () => {
    const buffer = Buffer.from('round-trip archive bytes', 'utf8');
    const sha256 = createHash('sha256').update(buffer).digest('hex');
    const stored = await storage.store(buffer, sha256);

    const retrieved = await storage.retrieve(stored.storagePath);
    expect(retrieved.equals(buffer)).toBe(true);
  });

  test('retrieve rejects a path that was never stored', async () => {
    await expect(storage.retrieve(join(root, 'ab', 'nonexistent.oep'))).rejects.toThrow();
  });
});
