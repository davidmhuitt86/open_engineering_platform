import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import '../models/publisher.dart';
import '../services/exchange_runtime_service.dart';

/// Publisher Profile (WP-EXC-010 §5) -- mirrors `apps/publisher-portal`'s
/// `PublisherProfilePage`. Publisher Administration itself (editing a
/// publisher's own profile) is explicitly excluded (WP-EXC-010 §2:
/// "Publisher administration") -- this is a read-only profile view.
class ExchangePublisherProfilePanel extends ConsumerWidget {
  const ExchangePublisherProfilePanel({required this.publisher, super.key});

  final Publisher publisher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(exchangeRuntimeServiceProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back, size: 18), onPressed: notifier.clearSelectedPublisher),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  publisher.displayName,
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Chip(label: Text(publisher.status)),
            ],
          ),
          const SizedBox(height: 8),
          Text(publisher.description, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          _InfoRow(label: 'Namespace', value: publisher.namespace),
          _InfoRow(label: 'Type', value: publisher.publisherType),
          _InfoRow(label: 'Legal Name', value: publisher.legalName),
          _InfoRow(label: 'Website', value: publisher.website.isEmpty ? '--' : publisher.website),
          _InfoRow(label: 'Contact', value: publisher.contactEmail),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: StudioColors.textSecondary, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12))),
        ],
      ),
    );
  }
}
