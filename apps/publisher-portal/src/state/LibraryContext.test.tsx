import { act, renderHook } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, test } from 'vitest';
import { LibraryProvider, useLibrary } from './LibraryContext.js';

describe('LibraryContext', () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  afterEach(() => {
    window.localStorage.clear();
  });

  test('starts empty when localStorage has nothing stored', () => {
    const { result } = renderHook(() => useLibrary(), { wrapper: LibraryProvider });
    expect(result.current.downloads).toEqual([]);
    expect(result.current.installations).toEqual([]);
  });

  test('recordDownload prepends the most recent download first', () => {
    const { result } = renderHook(() => useLibrary(), { wrapper: LibraryProvider });

    act(() => {
      result.current.recordDownload({
        packageId: 'pkg-1',
        packageDisplayName: 'Honda GL1200',
        version: '1.0.0',
        downloadedAt: '2026-01-01T00:00:00.000Z',
      });
      result.current.recordDownload({
        packageId: 'pkg-2',
        packageDisplayName: 'Yamaha XS650',
        version: '2.0.0',
        downloadedAt: '2026-01-02T00:00:00.000Z',
      });
    });

    expect(result.current.downloads.map((d) => d.packageId)).toEqual(['pkg-2', 'pkg-1']);
  });

  test('recordInstallation adds an entry and updateInstallationStatus updates it in place', () => {
    const { result } = renderHook(() => useLibrary(), { wrapper: LibraryProvider });

    act(() => {
      result.current.recordInstallation({
        installationId: 'install-1',
        packageId: 'pkg-1',
        packageDisplayName: 'Honda GL1200',
        version: '1.0.0',
        status: 'pending',
        requestedAt: '2026-01-01T00:00:00.000Z',
      });
    });
    expect(result.current.installations[0]?.status).toBe('pending');

    act(() => {
      result.current.updateInstallationStatus('install-1', 'completed');
    });
    expect(result.current.installations[0]?.status).toBe('completed');
    expect(result.current.installations).toHaveLength(1);
  });

  test('persists state to localStorage and reloads it on remount', () => {
    const { result, unmount } = renderHook(() => useLibrary(), { wrapper: LibraryProvider });

    act(() => {
      result.current.recordDownload({
        packageId: 'pkg-1',
        packageDisplayName: 'Honda GL1200',
        version: '1.0.0',
        downloadedAt: '2026-01-01T00:00:00.000Z',
      });
    });
    unmount();

    const { result: reloaded } = renderHook(() => useLibrary(), { wrapper: LibraryProvider });
    expect(reloaded.current.downloads).toHaveLength(1);
    expect(reloaded.current.downloads[0]?.packageId).toBe('pkg-1');
  });

  test('falls back to empty state when localStorage holds malformed JSON', () => {
    window.localStorage.setItem('oep-exchange.publisher-portal.library.v1', 'not-json{{{');
    const { result } = renderHook(() => useLibrary(), { wrapper: LibraryProvider });
    expect(result.current.downloads).toEqual([]);
    expect(result.current.installations).toEqual([]);
  });
});
