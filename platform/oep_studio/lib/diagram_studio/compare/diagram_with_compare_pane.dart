import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/engineering_project_service.dart'
    show primaryDiagramInstanceId;
import '../../core/theme/studio_colors.dart';
import '../analysis/analysis_results_panel.dart';
import '../webview/legacy_v2_webview.dart';
import 'compare_diagram_controller.dart';
import 'compare_legacy_v2_webview.dart';

/// AP-EK-020 Part B — whether the Analysis results panel is currently
/// shown alongside the Primary diagram. Mirrors [compareModeEnabledProvider]
/// exactly: page-scoped UI toggle, not persisted, always starts closed.
final analysisPanelVisibleProvider = StateProvider<bool>((ref) => false);

/// AP-OEP-DIAGRAM-COMPARE-001 — whether the Diagram content area is
/// currently showing the Compare pane split alongside the Primary
/// diagram. Page-scoped UI toggle only — not a context/selection
/// authority, and not persisted (Compare always starts closed). Shared
/// (not duplicated) across every place Diagram Studio's real content is
/// embedded, so turning Compare on in one place is reflected everywhere
/// that content is shown.
final compareModeEnabledProvider = StateProvider<bool>((ref) => false);

/// The actual Diagram Studio content, wherever it's embedded: the
/// existing Primary `LegacyV2WebViewPage`, plus a small toggle for
/// splitting the same content area to also show an independent Compare
/// diagram side by side.
///
/// **Used in two places** — both are genuine embeddings of "Diagram
/// Studio's real content," not two different features:
///   1. `EngineeringWorkspacePage`'s own Diagram Workspace tab.
///   2. `WebSurfacesHostPage`'s Diagram Studio tab — the page reached by
///      the sidebar's "Diagram Studio" row today (`/diagram`), which is
///      the default way most users reach Diagram Studio at all. Compare
///      only being wired into (1) and not (2) was a real gap — a user
///      who reaches Diagram Studio via the sidebar (not via the
///      Workspace tab specifically) would never see the Compare button.
///
/// Turning Compare on prompts for a second document (the native file
/// picker, the same `openFile()` pattern already used for Source
/// Material import) and opens it in the Compare pane's own, fully
/// independent `compareDiagramControllerProvider`/
/// `compareEngineeringProjectServiceProvider`. Turning it off hides the
/// pane again — its engine/session stay alive underneath (not
/// disposed), matching the same "don't destroy on merely hiding"
/// principle already established for Workspace tabs.
class DiagramWithComparePane extends ConsumerWidget {
  const DiagramWithComparePane({super.key});

  Future<void> _toggleCompare(BuildContext context, WidgetRef ref) async {
    final enabled = ref.read(compareModeEnabledProvider);
    if (enabled) {
      ref.read(compareModeEnabledProvider.notifier).state = false;
      return;
    }
    final picked = await openFile();
    if (picked == null) return;
    if (!context.mounted) return;
    await ref
        .read(compareDiagramControllerProvider.future)
        .then((c) => c.openDocument(picked.path));
    ref.read(compareModeEnabledProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compareEnabled = ref.watch(compareModeEnabledProvider);
    final analysisEnabled =
        !compareEnabled && ref.watch(analysisPanelVisibleProvider);
    return Column(
      children: [
        Container(
          height: 28,
          alignment: Alignment.centerRight,
          decoration: const BoxDecoration(
            color: StudioColors.surfaceSunken,
            border: Border(bottom: BorderSide(color: StudioColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Analysis and Compare share this content area's one
                // side-panel slot (AP-EK-020 Part B — kept to the
                // smallest implementation that proves the requirement,
                // matching Compare's own existing primary-tab-only
                // scope); Compare disabled while Analysis is open.
                if (!compareEnabled)
                  TextButton.icon(
                    onPressed: () => ref
                        .read(analysisPanelVisibleProvider.notifier)
                        .state = !analysisEnabled,
                    icon: Icon(
                        analysisEnabled
                            ? Icons.close
                            : Icons.analytics_outlined,
                        size: 15),
                    label: Text(analysisEnabled ? 'Close Analysis' : 'Analysis',
                        style: const TextStyle(fontSize: 12)),
                  ),
                if (!analysisEnabled)
                  TextButton.icon(
                    onPressed: () => _toggleCompare(context, ref),
                    icon: Icon(
                        compareEnabled
                            ? Icons.vertical_split
                            : Icons.compare_arrows,
                        size: 15),
                    label: Text(
                        compareEnabled ? 'Close Compare' : 'Compare Diagrams',
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: compareEnabled
              ? Row(
                  children: const [
                    Expanded(child: LegacyV2WebViewPage()),
                    VerticalDivider(width: 1, color: StudioColors.border),
                    Expanded(child: CompareLegacyV2WebViewPage()),
                  ],
                )
              : analysisEnabled
                  ? Row(
                      children: const [
                        Expanded(child: LegacyV2WebViewPage()),
                        VerticalDivider(width: 1, color: StudioColors.border),
                        SizedBox(
                          width: 340,
                          child: AnalysisResultsPanel(
                              instanceId: primaryDiagramInstanceId),
                        ),
                      ],
                    )
                  : const LegacyV2WebViewPage(),
        ),
      ],
    );
  }
}
