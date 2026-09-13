import { describe, expect, test, vi } from 'vitest';
import { HttpRepositoryClient } from './http-repository-client.js';

function fakeResponse(init: { ok: boolean; status?: number; body?: unknown }): Response {
  return {
    ok: init.ok,
    status: init.status ?? (init.ok ? 200 : 500),
    json: async () => init.body ?? {},
  } as Response;
}

describe('HttpRepositoryClient', () => {
  test('POSTs the artifact base64-encoded to {baseUrl}/api/v1/packages/install', async () => {
    const fetchFn = vi
      .fn()
      .mockResolvedValue(
        fakeResponse({ ok: true, body: { accepted: true, repositoryPackageId: 'repo-123' } }),
      );
    const client = new HttpRepositoryClient({ baseUrl: 'http://localhost:8080', fetchFn });

    const result = await client.install({
      packageId: 'com.divad.honda.gl1200',
      version: '1.0.0',
      artifact: Buffer.from('archive-bytes'),
      sha256: 'deadbeef',
      fileName: 'package.oep',
    });

    expect(result).toEqual({ accepted: true, repositoryPackageId: 'repo-123' });
    expect(fetchFn).toHaveBeenCalledWith(
      'http://localhost:8080/api/v1/packages/install',
      expect.objectContaining({ method: 'POST' }),
    );
    const requestBody = JSON.parse(fetchFn.mock.calls[0]![1].body as string);
    expect(requestBody.artifactBase64).toBe(Buffer.from('archive-bytes').toString('base64'));
    expect(requestBody.packageId).toBe('com.divad.honda.gl1200');
  });

  test('strips a trailing slash from baseUrl', async () => {
    const fetchFn = vi.fn().mockResolvedValue(fakeResponse({ ok: true, body: { accepted: true } }));
    const client = new HttpRepositoryClient({ baseUrl: 'http://localhost:8080/', fetchFn });

    await client.install({
      packageId: 'com.divad.honda.gl1200',
      version: '1.0.0',
      artifact: Buffer.from('x'),
      sha256: 'x',
      fileName: 'x.oep',
    });

    expect(fetchFn).toHaveBeenCalledWith(
      'http://localhost:8080/api/v1/packages/install',
      expect.anything(),
    );
  });

  test('reports rejection for a non-2xx HTTP response', async () => {
    const fetchFn = vi.fn().mockResolvedValue(fakeResponse({ ok: false, status: 503 }));
    const client = new HttpRepositoryClient({ baseUrl: 'http://localhost:8080', fetchFn });

    const result = await client.install({
      packageId: 'com.divad.honda.gl1200',
      version: '1.0.0',
      artifact: Buffer.from('x'),
      sha256: 'x',
      fileName: 'x.oep',
    });

    expect(result.accepted).toBe(false);
    expect(result.message).toMatch(/503/);
  });

  test('reports rejection when the Repository body omits accepted:true', async () => {
    const fetchFn = vi.fn().mockResolvedValue(fakeResponse({ ok: true, body: {} }));
    const client = new HttpRepositoryClient({ baseUrl: 'http://localhost:8080', fetchFn });

    const result = await client.install({
      packageId: 'com.divad.honda.gl1200',
      version: '1.0.0',
      artifact: Buffer.from('x'),
      sha256: 'x',
      fileName: 'x.oep',
    });

    expect(result.accepted).toBe(false);
  });

  test('reports rejection with a message when the network call itself throws', async () => {
    const fetchFn = vi.fn().mockRejectedValue(new Error('ECONNREFUSED'));
    const client = new HttpRepositoryClient({ baseUrl: 'http://localhost:8080', fetchFn });

    const result = await client.install({
      packageId: 'com.divad.honda.gl1200',
      version: '1.0.0',
      artifact: Buffer.from('x'),
      sha256: 'x',
      fileName: 'x.oep',
    });

    expect(result.accepted).toBe(false);
    expect(result.message).toMatch(/ECONNREFUSED/);
  });
});
