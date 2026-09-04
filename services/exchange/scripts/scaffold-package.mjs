// One-off scaffolding generator used during TASK-EXC-0001 to stamp out
// consistent, buildable-and-testable package skeletons. Not part of the
// runtime or build graph itself — safe to delete once every workspace
// package exists; kept here (rather than removed) as a documented,
// reusable tool for any future WP-EXC-0XX package addition.
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname.replace(/^\/([a-zA-Z]:)/, '$1');

const packages = [
  {
    dir: 'manifest',
    name: 'manifest',
    purpose: 'Parses and validates OEP Package Manifests (PKG-002).',
    deps: ['core'],
    owner: 'TASK-EXC-0005 (Upload Pipeline)',
    scope: 'in-scope',
  },
  {
    dir: 'signing',
    name: 'signing',
    purpose: 'Verifies package digital signatures (PKG-005) during upload.',
    deps: ['core'],
    owner: 'TASK-EXC-0005 (Upload Pipeline)',
    scope: 'in-scope',
  },
  {
    dir: 'search',
    name: 'search',
    purpose: "Indexes and queries the Package Catalog's search index.",
    deps: ['core', 'api-contracts'],
    owner: 'TASK-EXC-0006 (Search API)',
    scope: 'in-scope',
  },
  {
    dir: 'package_manager',
    name: 'package-manager',
    purpose:
      'Orchestrates the upload pipeline: validation, manifest parsing, metadata extraction, signature verification, and catalog registration.',
    deps: ['core', 'manifest', 'signing'],
    owner: 'TASK-EXC-0005 (Upload Pipeline)',
    scope: 'in-scope',
  },
  {
    dir: 'exchange_client',
    name: 'exchange-client',
    purpose:
      'A typed HTTP client SDK for the Exchange REST API, used by the installer, update service, and both web apps.',
    deps: ['core', 'api-contracts'],
    owner: 'TASK-EXC-0007 (Download API)',
    scope: 'in-scope',
  },
  {
    dir: 'dependency_resolver',
    name: 'dependency-resolver',
    purpose: 'Resolves Engineering Package dependency graphs (PKG-004).',
    deps: ['core', 'manifest'],
    owner: 'not yet scheduled',
    scope: 'deferred',
    scopeNote:
      "Not explicitly required by WP-EXC-001's MVP scope (a single package install has no dependency graph to resolve yet) — scaffolded now because the directory already existed, left otherwise empty until a future work package needs real multi-package dependency resolution.",
  },
  {
    dir: 'installer',
    name: 'installer',
    purpose:
      'Invokes the Package Transaction Engine and Repository Merge Engine, through public Repository interfaces only, to install a downloaded package into an OEP Repository.',
    deps: ['core', 'exchange_client'],
    owner: 'TASK-EXC-0008 (Repository Integration)',
    scope: 'in-scope',
  },
  {
    dir: 'update_service',
    name: 'update-service',
    purpose: 'Checks installed packages for available updates.',
    deps: ['core', 'exchange_client'],
    owner: 'not yet scheduled',
    scope: 'deferred',
    scopeNote:
      "Not in WP-EXC-001's explicit deliverable list — scaffolded now because the directory already existed, left otherwise empty until a future work package.",
  },
  {
    dir: 'licensing',
    name: 'licensing',
    purpose: 'License issuance, entitlements, and subscription validation (EXC-005).',
    deps: ['core'],
    owner: 'WP-EXC-003 (Licensing & Entitlements)',
    scope: 'excluded',
    scopeNote:
      'Explicitly excluded from WP-EXC-001 ("Licensing beyond Free Packages" — see the task doc\'s own Scope §5 Excluded list). Intentionally empty beyond this scaffold.',
  },
  {
    dir: 'payments',
    name: 'payments',
    purpose: 'Commerce: purchases, subscriptions, and revenue distribution (EXC-010).',
    deps: ['core'],
    owner: 'WP-EXC-004 (Commerce)',
    scope: 'excluded',
    scopeNote:
      'Explicitly excluded from WP-EXC-001 ("Commerce", "Revenue Distribution" — see the task doc\'s own Scope §5 Excluded list). Intentionally empty beyond this scaffold.',
  },
  {
    dir: 'reviews',
    name: 'reviews',
    purpose: 'Ratings, reviews, verification badges, and publisher reputation (EXC-006).',
    deps: ['core', 'api-contracts'],
    owner: 'WP-EXC-002 (Reviews & Verification)',
    scope: 'excluded',
    scopeNote:
      'Explicitly excluded from WP-EXC-001 ("Reviews", "Ratings" — see the task doc\'s own Scope §5 Excluded list). Intentionally empty beyond this scaffold.',
  },
];

const depScopedName = (dir) => {
  const found = packages.find((p) => p.dir === dir);
  if (found) return `@oep-exchange/${found.name}`;
  if (dir === 'core') return '@oep-exchange/core';
  if (dir === 'api-contracts') return '@oep-exchange/api-contracts';
  throw new Error(`unknown dep dir ${dir}`);
};

for (const pkg of packages) {
  const pkgRoot = join(root, 'packages', pkg.dir);
  mkdirSync(join(pkgRoot, 'src'), { recursive: true });

  const scopedName = `@oep-exchange/${pkg.name}`;
  const dependencies = Object.fromEntries(pkg.deps.map((d) => [depScopedName(d), '0.1.0']));

  const packageJson = {
    name: scopedName,
    version: '0.1.0',
    private: true,
    description: pkg.purpose,
    type: 'module',
    main: './dist/index.js',
    types: './dist/index.d.ts',
    exports: { '.': { types: './dist/index.d.ts', default: './dist/index.js' } },
    scripts: { build: 'tsc -b', test: 'vitest run' },
    ...(Object.keys(dependencies).length ? { dependencies } : {}),
    devDependencies: { typescript: '^5.7.2', vitest: '^2.1.6' },
  };
  writeFileSync(join(pkgRoot, 'package.json'), JSON.stringify(packageJson, null, 2) + '\n');

  const tsconfig = {
    extends: '../../tsconfig.base.json',
    compilerOptions: { outDir: 'dist', rootDir: 'src' },
    include: ['src'],
    ...(pkg.deps.length ? { references: pkg.deps.map((d) => ({ path: `../${d}` })) } : {}),
  };
  writeFileSync(join(pkgRoot, 'tsconfig.json'), JSON.stringify(tsconfig, null, 2) + '\n');

  writeFileSync(
    join(pkgRoot, 'vitest.config.ts'),
    `import { defineConfig } from 'vitest/config';\n\nexport default defineConfig({\n  test: {\n    environment: 'node',\n    include: ['src/**/*.test.ts'],\n  },\n});\n`,
  );

  const statusLine =
    pkg.scope === 'excluded'
      ? `Excluded from WP-EXC-001's scope. ${pkg.scopeNote}`
      : pkg.scope === 'deferred'
        ? `Deferred beyond WP-EXC-001's explicit scope. ${pkg.scopeNote}`
        : `Scaffolded in TASK-EXC-0001 (Repository Structure). Real implementation arrives in ${pkg.owner}.`;

  writeFileSync(
    join(pkgRoot, 'src', 'index.ts'),
    `/**\n * ${pkg.purpose}\n *\n * Status: ${statusLine}\n */\nexport const PACKAGE_NAME = '${scopedName}' as const;\n`,
  );

  writeFileSync(
    join(pkgRoot, 'src', 'index.test.ts'),
    `import { describe, expect, it } from 'vitest';\nimport { PACKAGE_NAME } from './index.js';\n\ndescribe('${scopedName} package scaffold', () => {\n  it('is wired into the workspace and exports its package identity', () => {\n    expect(PACKAGE_NAME).toBe('${scopedName}');\n  });\n});\n`,
  );

  const depsLine = pkg.deps.length
    ? pkg.deps.map((d) => `\`${depScopedName(d)}\``).join(', ')
    : 'nothing else in the workspace';

  writeFileSync(
    join(pkgRoot, 'README.md'),
    `# ${scopedName}\n\n${pkg.purpose}\n\n**Status:** ${statusLine}\n\n## Dependency direction\n\nDepends on ${depsLine}.\n`,
  );

  console.log(`scaffolded ${scopedName}`);
}
