/**
 * ui/toolbar.js
 *
 * Manages the top toolbar: mode buttons, zoom controls, search, legend, theme.
 *
 * Phase 1: toolbar button handlers are inline onclick attributes in index.html
 *          pointing to global functions in app.js (toggleEdit, toggleWireMode,
 *          zReset, zBy, toggleSearch, toggleLegend, toggleTheme, saveLayout,
 *          loadLayoutFile, exportSVG, openModPanel).
 *
 * Phase 2 goal: Toolbar class that:
 *   - Binds all toolbar button events
 *   - Reflects mode state (active classes, button text)
 *   - Responds to mode changes from editor/selection-manager
 *
 * No electrical logic. No rendering of diagram elements.
 */
