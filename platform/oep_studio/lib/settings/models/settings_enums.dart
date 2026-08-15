/// Small, self-contained enumerations used by [UserConfiguration]'s
/// sub-models (Work Package 017 STUDIO-TASK-000053; SDD-023). Bundled
/// into one file — unlike Work Package 016's one-enum-per-file
/// precedent — because each of these is a single-page settings choice
/// with no independent behavior of its own, and fifteen near-empty
/// files would obscure rather than clarify the settings surface; see
/// `docs/STUDIO_SETTINGS.md` Package Decisions.
library;

/// General > Logging. Also read (never written) by the Diagnostics page.
enum LoggingLevel { error, warning, info, debug, trace }

/// General > Units.
enum UnitSystem { metric, imperial }

/// General > Date Format.
enum DateFormatPreference { iso8601, us, eu }

/// General > Time Format.
enum TimeFormatPreference { h24, h12 }

/// General > Startup Behavior.
enum StartupBehaviorPreference { showDashboard, resumeLastWorkspace }

/// Appearance > Theme. Studio ships a single ratified dark theme
/// (`StudioTheme.dark`) — selecting `light` or `system` here is stored,
/// validated, and versioned like any other setting, but does not yet
/// change the rendered theme (see `docs/STUDIO_SETTINGS.md`
/// Architectural Observations).
enum StudioThemePreference { dark, light, system }

/// Appearance > Density.
enum UiDensity { comfortable, compact }

/// Workspace > Window Behavior.
enum WindowBehaviorPreference { rememberSize, alwaysMaximized }

/// Repository > Validation Defaults.
enum ValidationStrictness { lenient, standard, strict }

/// Knowledge Studio > Context Display.
enum ContextDisplayMode { tree, flat }

/// Knowledge Studio > Entity Display.
enum EntityDisplayMode { grouped, flat }

/// Knowledge Studio > Review Preferences.
enum ReviewSortPreference { newestFirst, oldestFirst }

/// Artificial Intelligence > Reasoning Depth.
enum ReasoningDepthPreference { standard, extended }

/// Updates > Update Channel.
enum UpdateChannel { stable, preview, nightly }

/// Security > Credential Storage.
enum CredentialStorageBackend { operatingSystem, none }
