import 'package:flutter/widgets.dart';

/// AP-OEP-SURFACE-ARCHITECTURE-002 — the smallest structure justified by
/// `docs/OEP_SURFACE_ARCHITECTURE.md` §3: only the fields already
/// evidenced by the real `WebSurface`/`_NativeTab` types this
/// generalizes, nothing speculative (no `context requirements`,
/// per-instance `capabilities`, or persistence/lifecycle metadata — §3
/// explicitly excludes those as unevidenced).
///
/// Deliberately not a replacement for `StudioDescriptor`
/// (`core/routing/studio_registry.dart`): that type owns routing
/// (`pageBuilder(BuildContext, GoRouterState)`,
/// `settingsProvider`/`searchProvider`), none of which a tab-embedded
/// Surface needs or has. [build] takes only a [BuildContext] —
/// `GoRouterState` cannot be constructed outside a real router
/// navigation (its sole constructor requires a private
/// `RouteConfiguration`, confirmed by reading `package:go_router`'s own
/// source — this is the exact, documented reason `StudioDescriptor.
/// pageBuilder` cannot be reused directly for a Surface, per the
/// architecture audit's own Phase 4 instruction to document any
/// destination that "cannot be derived cleanly").
class SurfaceDefinition {
  const SurfaceDefinition({
    required this.id,
    required this.title,
    required this.icon,
    required this.presentationTechnology,
    required this.build,
    this.allowsMultipleInstances = false,
  });

  /// Stable identity. For a native Surface, this is the underlying
  /// `StudioDestination.name` (see `SurfaceRegistry`) — reusing the one
  /// existing identity rather than inventing a second id space.
  final String id;

  final String title;
  final IconData icon;
  final SurfacePresentationTechnology presentationTechnology;

  /// Constructs the Surface's content widget. No `GoRouterState` — see
  /// class doc comment for why that's a hard requirement, not a
  /// simplification of convenience.
  final Widget Function(BuildContext context) build;

  /// AP-OEP-WORKSPACE-MULTI-INSTANCE-001 — declares whether more than one
  /// [WorkspaceTab] may exist for this Surface at once. Defaults to
  /// `false`, preserving every existing Surface's current singleton
  /// behavior (`WorkspaceTabsController.openSurface`'s one-tab-per-
  /// surfaceId rule) unless a future Surface explicitly opts in. Purely
  /// declarative here — this package only introduces the field and the
  /// generic tab-instance mechanism it describes; no Surface sets this to
  /// `true` yet (Diagram/Browser multi-instance are later packages), and
  /// [WorkspaceTabsController] does not read this field itself (a future
  /// caller — e.g. a "+"/globe menu — is what decides whether to call
  /// `openSurface` or `openNewInstance` based on it).
  final bool allowsMultipleInstances;
}

/// `docs/OEP_SURFACE_ARCHITECTURE.md` §12 — generalizes the existing,
/// real `WebSurfaceApplication` (`legacyV2`/`generic`) with the third
/// case that already exists in practice (a `_NativeTab`'s embedded
/// Flutter page) but had no name of its own until now.
enum SurfacePresentationTechnology {
  /// A native Flutter page, constructed directly (no `WebviewController`
  /// involved) — every current `_NativeTab`.
  native,

  /// The existing, unmodified `LegacyV2WebViewPage`
  /// (`WebSurfaceApplication.legacyV2` equivalent). Not used by
  /// [SurfaceRegistry] itself (Diagram Studio is deliberately excluded,
  /// § its own doc comment) — named here only so the enum is a complete,
  /// honest generalization of what [SurfacePresentationTechnology]
  /// actually covers across the app, not an artificially narrowed one.
  legacyV2WebView,

  /// A generic Web Surface (`WebSurfaceApplication.generic` equivalent).
  /// Not used by [SurfaceRegistry] itself, same reasoning as
  /// [legacyV2WebView].
  genericWeb,
}
