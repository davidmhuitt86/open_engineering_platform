import { pathToFileURL } from 'node:url';
import { buildApp } from './app.js';

const port = Number(process.env.PORT ?? 3000);
const host = process.env.HOST ?? '0.0.0.0';

async function start(): Promise<void> {
  const app = await buildApp({ logger: true });
  try {
    await app.listen({ port, host });
  } catch (error) {
    app.log.error(error);
    process.exit(1);
  }
}

// Only start the server when this module is run directly (`node
// dist/server.js` / `tsx src/server.ts`) — not when `buildApp` is
// imported by a test, which must never bind a real port.
const isMain =
  process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) {
  void start();
}
