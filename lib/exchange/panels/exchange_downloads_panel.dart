import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import '../../shared/widgets/oep_list_view.dart';
import '../services/exchange_runtime_service.dart';

/// Downloads (WP-EXC-010 §5) -- every package artifact this Studio has
/// downloaded, persisted locally (`ExchangeLibraryStorage`), mirroring
/// `apps/publisher-portal`'s `DownloadsPage` local download history.
class ExchangeDownloadsPanel extends ConsumerWidget {
  const ExchangeDownloadsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exchangeRuntimeServiceProvider);

    return OEPListView(
      items: state.downloads,
      emptyMessage: 'No downloads yet.',
      itemBuilder: (context, entry) => ListTile(
        dense: true,
        title: Text(entry.displayName, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
        subtitle: Text(
          '${entry.version ?? 'latest'} -- ${entry.downloadedAt}',
          style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
        ),
      ),
    );
  }
}
