/**
 * ui/dialogs.js
 *
 * Modal dialogs for data entry:
 *   - Add module dialog (#add-modal)
 *   - Edit module properties dialog (#mpm)
 *   - Wire properties dialog (#wpm)
 *   - Confirm delete dialog (uses native confirm())
 *
 * Phase 1: dialog open/close/submit logic lives in app.js:
 *   openAdd(), openAddConn(), openAddP(), closeAddModal(), commitAddModule()
 *   editModProps(), saveModProps(), addMpmTerm(), addMpmPin(), closeMpm()
 *   editWireProps(), saveWireProps(), closeWPM()
 *
 * Phase 2 goal: Dialogs module with consistent open/close API
 * and validation separate from business logic.
 *
 * No electrical logic. No rendering of diagram elements.
 */
