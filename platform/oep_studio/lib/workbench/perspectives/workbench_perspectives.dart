import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';
import '../perspective/perspective.dart';
import 'engineering_perspective.dart';
import 'instruments_perspective.dart';

/// WP-DS-006 Phase 1 — the fixed, registration-order list of Perspectives
/// this Workbench ships with. [Perspective]s are pluggable at the
/// [PerspectiveManager] level (`register`/`registerAll` accept any list);
/// this file is simply where Phase 1's default set lives, exactly the way
/// `StudioRegistry.defaultRegistry` is a plain static list a future Studio
/// could still add to without changing `StudioRegistry` itself.
///
/// Governing spec's Phase 1 deliverable is explicitly "the shell only" —
/// every non-Diagram entry below is a real, registered, switchable
/// [Perspective] (id/title/icon/centerBuilder all real), but its center
/// content is an honest placeholder rather than fabricated functionality;
/// see each perspective's own file for what, if anything, it hosts today.
final List<Perspective> workbenchPerspectives = [
  // AP-DIAGRAM-V2-BRIDGE-010 — `diagramPerspective` (which hosted the
  // native Diagram Studio renderer, `DiagramStudioPage`) was removed
  // once the parity/dependency audit confirmed the native renderer was
  // safe to retire. Legacy V2, bridged via the Web Surface host at
  // `/diagram`, is now the sole Diagram Studio surface.
  _placeholder(id: 'home', title: 'Home', icon: Icons.home_outlined),
  _placeholder(id: 'dashboard', title: 'Dashboard', icon: Icons.space_dashboard_outlined),
  _placeholder(id: 'inspection', title: 'Inspection', icon: Icons.search_outlined),
  engineeringPerspective,
  _placeholder(id: 'simulation', title: 'Simulation', icon: Icons.play_circle_outline),
  instrumentsPerspective,
  _placeholder(id: 'publishing', title: 'Publishing', icon: Icons.print_outlined),
  _placeholder(id: 'library', title: 'Library', icon: Icons.folder_special_outlined),
  _placeholder(id: 'review', title: 'Review', icon: Icons.rate_review_outlined),
];

Perspective _placeholder({required String id, required String title, required IconData icon}) {
  return Perspective(
    id: id,
    title: title,
    icon: icon,
    centerBuilder: (context) => _PlaceholderCenter(title: title, icon: icon),
  );
}

/// An honest "not built yet" placeholder — Phase 1 is shell-only per the
/// governing spec; this Perspective's real content is future work.
class _PlaceholderCenter extends StatelessWidget {
  const _PlaceholderCenter({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: StudioColors.background,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: StudioColors.textDisabled),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, color: StudioColors.textSecondary)),
          const SizedBox(height: 4),
          const Text(
            'This Perspective\'s workspace is not yet built.',
            style: TextStyle(fontSize: 12, color: StudioColors.textDisabled),
          ),
        ],
      ),
    );
  }
}
