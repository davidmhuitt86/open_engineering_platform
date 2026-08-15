import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

// This project does not enable Vitest's `globals` option, so
// @testing-library/react's automatic per-test cleanup (which relies on a
// global `afterEach`) never registers itself — without this, unmounted
// components from a prior test stay in `document.body` and leak into
// the next test's queries. Referenced from both this app's own
// `vite.config.ts` and the root `vitest.config.ts` (the aggregate `npm
// test` run) — guarded on `document` existing so it's a no-op for every
// other (Node-environment) package/app's test run.
afterEach(() => {
  if (typeof document !== 'undefined') {
    cleanup();
  }
});
