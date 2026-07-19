import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    // The two React web apps (publisher-portal, exchange-admin) render
    // components in their tests and need a DOM; every other package/app
    // is plain Node (Fastify server, shared libraries) and doesn't.
    environmentMatchGlobs: [
      ['apps/publisher-portal/**', 'jsdom'],
      ['apps/exchange-admin/**', 'jsdom'],
    ],
    include: ['packages/*/src/**/*.test.{ts,tsx}', 'apps/*/src/**/*.test.{ts,tsx}'],
    exclude: ['**/node_modules/**', '**/dist/**'],
    passWithNoTests: false,
  },
});
