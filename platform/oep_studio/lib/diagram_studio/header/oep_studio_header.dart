import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/studio_colors.dart';
import '../webview/legacy_v2_webview.dart';

/// OEP-STUDIO-BRANDING-V1 — the two view-perspectives this single header
/// (and single underlying document/session — see [OepStudioHeader]'s own
/// doc comment) can present as. NOT a second route/page/document: this is
/// the presentation-layer counterpart of V2's own already-real
/// `toggleSimPanel()` state (`js/ui/sim-panel.js`), never a new authority
/// of its own.
enum OepStudioView { diagram, simulation }

/// Page-scoped (not persisted, always starts on [OepStudioView.diagram]) —
/// same lifetime/pattern as [dmmPanelVisibleProvider]/
/// [compareModeEnabledProvider] (`diagram_studio/compare/diagram_with_compare_pane.dart`).
final oepStudioViewProvider =
    StateProvider<OepStudioView>((ref) => OepStudioView.diagram);

/// OEP-STUDIO-BRANDING-V1 — the shared OEP application header: master
/// logo, the active Studio's own identity mark/title/subtitle, and the
/// OEP-branded view-swap control. Sits above [WebSurfacesHostPage]'s own
/// tab strip (`web_surface/web_surfaces_host_page.dart`) — presentation
/// only, per this task's own §25 constraint ("do not put business logic
/// in the header"): every real state change (which view is active, and
/// the live V2 page's own Simulate-panel visibility) lives in
/// [oepStudioViewProvider] and [legacyV2ToggleSimulationViewProvider]
/// respectively, both owned elsewhere.
///
/// **Why one header, not two Studio pages:** per direct product
/// direction, there is no separate "Simulation Studio" route — Diagram
/// Studio is the one real screen, and "Simulation view" is a
/// perspective/mode of that same open document (the same tabs, the same
/// session), not a second Studio. This widget's [OepStudioView] param is
/// therefore what changes, not which widget is mounted — asked for
/// explicitly: "Do NOT create separate Diagram Studio and Simulation
/// Studio routes just for the visual design."
///
/// **Asset provenance** — `assets/branding/*.svg` are supplied,
/// pre-approved artwork (OEP_Branding_V1_SVG_Assets), used directly and
/// verbatim; nothing under `assets/branding/` in this repo was traced,
/// redrawn, or approximated from the concept-board renders — those stay
/// references for layout/proportion only, per direct instruction.
/// `oep_logo.svg` is the full lockup (mark + "OPEN ENGINEERING PLATFORM"
/// wordmark baked into the SVG itself); `oep_logo_compact.svg` is the
/// same mark without the wordmark, used here at header size, since a
/// second, Flutter-rendered "Open Engineering Platform" caption would
/// duplicate what the full logo already says. `diagram_studio_mark.svg`/
/// `simulation_studio_mark.svg` are the two Studio marks (shared hexagon
/// container, blue vs. teal). `oep_view_swap.svg` is the swap symbol
/// (the same hexagon, two opposing directional paths through it).
class OepStudioHeader extends ConsumerWidget {
  const OepStudioHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(oepStudioViewProvider);
    final isDiagram = view == OepStudioView.diagram;
    final accent = isDiagram ? const Color(0xFF4C8DFF) : const Color(0xFF22D3C7);
    final title = isDiagram ? 'Diagram' : 'Simulation';
    final subtitle = isDiagram
        ? 'DESIGN • EXPLORE • ANALYZE • DOCUMENT'
        : 'RUN • OBSERVE • MEASURE • DIAGNOSE';
    final destination = isDiagram ? OepStudioView.simulation : OepStudioView.diagram;
    final destinationLabel = isDiagram ? 'Simulation View' : 'Diagram View';
    final studioMarkAsset = isDiagram
        ? 'assets/branding/diagram_studio_mark.svg'
        : 'assets/branding/simulation_studio_mark.svg';

    return LayoutBuilder(builder: (context, constraints) {
      // §17 — the header must compress gracefully, never overlap/clip.
      // Below ~760px there isn't room for the subtitle line AND the
      // swap control's own two-line label without collision (measured
      // against this row's real min-intrinsic widths at 12-13px type) —
      // the subtitle is the one explicitly named as droppable first
      // (§17: "reduce subtitle visibility"), so it goes first, then the
      // swap control's text collapses to icon+tooltip (§17's own
      // explicit fallback) below ~560px.
      final compact = constraints.maxWidth < 760;
      final veryCompact = constraints.maxWidth < 560;
      return Container(
        height: veryCompact ? 48 : (compact ? 60 : 72),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: StudioColors.surface,
          border: Border(bottom: BorderSide(color: StudioColors.border)),
        ),
        child: Row(
          children: [
            SvgPicture.asset('assets/branding/oep_logo_compact.svg', height: veryCompact ? 20 : 26),
            const SizedBox(width: 12),
            Container(width: 1, height: 30, color: StudioColors.border),
            const SizedBox(width: 12),
            SvgPicture.asset(studioMarkAsset, height: veryCompact ? 26 : 36),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$title ',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: StudioColors.textPrimary,
                          fontSize: veryCompact ? 16 : 23,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Studio',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontSize: veryCompact ? 16 : 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (!compact)
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StudioColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
            _ViewSwapControl(
              accent: accent,
              destination: destination,
              destinationLabel: destinationLabel,
              showLabel: !veryCompact,
            ),
          ],
        ),
      );
    });
  }
}

class _ViewSwapControl extends ConsumerWidget {
  const _ViewSwapControl({
    required this.accent,
    required this.destination,
    required this.destinationLabel,
    required this.showLabel,
  });

  final Color accent;
  final OepStudioView destination;
  final String destinationLabel;
  final bool showLabel;

  Future<void> _handleSwap(WidgetRef ref) async {
    ref.read(oepStudioViewProvider.notifier).state = destination;
    // §10/§23.8 — the swap must still change the real view, not just this
    // header's own chrome: forwards into the live, primary V2 page's own
    // already-working Simulate-panel toggle when one is currently
    // mounted/ready. A `null` hook (no primary instance ready yet) still
    // leaves the header's own title/subtitle/mark swap in effect.
    final toggle = ref.read(legacyV2ToggleSimulationViewProvider);
    if (toggle != null) await toggle();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semanticLabel = 'Switch to $destinationLabel';
    return Tooltip(
      message: semanticLabel,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            focusColor: accent.withValues(alpha: 0.18),
            hoverColor: accent.withValues(alpha: 0.10),
            splashColor: accent.withValues(alpha: 0.22),
            highlightColor: accent.withValues(alpha: 0.14),
            onTap: () => _handleSwap(ref),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: accent.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset('assets/branding/oep_view_swap.svg', height: 20),
                  if (showLabel) ...[
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'SWITCH TO',
                          style: TextStyle(
                            color: StudioColors.textSecondary,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          destinationLabel,
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
