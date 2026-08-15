import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // exchange-api has no CORS headers (WP-EXC-001 §2 excludes auth/CORS
    // concerns entirely) — proxying keeps every request same-origin in
    // dev instead of adding CORS middleware to the already-approved API.
    // A production deployment is expected to front both with a single
    // reverse proxy the same way (see docs/guides/FRONTEND_GUIDE.md).
    proxy: {
      '/api': {
        target: process.env.OEP_EXCHANGE_API_PROXY_TARGET ?? 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
  test: {
    environment: 'jsdom',
    include: ['src/**/*.test.{ts,tsx}'],
    setupFiles: ['./src/test-setup.ts'],
  },
});
