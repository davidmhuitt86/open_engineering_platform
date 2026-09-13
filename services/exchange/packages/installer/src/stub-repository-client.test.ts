import { describe, expect, test } from 'vitest';
import { StubRepositoryClient } from './stub-repository-client.js';

describe('StubRepositoryClient', () => {
  test('reports acceptance by default', async () => {
    const client = new StubRepositoryClient();
    const result = await client.install({
      packageId: 'com.divad.honda.gl1200',
      version: '1.0.0',
      artifact: Buffer.from('archive'),
      sha256: 'deadbeef',
      fileName: 'package.oep',
    });

    expect(result.accepted).toBe(true);
    expect(result.repositoryPackageId).toBe('stub-com.divad.honda.gl1200@1.0.0');
  });

  test('reports rejection when configured to simulate failure', async () => {
    const client = new StubRepositoryClient({
      simulateFailure: true,
      failureMessage: 'out of disk space',
    });
    const result = await client.install({
      packageId: 'com.divad.honda.gl1200',
      version: '1.0.0',
      artifact: Buffer.from('archive'),
      sha256: 'deadbeef',
      fileName: 'package.oep',
    });

    expect(result.accepted).toBe(false);
    expect(result.message).toBe('out of disk space');
  });

  test('uses a default failure message when none is provided', async () => {
    const client = new StubRepositoryClient({ simulateFailure: true });
    const result = await client.install({
      packageId: 'com.divad.honda.gl1200',
      version: '1.0.0',
      artifact: Buffer.from('archive'),
      sha256: 'deadbeef',
      fileName: 'package.oep',
    });

    expect(result.message).toMatch(/rejected/);
  });
});
