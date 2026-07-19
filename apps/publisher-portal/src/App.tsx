/**
 * The Publisher Portal's root component.
 *
 * Status: scaffolded in TASK-EXC-0001 (Repository Structure) — proves
 * the Vite + React + TypeScript + Vitest toolchain is wired correctly.
 * The real pages (Home, Search, Package Details, Publisher Profile,
 * Upload, My Packages) arrive in TASK-EXC-0009 (Web Interface), once
 * `exchange_client` has a real API to call.
 */
export function App(): JSX.Element {
  return (
    <main>
      <h1>OEP Engineering Exchange</h1>
      <p>Publisher Portal — scaffolded, not yet implemented.</p>
    </main>
  );
}
