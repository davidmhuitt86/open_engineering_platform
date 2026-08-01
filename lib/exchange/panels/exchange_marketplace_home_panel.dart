import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import '../../knowledge/widgets/knowledge_panel.dart';
import '../models/exchange_package.dart';
import '../models/publisher.dart';
import '../services/exchange_runtime_service.dart';

/// Marketplace Home (WP-EXC-010 §5) -- a sample of packages and
/// publishers, mirroring `apps/publisher-portal`'s `MarketplaceHomePage`
/// ("Recently updated packages + a category-cards sample"). Selecting a
/// package or publisher switches the workspace into Package Detail /
/// Publisher Profile via `ExchangeRuntimeNotifier.selectPackage`/
/// `.selectPublisher` -- the same in-workspace "drill down without
/// leaving Studio" pattern `AcquisitionJobsPanel`'s job selection uses
/// for the Pipeline panel.
class ExchangeMarketplaceHomePanel extends ConsumerWidget {
  const ExchangeMarketplaceHomePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exchangeRuntimeServiceProvider);
    final notifier = ref.read(exchangeRuntimeServiceProvider.notifier);

    return Row(
      children: [
        Expanded(
          child: KnowledgePanel(
            title: 'Recently Updated Packages',
            icon: Icons.inventory_2_outlined,
            child: state.packages.isEmpty
                ? const Center(child: Text('No packages yet.', style: TextStyle(color: StudioColors.textSecondary)))
                : ListView.separated(
                    itemCount: state.packages.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _PackageRow(
                      package: state.packages[index],
                      onTap: () => notifier.selectPackage(state.packages[index].id),
                    ),
                  ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: KnowledgePanel(
            title: 'Publishers',
            icon: Icons.storefront_outlined,
            child: state.publishers.isEmpty
                ? const Center(child: Text('No publishers yet.', style: TextStyle(color: StudioColors.textSecondary)))
                : ListView.separated(
                    itemCount: state.publishers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _PublisherRow(
                      publisher: state.publishers[index],
                      onTap: () => notifier.selectPublisher(state.publishers[index].id),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({required this.package, required this.onTap});

  final ExchangePackage package;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      title: Text(package.displayName, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
      subtitle: Text(
        package.description.isEmpty ? package.packageId : package.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
      ),
      trailing: Text(package.currentVersion ?? '--', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
    );
  }
}

class _PublisherRow extends StatelessWidget {
  const _PublisherRow({required this.publisher, required this.onTap});

  final Publisher publisher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      title: Text(publisher.displayName, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
      subtitle: Text(publisher.namespace, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
    );
  }
}
