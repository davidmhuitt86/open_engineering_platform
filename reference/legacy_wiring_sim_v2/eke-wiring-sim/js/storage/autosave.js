/**
 * storage/autosave.js
 *
 * Debounced autosave to localStorage whenever the project state changes.
 *
 * Phase 2 placeholder.
 *
 * Phase 2 goal:
 *   const autosave = new Autosave({ key: 'eke-trx300', debounceMs: 2000 });
 *   autosave.onChange(() => autosave.schedule(getProjectSnapshot()));
 *
 * Methods:
 *   schedule(data)   → debounces write by debounceMs
 *   flush()          → write immediately
 *   enable() / disable()
 *   loadLast()       → return last autosaved snapshot or null
 *
 * No DOM. No rendering. No electrical logic.
 */
