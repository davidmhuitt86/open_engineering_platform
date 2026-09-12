import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/studio_colors.dart';
import '../webview/legacy_v2_webview.dart';

/// The two view-perspectives of one Diagram Studio document/session —
/// NOT a second route/page. Presentation-layer counterpart of V2's own
/// `toggleSimPanel()` state (`js/ui/sim-panel.js`); never a new authority.
/// Full rationale: docs/architecture/diagram_studio/OEP-STUDIO-BRANDING-V1.md.
enum OepStudioView { diagram, simulation }

/// Page-scoped, not persisted; always starts on [OepStudioView.diagram].
final oepStudioViewProvider =
    StateProvider<OepStudioView>((ref) => OepStudioView.diagram);

/// The shared OEP application header (master logo, active Studio mark/
/// title/subtitle, view-swap control). Sits above [WebSurfacesHostPage]'s
/// tab strip. Presentation only — real state (which view is active; V2's
/// live Simulate-panel visibility) lives in [oepStudioViewProvider] and
/// [legacyV2ToggleSimulationViewProvider], both owned elsewhere; do not
/// add business logic here. Asset provenance and full design rationale:
/// docs/architecture/diagram_studio/OEP-STUDIO-BRANDING-V1.md.
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
