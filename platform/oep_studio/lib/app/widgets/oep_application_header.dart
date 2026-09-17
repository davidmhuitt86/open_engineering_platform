import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/auth/authentication_provider.dart';
import '../../core/operations/operation_manager.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/oep_tokens.dart';
import 'command_palette_dialog.dart';

/// The OEP application-global header (target shell region 01,
/// `docs/architecture/ux/design-system/OEP-SHELL-COMPONENTS.md` §2).
///
/// WP-UI-DS-001 Section 02 — hosted once by [StudioShell], above every
/// Studio, so it renders identically regardless of which Studio is active.
/// This replaces `OepStudioHeader`'s former role as "the header" for the
/// Diagram Workspace tab (`EngineeringWorkspacePage` no longer renders it —
/// see that file's own Section 02 change). `OepStudioHeader` itself is not
/// deleted: its Diagram/Simulation identity (title/subtitle/studio-mark/
/// accent) and its `_ViewSwapControl` are Diagram-Studio-specific state and
/// presentation that belong in Diagram Studio's own chrome, not here — the
/// view-swap control specifically is reserved for Context Navigation
/// (Section 06, OD-001) and is not implemented in this section.
///
/// Per `OEP-SHELL-COMPONENTS.md` §2 ("no Studio-specific navigation
/// embedded here; no browser address-bar metaphor") this widget carries
/// only OEP identity — no Diagram/Simulation controls, no workspace tabs,
/// no Studio navigation (that is the Global Studio Bar, Section 03).
///
/// Right-side controls against the canonical `App Header with OEP Logo.png`
/// reference, each backed by a real, already-existing state source (Rule 3,
/// `OEP-UI-RULES.md` — no invented behavior):
/// - Search opens the existing, already-wired Command Palette
///   (`showCommandPaletteDialog`, the same one `StudioShell`'s Ctrl+K binds)
///   rather than a new, disconnected search field.
/// - The status pill reflects the real `foundationRuntimeServiceProvider`
///   connection phase — the identical source Home's own System Status card
///   already reads (`home_dashboard_page.dart`'s `_SystemStatusCard`).
/// - The notification bell's badge count and its dropdown list are the real
///   `OperationManager.instance.activeOperations` — the same tracker
///   `StudioShell` already feeds via its download/OCR bridges.
///
/// The user element reads the real, already-working local sign-in system
/// (OEP First Startup UI, Phase 0A — `AuthenticationService`/`OnboardingFlow`,
/// `Splash -> Login -> Welcome -> Workspace Selection` gates entry to the app
/// today): [authenticationServiceProvider].rememberedUsername() returns the
/// signed-in username persisted by that same flow. There is no profile
/// picture concept anywhere in that system, so the avatar is a generic
/// person glyph, not a fabricated photo.
///
/// One element from the reference is deliberately NOT implemented, for a
/// reason that is architectural, not merely unfinished work:
/// - **Window controls** (minimize/maximize/close): this application runs
///   in a standard, OS-decorated window (no frameless-window package —
///   e.g. `window_manager`/`bitsdojo_window` — is present in `pubspec.yaml`).
///   The native Windows title bar already provides these controls; adding a
///   second, unwired set inside this header would be redundant chrome, not
///   a fix for a missing capability.
class OepApplicationHeader extends ConsumerWidget {
  const OepApplicationHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final engineOnline = foundation.isConnected;

    return Container(
      height: OepGeometry.headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: OepColors.surface1,
        border: Border(bottom: BorderSide(color: OepColors.border)),
      ),
      child: Row(
        children: [
          SvgPicture.asset('assets/branding/oep_logo.svg', height: 34),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OPEN ENGINEERING PLATFORM',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: OepColors.textPrimary,
                  fontFamily: OepTypography.fontFamily,
                  fontSize: OepTypography.applicationTitle,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'OPEN TODAY  ·  ENGINEER TOMORROW',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: OepColors.accent,
                  fontFamily: OepTypography.fontFamily,
                  fontSize: OepTypography.metadata,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: _HeaderSearchField(onTap: () => showCommandPaletteDialog(context)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _EngineStatusPill(online: engineOnline),
          const SizedBox(width: 16),
          const _OperationsBell(),
          const SizedBox(width: 16),
          const _UserBadge(),
        ],
      ),
    );
  }
}

class _HeaderSearchField extends StatelessWidget {
  const _HeaderSearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(OepGeometry.radiusMd),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: OepColors.border),
            borderRadius: BorderRadius.circular(OepGeometry.radiusMd),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 16, color: OepColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search or run a command  (Ctrl+K)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: OepColors.textSecondary, fontSize: OepTypography.body),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EngineStatusPill extends StatelessWidget {
  const _EngineStatusPill({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? OepColors.success : OepColors.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(
          online ? 'System Online' : 'System Offline',
          style: TextStyle(color: OepColors.textSecondary, fontSize: OepTypography.body),
        ),
      ],
    );
  }
}

class _UserBadge extends ConsumerStatefulWidget {
  const _UserBadge();

  @override
  ConsumerState<_UserBadge> createState() => _UserBadgeState();
}

class _UserBadgeState extends ConsumerState<_UserBadge> {
  late Future<String?> _username;

  @override
  void initState() {
    super.initState();
    _username = ref.read(authenticationServiceProvider).rememberedUsername();
  }

  Future<void> _signOut() async {
    await ref.read(authenticationServiceProvider).signOut();
    if (!mounted) return;
    setState(() => _username = Future.value(null));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out. Restart the application to sign in again.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _username,
      builder: (context, snapshot) {
        final username = snapshot.data;
        return PopupMenuButton<VoidCallback>(
          tooltip: username ?? 'Not signed in',
          onSelected: (action) => action(),
          itemBuilder: (context) => [
            if (username != null)
              PopupMenuItem<VoidCallback>(enabled: false, child: Text('Signed in as $username')),
            PopupMenuItem<VoidCallback>(value: _signOut, child: const Text('Sign Out')),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 12,
                backgroundColor: OepColors.surface3,
                child: Icon(Icons.person, size: 14, color: OepColors.textSecondary),
              ),
              if (username != null) ...[
                const SizedBox(width: 8),
                Text(username, style: TextStyle(color: OepColors.textSecondary, fontSize: OepTypography.body)),
              ],
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down, size: 18, color: OepColors.textSecondary),
            ],
          ),
        );
      },
    );
  }
}

class _OperationsBell extends StatefulWidget {
  const _OperationsBell();

  @override
  State<_OperationsBell> createState() => _OperationsBellState();
}

class _OperationsBellState extends State<_OperationsBell> {
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = OperationManager.instance.changes.listen(_onChange);
  }

  void _onChange(void _) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = OperationManager.instance.activeOperations;
    return PopupMenuButton<void>(
      tooltip: active.isEmpty ? 'No active operations' : '${active.length} active operation(s)',
      itemBuilder: (context) => active.isEmpty
          ? [const PopupMenuItem<void>(enabled: false, child: Text('No active operations'))]
          : [
              for (final operation in active)
                PopupMenuItem<void>(enabled: false, child: Text(operation.label)),
            ],
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined, size: 20, color: OepColors.textSecondary),
          if (active.isNotEmpty)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: OepColors.accent, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '${active.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
