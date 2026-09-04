import { renderHook, waitFor } from '@testing-library/react';
import { ExchangeApiError } from '@oep-exchange/exchange-client';
import { describe, expect, test } from 'vitest';
import { useAsync } from './use-async.js';

describe('useAsync', () => {
  test('starts in the loading state', () => {
    const { result } = renderHook(() => useAsync(() => new Promise<string>(() => {}), []));
    expect(result.current).toEqual({ status: 'loading' });
  });

  test('transitions to success with the resolved data', async () => {
    const { result } = renderHook(() => useAsync(() => Promise.resolve('hello'), []));
    await waitFor(() => expect(result.current.status).toBe('success'));
    expect(result.current).toEqual({ status: 'success', data: 'hello' });
  });

  test('transitions to error with the ExchangeApiError message', async () => {
    const { result } = renderHook(() =>
      useAsync(() => Promise.reject(new ExchangeApiError(404, 'NOT_FOUND', 'not found')), []),
    );
    await waitFor(() => expect(result.current.status).toBe('error'));
    expect(result.current).toEqual({ status: 'error', message: 'not found' });
  });

  test('transitions to error with a generic message for a non-Error rejection', async () => {
    const { result } = renderHook(() => useAsync(() => Promise.reject('boom'), []));
    await waitFor(() => expect(result.current.status).toBe('error'));
    expect(result.current).toEqual({ status: 'error', message: 'Something went wrong.' });
  });

  test('discards a stale response when deps change before the first call resolves', async () => {
    let resolveFirst!: (value: string) => void;
    const first = new Promise<string>((resolve) => {
      resolveFirst = resolve;
    });

    const { result, rerender } = renderHook(
      ({ id }: { id: number }) =>
        useAsync(() => (id === 1 ? first : Promise.resolve('second')), [id]),
      { initialProps: { id: 1 } },
    );

    rerender({ id: 2 });
    await waitFor(() => expect(result.current).toEqual({ status: 'success', data: 'second' }));

    resolveFirst('first');
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(result.current).toEqual({ status: 'success', data: 'second' });
  });
});
