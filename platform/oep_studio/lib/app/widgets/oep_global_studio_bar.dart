import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/oep_tokens.dart';
import '../active_studio.dart';

/// The OEP Global Studio Bar (target shell region 02,
/// `docs/architecture/ux/design-system/OEP-SHELL-COMPONENTS.md` §3;
/// canonical reference `docs/architecture/ux/renders/oep-shell/global-studio-bar.svg`).
///
/// WP-UI-DS-001 Section 03 (corrected, FROZEN) — application-level
/// NAVIGATION BETWEEN STUDIOS only. It is not a workspace/document tab bar
/// (that is the Workspace Bar, Section 04), not Context Navigation, not a
/// Toolbar, and not a browser tab strip.
///
/// **Frozen invariant:** selecting a Studio here ONLY assigns
/// [activeStudioProvider] (`app/active_studio.dart`). It never calls
/// `openSurface`, `openDiagramTab`, or any other tab-creating API — a
/// Studio is an application destination; a workspace is a unit of work
/// inside a Studio (`AP-UX-006` §10, §16). Do not reopen this decision.
///
/// **Studio inventory (ratified, closed set):** Home, Diagram Studio, EAM,
/// Knowledge Studio, Engineering Exchange, Instruments, Settings —
/// [ActiveStudio.values], in the ratified order. Engineering Intelligence is
/// deliberately absent — it is an internal OEP Engine/platform capability,
/// not a Studio Bar destination.
///
/// **Visual note (P2, disclosed):** the canonical render's active tab adds
/// a light glow border around its angled shape; this implementation uses a
/// solid identity-color fill plus bold white text for the active state
/// without the additional glow stroke, since Flutter's `ClipPath` does not
/// paint a border around an arbitrary clipped shape without a second
/// custom-paint pass. The substantive rule this region must satisfy —
/// "active Studio is obvious, using that Studio's identity color" — is met;
/// the glow itself is a minor polish difference from the reference, not a
/// structural one.
class OepGlobalStudioBar extends ConsumerWidget {
  const OepGlobalStudioBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStudio = ref.watch(activeStudioProvider);

    return Container(
      height: OepGeometry.studioBarHeight,
      color: OepColors.bg,
      child: Row(
        children: [
          for (final studio in ActiveStudio.values)
            _StudioTab(
              studio: studio,
              active: studio == activeStudio,
              // Frozen (Section 03) — selecting a Studio ONLY assigns
              // activeStudioProvider. No workspace tab is opened, reused,
              // or created by this action.
              onTap: () => ref.read(activeStudioProvider.notifier).state = studio,
            ),
        ],
      ),
    );
  }
}

/// Angled parallelogram tab, per the canonical "DUAL-TONE ANGLED" Studio
/// Bar reference. Width is intrinsic to its label (no fixed pixel table),
/// unlike the reference render's per-label-measured widths — this is the
/// correct approach for real content rather than pre-measured mockup text.
class _StudioTab extends StatelessWidget {
  const _StudioTab({required this.studio, required this.active, required this.onTap});

  final ActiveStudio studio;
  final bool active;
  final VoidCallback onTap;

  static const double _skew = 18;

  @override
  Widget build(BuildContext context) {
    final meta = studio.meta;
    final foreground = active ? Colors.white : OepColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: ClipPath(
        clipper: _ParallelogramClipper(skew: _skew),
        child: Material(
          color: active ? meta.color : OepColors.surface1,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(left: _skew + 16, right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(meta.icon, size: 16, color: foreground),
                  const SizedBox(width: 8),
                  Text(
                    meta.label,
                    style: TextStyle(
                      color: foreground,
                      fontFamily: OepTypography.fontFamily,
                      fontSize: OepTypography.workspaceLabel,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ParallelogramClipper extends CustomClipper<Path> {
  const _ParallelogramClipper({required this.skew});

  final double skew;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width - skew, size.height)
      ..lineTo(size.width, 0)
      ..lineTo(skew, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
