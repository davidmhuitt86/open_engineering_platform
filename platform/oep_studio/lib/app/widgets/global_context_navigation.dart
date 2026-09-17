import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/oep_tokens.dart';
import '../../diagram_studio/header/oep_studio_header.dart';
import '../active_studio.dart';

/// The OEP Global Context Navigation (target shell region 04,
/// `docs/architecture/ux/design-system/OEP-SHELL-COMPONENTS.md` §5;
/// canonical reference `docs/architecture/ux/renders/oep-shell/context-navigation.svg`).
///
/// WP-UI-DS-002 (Section 06) — a GLOBAL, persistent LEFT-side shell region
/// (structural sibling of the Main Engineering Surface and Global
/// Inspector, hosted by `EngineeringWorkspacePage` at the FIRST position of
/// the same `Row` `GlobalInspector` already occupies the last position of —
/// see that page's own doc comments). Its container is global; its content
/// is Studio-scoped via [activeStudioProvider], exactly like
/// [GlobalInspector] and [GlobalToolbar].
///
/// **Context Navigation is workspace/Studio-scoped navigation, never
/// Studio SELECTION** (`AP-UX-006` §10/§16, the same frozen rule
/// [OepGlobalStudioBar] observes): nothing in this widget calls
/// `openSurface`/`openDiagramTab`/`openNewInstance`/any workspace-creation
/// API. It only ever assigns [oepStudioViewProvider] via the shared
/// [switchOepStudioView] helper.
///
/// **Per-Studio content — evidence-based, not fabricated (Rule 3,
/// `OEP-UI-RULES.md`):** a direct inspection of every Studio's own content
/// page found real, existing left-side navigation/view-switching UI in
/// exactly two places — `ExchangeStudioPage`'s `_SectionRail` and
/// `SettingsWorkspacePage`'s own category list — and genuinely NONE for
/// Home, EAM (`AcquisitionStudioPage`), Knowledge Studio, or Instruments
/// (all four are fixed, single-layout panels with no internal view
/// switching at all). Diagram Studio has exactly one real, existing
/// persistent view/mode concept: [OepStudioView.diagram]/
/// [OepStudioView.simulation] (`oepStudioViewProvider`,
/// `oep_studio_header.dart`), previously only ever shown inside the now-
/// unmounted `OepStudioHeader`'s `_ViewSwapControl`.
///
/// This region therefore shows:
/// - **Diagram Studio:** the real Diagram/Simulation mode switch, re-
///   expressed in Context Navigation's own visual language and driving
///   the exact same [oepStudioViewProvider] + `legacyV2ToggleSimulationViewProvider`
///   mechanism `_ViewSwapControl` always has — via the shared
///   [switchOepStudioView] function extracted from that control this
///   section (no second source of truth, no duplicated behavior).
/// - **Exchange and Settings:** intentionally left minimal here, NOT
///   duplicated — both Studios already have a real, working section/
///   category list inside their own content area (`ExchangeStudioPage`'s
///   `_SectionRail`, `SettingsWorkspacePage`'s own `_NavItem` list).
///   Lifting either into this shell-level region would mean showing the
///   same navigation twice on screen at once (once here, once in the
///   Studio's own content), which is a duplicated navigation model even
///   though the underlying state (Settings' case) is already shared —
///   `AP-UX-006`/this task's own "avoid duplicated navigation models" rule
///   is read here as covering presentation, not just state. Recorded as a
///   deliberate decision, not an oversight.
/// - **Home, EAM, Knowledge Studio, Instruments:** minimal — no real
///   contextual navigation exists in the repository for any of these
///   today (verified by direct inspection, not assumed).
class GlobalContextNavigation extends ConsumerWidget {
  const GlobalContextNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStudio = ref.watch(activeStudioProvider);
    return Container(
      width: OepGeometry.contextNavWidth,
      decoration: const BoxDecoration(
        color: OepColors.surface1,
        border: Border(right: BorderSide(color: OepColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'CONTEXT',
              style: TextStyle(
                color: OepColors.textMuted,
                fontFamily: OepTypography.fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          const Divider(height: 1, color: OepColors.border),
          Expanded(
            child: activeStudio == ActiveStudio.diagram
                ? const _DiagramViewSwitch()
                : _MinimalContext(studioLabel: activeStudio.meta.label),
          ),
        ],
      ),
    );
  }
}

/// The Diagram/Simulation mode switch, re-hosted here per AP-UX-007's
/// decision. Reuses [oepStudioViewProvider] (read) and [switchOepStudioView]
/// (write) — the exact same state/behavior `_ViewSwapControl` uses, not a
/// parallel one.
class _DiagramViewSwitch extends ConsumerWidget {
  const _DiagramViewSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(oepStudioViewProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ViewRow(
            label: 'Diagram',
            icon: Icons.polyline_outlined,
            active: active == OepStudioView.diagram,
            onTap: () => switchOepStudioView(ref, OepStudioView.diagram),
          ),
          _ViewRow(
            label: 'Simulation',
            icon: Icons.bolt_outlined,
            active: active == OepStudioView.simulation,
            onTap: () => switchOepStudioView(ref, OepStudioView.simulation),
          ),
        ],
      ),
    );
  }
}

class _ViewRow extends StatelessWidget {
  const _ViewRow(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? OepColors.surface3 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
                left: BorderSide(
                    color: active ? OepColors.accent : Colors.transparent,
                    width: 2)),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? OepColors.accent : OepColors.textSecondary),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color:
                      active ? OepColors.textPrimary : OepColors.textSecondary,
                  fontFamily: OepTypography.fontFamily,
                  fontSize: OepTypography.body,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown for every Studio without real, shell-reachable contextual
/// navigation today (Home, EAM, Knowledge Studio, Engineering Exchange,
/// Instruments, Settings) — an honest, compact statement, not a fabricated
/// navigation tree.
class _MinimalContext extends StatelessWidget {
  const _MinimalContext({required this.studioLabel});

  final String studioLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'No contextual navigation is defined for $studioLabel yet.',
        style: TextStyle(
          color: OepColors.textMuted,
          fontFamily: OepTypography.fontFamily,
          fontSize: OepTypography.body,
        ),
      ),
    );
  }
}
