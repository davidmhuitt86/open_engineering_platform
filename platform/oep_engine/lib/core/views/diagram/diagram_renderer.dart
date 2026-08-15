/// Marker interface for a concrete Diagram View renderer.
///
/// The Engineering Engine never implements one of these itself (SDD-025/026
/// forbid Flutter Widgets/dart:ui in engine code) — a Flutter-side painter
/// (e.g. the Demonstration Host's `CustomPainter`) implements this and
/// registers with [DiagramRendererRegistry] under its [id] so a host
/// application can offer a "Renderer selection framework" (STUDIO-TASK-000063)
/// without the engine knowing what Flutter is.
abstract class DiagramSceneRenderer {
  String get id;
  String get displayName;
}

/// Discovery point for registered [DiagramSceneRenderer]s. Selection is by
/// [DiagramSceneRenderer.id]; resolving and actually painting a scene is
/// entirely the host application's responsibility.
class DiagramRendererRegistry {
  final Map<String, DiagramSceneRenderer> _renderers = {};

  void register(DiagramSceneRenderer renderer) {
    _renderers[renderer.id] = renderer;
  }

  DiagramSceneRenderer? resolve(String id) => _renderers[id];

  List<DiagramSceneRenderer> get all => _renderers.values.toList(growable: false);
}
