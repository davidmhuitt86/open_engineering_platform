import { ExchangeApiClient } from '@oep-exchange/exchange-client';
import { createContext, useContext, useMemo, type ReactNode } from 'react';

/**
 * The only place this app constructs an `ExchangeApiClient` (WP-EXC-009.md
 * §3: "No component shall communicate directly with backend services
 * outside the API client layer"). `/api/v1` is same-origin — the dev
 * server proxies it to `exchange-api` (`vite.config.ts`); a production
 * deployment is expected to front both behind one reverse proxy the same
 * way.
 */
/** Exported (not just the provider/hook) so tests can supply a fake `ExchangeApiClient` directly. */
export const ExchangeApiClientContext = createContext<ExchangeApiClient | undefined>(undefined);

export function ExchangeApiClientProvider({ children }: { children: ReactNode }): JSX.Element {
  const client = useMemo(() => new ExchangeApiClient({ baseUrl: '/api/v1' }), []);
  return (
    <ExchangeApiClientContext.Provider value={client}>{children}</ExchangeApiClientContext.Provider>
  );
}

export function useExchangeApiClient(): ExchangeApiClient {
  const client = useContext(ExchangeApiClientContext);
  if (!client) {
    throw new Error('useExchangeApiClient() must be called within an ExchangeApiClientProvider.');
  }
  return client;
}
