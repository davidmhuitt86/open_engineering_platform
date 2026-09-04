import { useEffect, useRef, useState } from 'react';
import { ExchangeApiError } from '@oep-exchange/exchange-client';

export type AsyncState<T> =
  { status: 'loading' } | { status: 'success'; data: T } | { status: 'error'; message: string };

/**
 * The shared loading/data/error state machine every page uses to call
 * `exchange-client` (WP-EXC-009.md §7: "API integration... State
 * management... Error handling... Loading states"). Re-runs whenever
 * `deps` changes; a stale response from a superseded call (e.g. the user
 * changed the search query before the previous request resolved) is
 * discarded rather than overwriting newer state.
 */
export function useAsync<T>(fn: () => Promise<T>, deps: readonly unknown[]): AsyncState<T> {
  const [state, setState] = useState<AsyncState<T>>({ status: 'loading' });
  const callId = useRef(0);

  useEffect(() => {
    const thisCall = ++callId.current;
    setState({ status: 'loading' });

    fn().then(
      (data) => {
        if (callId.current === thisCall) {
          setState({ status: 'success', data });
        }
      },
      (error: unknown) => {
        if (callId.current === thisCall) {
          setState({ status: 'error', message: messageFor(error) });
        }
      },
    );
    // No react-hooks/exhaustive-deps plugin is configured in this repo
    // (see eslint.config.js) — `deps` is this hook's own explicit,
    // caller-controlled dependency list, not derived from `fn`'s closure.
  }, deps);

  return state;
}

function messageFor(error: unknown): string {
  if (error instanceof ExchangeApiError) {
    return error.message;
  }
  if (error instanceof Error) {
    return error.message;
  }
  return 'Something went wrong.';
}
