import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/studio_destination.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/widgets/oep_list_view.dart';
import '../models/library_entry.dart';
import '../services/exchange_runtime_service.dart';

/// My Library (WP-EXC-010 §5) -- every package this Studio has installed,
/// persisted locally (`ExchangeLibraryStorage`), mirroring
/// `apps/publisher-portal`'s `MyLibraryPage` ("Locally tracked
/// installation history" / "Refresh status re-fetches the real
/// Installation by id rather than trusting the cached status forever").
/// Also exposes Repository Integration's "Refresh Repository"
/// (WP-EXC-010 §6) directly, since My Library is where the engineer
/// reviews everything they've installed into the Repository.
class ExchangeMyLibraryPanel extends ConsumerWidget {
  const ExchangeMyLibraryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exchangeRuntimeServiceProvider);
    final notifier = ref.read(exchangeRuntimeServiceProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Expanded(
                child: Text('My Library', style: TextStyle(color: StudioColors.textPrimary, fontWeight: FontWeight.w700)),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(foundationRuntimeServiceProvider.notifier).refreshRepository();
                  context.go(StudioDestination.repository.path);
                },
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Refresh Repository'),
              ),
            ],
          ),
        ),
        Expanded(
          child: OEPListView(
            items: state.library,
            emptyMessage: 'No installed packages yet.',
            itemBuilder: (context, entry) =>
                _LibraryRow(entry: entry, onRefresh: () => notifier.refreshInstallationStatus(entry.installationId)),
          ),
        ),
      ],
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.entry, required this.onRefresh});

  final LibraryEntry entry;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(entry.displayName, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
      subtitle: Text(
        'v${entry.version} -- ${entry.status}',
        style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
      ),
      trailing: TextButton(onPressed: onRefresh, child: const Text('Refresh Status')),
    );
  }
}
