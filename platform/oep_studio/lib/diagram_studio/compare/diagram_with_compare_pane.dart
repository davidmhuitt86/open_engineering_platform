import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/engineering_project_service.dart'
    show primaryDiagramInstanceId;
import '../../core/theme/studio_colors.dart';
import '../analysis/analysis_results_panel.dart';
import '../instruments/multimeter/digital_multimeter_instrument_panel.dart';
import '../trace/trace_inspector_panel.dart';
import '../webview/legacy_v2_webview.dart';
import 'compare_diagram_controller.dart';
import 'compare_legacy_v2_webview.dart';

/// AP-EK-020 Part B — whether the Analysis results panel is currently
/// shown alongside the Primary diagram. Mirrors [compareModeEnabledProvider]
/// exactly: page-scoped UI toggle, not persisted, always starts closed.
final analysisPanelVisibleProvider = StateProvider<bool>((ref) => false);

/// PRODUCT-READINESS-008 §19/§20 — whether the Digital Multimeter
/// instrument panel is currently shown alongside the Primary diagram.
/// Shares this content area's one side-panel slot with Analysis/Compare
/// (same established precedent as [analysisPanelVisibleProvider]'s own
/// doc comment) — page-scoped UI toggle, not persisted, always starts
/// closed.
final dmmPanelVisibleProvider = StateProvider<bool>((ref) => false);

/// PRODUCT-READINESS-009 §20/§21 — whether the Trace Inspector panel is
/// currently shown alongside the Primary diagram. Shares this content
/// area's one side-panel slot with Analysis/Compare/DMM (same established
/// precedent as [dmmPanelVisibleProvider]'s own doc comment) — page-scoped
/// UI toggle, not persisted, always starts closed.
final tracePanelVisibleProvider = StateProvider<bool>((ref) => false);

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

  /// AP-DIAGRAM-TOOLBAR-STATIC-001 — Analysis/Compare/DMM/Trace's own
  /// mutual exclusion used to be enforced by CONDITIONALLY RENDERING
  /// only the buttons for whichever panes weren't currently open (the
  /// other three simply weren't in the widget tree at all) — direct
  /// report: switching panes changed this row's own child count, and
  /// since the row is right-aligned, every remaining button visibly
  /// shifted position, obscuring whatever sat to its right. This turns
  /// off the OTHER three panes' own flags directly instead, so all four
  /// buttons stay in the tree, at the same position, for the toolbar's
  /// entire lifetime — only each button's own icon/label still reflects
  /// whether IT is the active one.
  void _deactivateOthers(WidgetRef ref, {required String except}) {
    if (except != 'analysis') ref.read(analysisPanelVisibleProvider.notifier).state = false;
    if (except != 'compare') ref.read(compareModeEnabledProvider.notifier).state = false;
    if (except != 'dmm') ref.read(dmmPanelVisibleProvider.notifier).state = false;
    if (except != 'trace') ref.read(tracePanelVisibleProvider.notifier).state = false;
  }

  void _toggleAnalysis(WidgetRef ref, bool analysisEnabled) {
    if (!analysisEnabled) _deactivateOthers(ref, except: 'analysis');
    ref.read(analysisPanelVisibleProvider.notifier).state = !analysisEnabled;
  }

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
    if (!context.mounted) return;
    _deactivateOthers(ref, except: 'compare');
    ref.read(compareModeEnabledProvider.notifier).state = true;
  }

  void _toggleDmm(WidgetRef ref, bool dmmEnabled) {
    if (!dmmEnabled) _deactivateOthers(ref, except: 'dmm');
    ref.read(dmmPanelVisibleProvider.notifier).state = !dmmEnabled;
  }

  void _toggleTrace(WidgetRef ref, bool traceEnabled) {
    if (!traceEnabled) _deactivateOthers(ref, except: 'trace');
    ref.read(tracePanelVisibleProvider.notifier).state = !traceEnabled;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AP-DIAGRAM-TOOLBAR-STATIC-001 — each flag is now a plain read of
    // its own provider, not gated by the others: mutual exclusion is
    // enforced once, at the point of activation (`_toggleAnalysis`/
    // `_toggleCompare`/`_toggleDmm`/`_toggleTrace`, all above), so at
    // most one of these is ever true regardless of how this getter
    // computes it — the `!compareEnabled && ...` chain this used to be
    // was doing double duty as BOTH the mutual-exclusion mechanism AND
    // each button's own conditional-render gate, which is what made the
    // toolbar's own child count (and therefore its right-aligned
    // position) change every time a pane opened.
    final compareEnabled = ref.watch(compareModeEnabledProvider);
    final analysisEnabled = ref.watch(analysisPanelVisibleProvider);
    final dmmEnabled = ref.watch(dmmPanelVisibleProvider);
    final traceEnabled = ref.watch(tracePanelVisibleProvider);
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
                // Analysis, Compare, the DMM, and Trace share this content
                // area's one side-panel slot (AP-EK-020 Part B — kept to
                // the smallest implementation that proves the
                // requirement, matching Compare's own existing
                // primary-tab-only scope); only one is open at a time,
                // enforced by the toggle handlers above -- all four
                // buttons stay in the tree, always, at a fixed position
                // (direct report: conditionally rendering only the
                // buttons for closed panes changed this row's own width,
                // and since it's right-aligned, every remaining button
                // visibly shifted and could obscure whatever sat past it).
                TextButton.icon(
                  onPressed: () => _toggleAnalysis(ref, analysisEnabled),
                  icon: Icon(
                      analysisEnabled
                          ? Icons.close
                          : Icons.analytics_outlined,
                      size: 15),
                  label: Text(analysisEnabled ? 'Close Analysis' : 'Analysis',
                      style: const TextStyle(fontSize: 12)),
                ),
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
                TextButton.icon(
                  onPressed: () => _toggleDmm(ref, dmmEnabled),
                  icon: Icon(dmmEnabled ? Icons.close : Icons.speed, size: 15),
                  label: Text(dmmEnabled ? 'Close Multimeter' : 'Multimeter',
                      style: const TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () => _toggleTrace(ref, traceEnabled),
                  icon: Icon(
                      traceEnabled ? Icons.close : Icons.route_outlined,
                      size: 15),
                  label: Text(traceEnabled ? 'Close Trace' : 'Trace Circuit',
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
                  : dmmEnabled
                      ? const Row(
                          children: [
                            Expanded(child: LegacyV2WebViewPage()),
                            VerticalDivider(width: 1, color: StudioColors.border),
                            SizedBox(
                              width: 340,
                              child: DigitalMultimeterInstrumentPanel(),
                            ),
                          ],
                        )
                      : traceEnabled
                          ? const Row(
                              children: [
                                Expanded(child: LegacyV2WebViewPage()),
                                VerticalDivider(width: 1, color: StudioColors.border),
                                SizedBox(
                                  width: 340,
                                  child: TraceInspectorPanel(),
                                ),
                              ],
                            )
                          : const LegacyV2WebViewPage(),
        ),
      ],
    );
  }
}
