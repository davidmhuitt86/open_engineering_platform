/// AP-STUDIO-WEB-SURFACE-001/002 — the model half of the Web Surface
/// abstraction. Deliberately the **smallest** model that supports the
/// requirements across both tasks — see
/// `docs/OEP_STUDIO_WEB_SURFACE_ARCHITECTURE.md` §3 for why this shape,
/// not `StudioSurface`/`NativeSurface`/`WebSurface` or a
/// `StudioTab`/`NativeTabContent`/`WebTabContent` split, was chosen: the
/// existing Diagram Studio tab system (`diagram_studio/tabs/`) is a
/// document-*reference* model over one shared `EditingSession` (confirmed
/// by reading `DiagramTab`'s own doc comment, Phase 1) — fundamentally
/// incompatible with a Web Surface's need for genuinely independent,
/// simultaneously-alive per-tab state (URL, JS runtime, history). A Web
/// Surface tab is therefore its own small, separate concept, not a new
/// case grafted onto `DiagramTab`.
library;

enum WebSurfaceKind {
  /// Loaded from this machine's filesystem via `file://` — Legacy V2 and
  /// the POC's second local test app are both this kind.
  local,

  /// Loaded from a normal `http(s)://` URL — arbitrary remote content.
  remote,
}

/// Classifies a URL as [WebSurfaceKind.local] or [WebSurfaceKind.remote]
/// by scheme alone — the only signal that's actually trustworthy without
/// executing any page content (Phase 8 of AP-STUDIO-WEB-SURFACE-001:
/// "distinguish local engineering applications from remote web content").
WebSurfaceKind classifyWebSurfaceUrl(String url) {
  final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
  return scheme == 'file' ? WebSurfaceKind.local : WebSurfaceKind.remote;
}

/// AP-STUDIO-WEB-SURFACE-002, Phase 7/8 — **which view widget renders
/// this surface**, and (via [WebSurface.bridgeAuthorized]) the sole
/// determinant of bridge access. This is a closed, compile-time-checked
/// set — not a boolean flag a caller could accidentally set true for a
/// generic surface.
enum WebSurfaceApplication {
  /// Rendered by the existing, unmodified `LegacyV2WebViewPage` (which
  /// already composes `LegacyV2BridgeTransport`/`LegacyV2StateAdapter` —
  /// untouched by this task, per Phase 7's "do not force the generic
  /// WebSurfaceView to understand V2"). The only value for which
  /// [WebSurface.bridgeAuthorized] is `true`.
  legacyV2,

  /// Rendered by the generic `WebSurfaceView` — zero OEP bridge access,
  /// structurally, not by convention (§ [WebSurface.bridgeAuthorized]).
  generic,
}

/// One Web Surface tab's identity/metadata — intentionally holds no
/// `WebviewController` or Flutter widget state; those live in the
/// relevant view widget's own `State`, matching the module bridge's own
/// "adapter holds mapping, widget holds the live object" separation.
class WebSurface {
  WebSurface({
    required this.id,
    required this.title,
    required this.initialUrl,
    this.application = WebSurfaceApplication.generic,
  }) : kind = classifyWebSurfaceUrl(initialUrl);

  final String id;
  final String title;
  final String initialUrl;
  final WebSurfaceKind kind;
  final WebSurfaceApplication application;

  /// AP-STUDIO-WEB-SURFACE-002, Phase 8 — **structurally derived, not a
  /// constructor parameter**: there is no way to construct a `WebSurface`
  /// with `application: WebSurfaceApplication.generic` that also reports
  /// `bridgeAuthorized == true`. This is the "minimum structural
  /// enforcement necessary so that a generic WebSurface cannot
  /// accidentally acquire the Legacy V2 bridge" this task calls for —
  /// removing `bridgeAuthorized` as a settable field (it was one, with a
  /// default of `false`, in AP-STUDIO-WEB-SURFACE-001) closes the
  /// accidental-`true` path entirely rather than relying on every call
  /// site remembering to leave it at its default.
  bool get bridgeAuthorized => application == WebSurfaceApplication.legacyV2;

  WebSurface copyWith({String? title}) => WebSurface(
        id: id,
        title: title ?? this.title,
        initialUrl: initialUrl,
        application: application,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'initialUrl': initialUrl,
        'application': application.name,
      };

  static WebSurface? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final title = json['title'];
    final initialUrl = json['initialUrl'];
    if (id is! String || title is! String || initialUrl is! String) return null;
    final applicationName = json['application'];
    final application = WebSurfaceApplication.values
        .where((a) => a.name == applicationName)
        .firstOrNull;
    return WebSurface(
      id: id,
      title: title,
      initialUrl: initialUrl,
      application: application ?? WebSurfaceApplication.generic,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
