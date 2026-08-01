import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import '../models/exchange_connection_status.dart';
import '../panels/exchange_downloads_panel.dart';
import '../panels/exchange_marketplace_home_panel.dart';
import '../panels/exchange_my_library_panel.dart';
import '../panels/exchange_package_detail_panel.dart';
import '../panels/exchange_publisher_profile_panel.dart';
import '../panels/exchange_search_panel.dart';
import '../services/exchange_runtime_service.dart';
import '../services/exchange_runtime_state.dart';

enum _ExchangeSection { marketplaceHome, search, myLibrary, downloads }

/// The Engineering Exchange workspace (WP-EXC-010) -- registered as a
/// Studio workspace exactly like Engineering Acquisition: same
/// Navigation Rail, theme, and window layout via `StudioShell`. Per this
/// Work Package's Objective, the engineer should not perceive the
/// Exchange as a separate application -- this page (plus the panels
/// under `lib/exchange/panels/`) is the only thing that changes; the
/// Exchange's own REST API (`oep_exchange`) never has, and does not
/// gain, any UI of its own outside of Studio.
///
/// Implements Marketplace Home / Search / My Library / Downloads as four
/// in-workspace sections switched by local widget state, and Package
/// Detail / Publisher Profile as a drill-down that replaces the section
/// content when `ExchangeServiceState.selectedPackage`/`.selectedPublisher`
/// is set -- a small internal "section stack," not nested `go_router`
/// routes, so the Studio-level route table (`StudioRegistry`) still has
/// exactly one entry for Exchange, unchanged by whichever of its seven
/// WP-EXC-010 §5 views is currently showing.
class ExchangeStudioPage extends ConsumerStatefulWidget {
  const ExchangeStudioPage({super.key});

  @override
  ConsumerState<ExchangeStudioPage> createState() => _ExchangeStudioPageState();
}

class _ExchangeStudioPageState extends ConsumerState<ExchangeStudioPage> {
  _ExchangeSection _section = _ExchangeSection.marketplaceHome;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(exchangeRuntimeServiceProvider.notifier).refreshMarketplace();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exchangeRuntimeServiceProvider);
    final notifier = ref.read(exchangeRuntimeServiceProvider.notifier);

    return Column(
      children: [
        _ConnectionBanner(state: state, onRefresh: notifier.refreshMarketplace),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionRail(
                section: _section,
                onSelect: (section) => setState(() {
                  _section = section;
                  notifier.clearSelectedPackage();
                  notifier.clearSelectedPublisher();
                }),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _buildContent(state)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ExchangeServiceState state) {
    if (state.selectedPackage != null) {
      return ExchangePackageDetailPanel(package: state.selectedPackage!);
    }
    if (state.selectedPublisher != null) {
      return ExchangePublisherProfilePanel(publisher: state.selectedPublisher!);
    }
    return switch (_section) {
      _ExchangeSection.marketplaceHome => const ExchangeMarketplaceHomePanel(),
      _ExchangeSection.search => const ExchangeSearchPanel(),
      _ExchangeSection.myLibrary => const ExchangeMyLibraryPanel(),
      _ExchangeSection.downloads => const ExchangeDownloadsPanel(),
    };
  }
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({required this.section, required this.onSelect});

  final _ExchangeSection section;
  final ValueChanged<_ExchangeSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _RailItem(
            label: 'Marketplace Home',
            icon: Icons.storefront_outlined,
            selected: section == _ExchangeSection.marketplaceHome,
            onTap: () => onSelect(_ExchangeSection.marketplaceHome),
          ),
          _RailItem(
            label: 'Search',
            icon: Icons.search_outlined,
            selected: section == _ExchangeSection.search,
            onTap: () => onSelect(_ExchangeSection.search),
          ),
          _RailItem(
            label: 'My Library',
            icon: Icons.video_library_outlined,
            selected: section == _ExchangeSection.myLibrary,
            onTap: () => onSelect(_ExchangeSection.myLibrary),
          ),
          _RailItem(
            label: 'Downloads',
            icon: Icons.download_outlined,
            selected: section == _ExchangeSection.downloads,
            onTap: () => onSelect(_ExchangeSection.downloads),
          ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: StudioColors.surfaceRaised,
      leading: Icon(icon, size: 18),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      onTap: onTap,
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.state, required this.onRefresh});

  final ExchangeServiceState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final isError = state.connectionStatus == ExchangeConnectionStatus.networkError ||
        state.connectionStatus == ExchangeConnectionStatus.serviceError ||
        state.lastError != null;

    if (!isError && !state.loading) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: isError ? StudioColors.error.withValues(alpha: 0.15) : StudioColors.surfaceRaised,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (state.loading)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          else
            const Icon(Icons.error_outline, size: 16, color: StudioColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.loading
                  ? 'Loading from Engineering Exchange…'
                  : (state.lastError ?? 'Could not reach the Engineering Exchange service.'),
              style: TextStyle(
                color: isError ? StudioColors.error : StudioColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          if (!state.loading) TextButton(onPressed: onRefresh, child: const Text('Retry')),
        ],
      ),
    );
  }
}
