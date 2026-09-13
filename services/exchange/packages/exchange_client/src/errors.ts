/**
 * Thrown by `ExchangeApiClient` for every non-2xx Exchange API response.
 *
 * Contract established from actual usage, not invented: `status`/`code`/
 * `message` is the exact constructor shape
 * `apps/publisher-portal/src/hooks/use-async.test.ts` already pins
 * (`new ExchangeApiError(404, 'NOT_FOUND', 'not found')`), and `message`
 * is exactly what `messageFor()` in `use-async.ts` reads via
 * `error.message` after an `instanceof ExchangeApiError` check. `code`
 * mirrors `@oep-exchange/api-contracts`'s `ApiErrorResponse.error.code` --
 * every route in `apps/exchange-api` already serializes its failures
 * through `toApiErrorResponse(DomainError)`, so `code` is the same stable,
 * machine-readable identifier a caller can already rely on there.
 *
 * A transport-level failure (the network request itself failing, or the
 * server being unreachable) is a plain `Error`/`TypeError` from `fetch`,
 * not an `ExchangeApiError` -- existing consumers already distinguish the
 * two (`use-async.ts`'s `messageFor` checks `instanceof ExchangeApiError`
 * first, then falls back to `instanceof Error`), so this class is never
 * thrown for anything but a real HTTP response the server actually sent.
 */
export class ExchangeApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = new.target.name;
  }
}
