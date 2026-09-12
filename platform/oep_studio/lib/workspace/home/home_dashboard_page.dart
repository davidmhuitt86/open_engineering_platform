import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/engineering_project_service.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/services/foundation_runtime_state.dart';
import '../../core/surfaces/surface_registry.dart';
import '../../core/theme/studio_colors.dart';
import '../../core/workspace/workspace_manager.dart';
import '../../diagram_studio/analysis/analysis_controller.dart';
import '../../diagram_studio/instruments_host/instrument_bridge_provider.dart';
import '../../exchange/models/exchange_connection_status.dart';
import '../../exchange/services/exchange_runtime_service.dart';
import '../engineering_workspace_page.dart' show openDiagramTab;
import '../workspace_tabs_controller.dart';

/// PRODUCT-READINESS-013 — the application-shell landing surface: the
/// first thing a user sees once a Workspace has no Studio tab open yet
/// (§ [WorkspaceTabsController]'s own boot-to-Home logic). Presentation
/// only — every action here calls the exact same real entry point a
/// menu/toolbar action already uses (`openDiagramTab`,
/// `WorkspaceTabsController.openSurface`,
/// `EngineeringProjectServiceNotifier.openDocument`); nothing here is a
/// second document/tab/registry authority.
///
/// Every status row reads a REAL, already-existing provider/getter.
/// Where no real signal exists for a subsystem, this says so plainly
/// (`Not Available`) rather than fabricating a health check — see
/// `PRODUCT-READINESS-013-IMPLEMENTATION-REPORT.md` §"System status" for
/// the full per-subsystem accounting of what is/isn't real.
class HomeDashboardPage extends ConsumerWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsController = ref.watch(workspaceTabsControllerProvider);
    final recent = WorkspaceManager.instance.recentWorkspaces;

    return Container(
      color: StudioColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HomeHeader(),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ContinueWorkCard(recent: recent, ref: ref),
                        const SizedBox(height: 20),
                        _RecentWorkCard(recent: recent, ref: ref),
                        const SizedBox(height: 20),
                        _AvailableStudiosCard(tabsController: tabsController),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Expanded(flex: 2, child: _SystemStatusCard()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgOrFallbackLogo(),
            const SizedBox(width: 12),
            const Text(
              'Home',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'OPEN ENGINEERING PLATFORM',
          style: TextStyle(color: StudioColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
      ],
    );
  }
}

/// A tiny, dependency-free stand-in mark (the real OEP SVG asset lives
/// under `assets/branding/`; this avoids adding an `flutter_svg` import
/// to a page that otherwise needs none) — a plain accent-colored square
/// with the OEP monogram, matching the header's own accent color.
class SvgOrFallbackLogo extends StatelessWidget {
  const SvgOrFallbackLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: StudioColors.selection, borderRadius: BorderRadius.circular(6)),
      child: const Text('O', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudioColors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StudioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ContinueWorkCard extends StatelessWidget {
  const _ContinueWorkCard({required this.recent, required this.ref});

  final List<String> recent;
  final WidgetRef ref;

  Future<void> _openPath(BuildContext context, String path) async {
    await ref.read(engineeringProjectServiceProvider.notifier).openDocument(path);
    if (!context.mounted) return;
    openDiagramTab(ref.read(workspaceTabsControllerProvider));
  }

  Future<void> _openExisting(BuildContext context) async {
    final picked = await openFile();
    if (picked == null) return;
    if (!context.mounted) return;
    await _openPath(context, picked.path);
  }

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) {
      return _Card(
        title: 'Continue Work',
        child: Row(
          children: [
            const Expanded(
              child: Text('No recent work', style: TextStyle(color: StudioColors.textDisabled, fontSize: 13)),
            ),
            OutlinedButton(
              onPressed: () => _openExisting(context),
              child: const Text('Open Existing Work'),
            ),
          ],
        ),
      );
    }
    final path = recent.first;
    final name = path.split(RegExp(r'[\\/]')).last;
    return _Card(
      title: 'Continue Work',
      child: InkWell(
        onTap: () => _openPath(context, path),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.play_circle_outline, color: StudioColors.selection, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(path, style: const TextStyle(color: StudioColors.textDisabled, fontSize: 11), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentWorkCard extends StatelessWidget {
  const _RecentWorkCard({required this.recent, required this.ref});

  final List<String> recent;
  final WidgetRef ref;

  Future<void> _openPath(BuildContext context, String path) async {
    await ref.read(engineeringProjectServiceProvider.notifier).openDocument(path);
    if (!context.mounted) return;
    openDiagramTab(ref.read(workspaceTabsControllerProvider));
  }

  @override
  Widget build(BuildContext context) {
    // The Continue Work card above already surfaces the most-recent
    // entry — this lists whatever real entries remain, never fabricated.
    final rest = recent.length > 1 ? recent.sublist(1) : const <String>[];
    return _Card(
      title: 'Recent Work',
      child: rest.isEmpty
          ? const Text('Nothing else recent', style: TextStyle(color: StudioColors.textDisabled, fontSize: 13))
          : Column(
              children: [
                for (final path in rest)
                  InkWell(
                    onTap: () => _openPath(context, path),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.description_outlined, color: StudioColors.textSecondary, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              path.split(RegExp(r'[\\/]')).last,
                              style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _AvailableStudiosCard extends StatelessWidget {
  const _AvailableStudiosCard({required this.tabsController});

  final WorkspaceTabsController tabsController;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Available Studios',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _StudioTile(
            icon: Icons.polyline,
            label: 'Diagram Studio',
            onTap: () => openDiagramTab(tabsController),
          ),
          // Every other entry is derived directly from the same
          // SurfaceRegistry the Workspace's own "+" menu already uses —
          // never a hand-maintained second list, never a fake target for
          // something not actually registered. Home itself is excluded:
          // this card only ever renders while Home is the open tab being
          // viewed, so a tile linking back to it would always be a
          // no-op link to the page already on screen.
          for (final surface in SurfaceRegistry.all)
            if (surface.id != SurfaceRegistry.homeSurfaceId)
              _StudioTile(
                icon: surface.icon,
                label: surface.title,
                onTap: () => tabsController.openSurface(surface.id),
              ),
        ],
      ),
    );
  }
}

class _StudioTile extends StatelessWidget {
  const _StudioTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 132,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: StudioColors.surfaceSunken,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: StudioColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: StudioColors.selection, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: StudioColors.textPrimary, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemStatusCard extends ConsumerWidget {
  const _SystemStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final exchange = ref.watch(exchangeRuntimeServiceProvider);
    final knowledge = ref.watch(electricalCoreRuntimeProvider);
    final instrumentBridge = ref.watch(instrumentBridgeServiceProvider);
    final tabsController = ref.watch(workspaceTabsControllerProvider);

    return _Card(
      title: 'System Status',
      child: Column(
        children: [
          _StatusRow(
            label: 'Engineering Engine',
            value: switch (foundation.phase) {
              FoundationConnectionPhase.connected => 'Ready',
              FoundationConnectionPhase.connecting => 'Connecting…',
              FoundationConnectionPhase.error => 'Error',
            },
            ok: foundation.isConnected,
          ),
          _StatusRow(
            label: 'Repository',
            value: foundation.isRepositoryOpen ? 'Open' : 'Closed',
            ok: foundation.isRepositoryOpen,
          ),
          _StatusRow(
            label: 'Knowledge Package',
            value: knowledge.when(
              data: (_) => 'Ready',
              loading: () => 'Loading…',
              error: (_, __) => 'Error',
            ),
            ok: knowledge.hasValue,
          ),
          _StatusRow(
            label: 'Engineering Exchange',
            value: switch (exchange.connectionStatus) {
              ExchangeConnectionStatus.connected => 'Connected',
              ExchangeConnectionStatus.notTested => 'Not Tested',
              ExchangeConnectionStatus.networkError => 'Offline',
              ExchangeConnectionStatus.serviceError => 'Unavailable',
            },
            ok: exchange.isConnected,
          ),
          _StatusRow(
            label: 'Instrument Bridge',
            value: instrumentBridge.isRunning ? 'Running (port ${instrumentBridge.port})' : 'Stopped',
            ok: instrumentBridge.isRunning,
          ),
          _StatusRow(
            label: 'Workspace',
            value: '${tabsController.tabs.length} tab${tabsController.tabs.length == 1 ? '' : 's'} open'
                '${WorkspaceManager.instance.hasUnsavedChanges ? ' · unsaved changes' : ''}',
            ok: true,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value, required this.ok});

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.circle_outlined, size: 13, color: ok ? StudioColors.success : StudioColors.textDisabled),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12.5)),
          ),
          Text(value, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
