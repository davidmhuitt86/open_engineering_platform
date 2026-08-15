import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/foundation/foundation_bridge_exception.dart';
import '../../core/foundation/oep_api_types.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import 'builder/package_builder_page.dart';
import 'package_validation_dialog.dart';

/// Package Integration UI (AP-DS-002, "Package Integration"): Install
/// Package, Package Metadata, Publisher Metadata, and Package
/// Validation over the currently open repository's already-installed
/// packages. No networking, no Exchange integration — installation here
/// takes only a local `.oep` archive path, matching
/// `FoundationBridge.installPackage`'s own signature. "Create Package"
/// and "Save Package" (package *authoring*, as opposed to installing an
/// already-built archive) have no bound Foundation Bridge entry point
/// as of this work package — see the task report's package-integration
/// findings.
///
/// Reads and writes only through `FoundationRuntimeNotifier.bridge`
/// (the established access pattern used by every Engineering
/// Intelligence page — see `query_console_page.dart`), never SQL,
/// repository internals, or trust/dependency-resolution internals
/// directly, per the spec's constraints.
class PackageManagerPage extends ConsumerStatefulWidget {
  const PackageManagerPage({super.key});

  @override
  ConsumerState<PackageManagerPage> createState() => _PackageManagerPageState();
}

class _PackageManagerPageState extends ConsumerState<PackageManagerPage> {
  List<InstalledPackageInfo>? _packages;
  String? _error;
  bool _busy = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    final foundation = ref.read(foundationRuntimeServiceProvider);
    if (bridge == null || !foundation.isRepositoryOpen) {
      setState(() {
        _packages = null;
        _error = null;
      });
      return;
    }
    try {
      final query = _searchController.text.trim();
      final packages = query.isEmpty ? bridge.listInstalledPackages() : bridge.searchInstalledPackages(query);
      setState(() {
        _packages = packages;
        _error = null;
      });
    } on FoundationBridgeException catch (e) {
      setState(() {
        _packages = null;
        _error = e.message;
      });
    }
  }

  Future<void> _installFromPath(String archivePath) async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null || archivePath.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      bridge.installPackage(archivePath.trim());
      _refresh();
    } on FoundationBridgeException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promptInstall() async {
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: const Text('Install Package', style: TextStyle(color: StudioColors.textPrimary)),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13),
            decoration: const InputDecoration(labelText: 'Path to .oep archive'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Install')),
        ],
      ),
    );
    if (path == null || path.trim().isEmpty) return;
    await _installFromPath(path);
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);

    if (!foundation.isRepositoryOpen) {
      return const Center(
        child: Text(
          'Open a repository to manage packages.',
          style: TextStyle(color: StudioColors.textSecondary, fontSize: 13),
        ),
      );
    }

    final packages = _packages ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 18, color: StudioColors.selection),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Packages',
                  style: TextStyle(color: StudioColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(PackageBuilderPage.route()),
                icon: const Icon(Icons.construction_outlined, size: 16),
                label: const Text('Build Package'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _promptInstall,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Install Package'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 34,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _refresh(),
              style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 16),
                hintText: 'Search installed packages…',
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(_error!, style: const TextStyle(color: StudioColors.error, fontSize: 12)),
          ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        Expanded(
          child: packages.isEmpty
              ? const Center(
                  child: Text('No packages installed.', style: TextStyle(color: StudioColors.textDisabled, fontSize: 12.5)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: packages.length,
                  itemBuilder: (context, index) => _PackageTile(package: packages[index]),
                ),
        ),
      ],
    );
  }
}

class _PackageTile extends ConsumerWidget {
  const _PackageTile({required this.package});

  final InstalledPackageInfo package;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMetadata(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 16, color: StudioColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(package.title, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 13)),
                    Text(
                      '${package.packageId} · v${package.version} · ${package.objectCount} objects',
                      style: const TextStyle(color: StudioColors.textDisabled, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                iconSize: 16,
                tooltip: 'Validate Package',
                icon: const Icon(Icons.fact_check_outlined, color: StudioColors.textSecondary),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PackageValidationDialog(packageId: package.packageId, packageTitle: package.title),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMetadata(BuildContext context, WidgetRef ref) async {
    final bridge = ref.read(foundationRuntimeServiceProvider.notifier).bridge;
    if (bridge == null) return;
    PackageDetails? details;
    PublisherCertificate? publisher;
    String? error;
    try {
      details = bridge.getPackageInfo(package.packageId);
      try {
        publisher = bridge.trustGetCertificate(details.publisherId);
      } on FoundationBridgeException {
        publisher = null; // Not every publisher has a trusted certificate on file.
      }
    } on FoundationBridgeException catch (e) {
      error = e.message;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: StudioColors.surfaceRaised,
        title: Text(package.title, style: const TextStyle(color: StudioColors.textPrimary)),
        content: SizedBox(
          width: 440,
          child: error != null
              ? Text(error, style: const TextStyle(color: StudioColors.error, fontSize: 12.5))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _metaRow('Package ID', details!.packageId),
                    _metaRow('Version', details.version),
                    _metaRow('Summary', details.summary),
                    _metaRow('Category', details.category),
                    _metaRow('Domains', details.engineeringDomains.join(', ')),
                    _metaRow('Objects / Relationships', '${details.objectCount} / ${details.relationshipCount}'),
                    _metaRow('Installed', details.installedUtc),
                    _metaRow('Source', details.source),
                    _metaRow('State', details.runtimeState),
                    const SizedBox(height: 8),
                    const Text('Publisher', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    _metaRow('Name', details.publisherName),
                    _metaRow('Publisher ID', details.publisherId),
                    _metaRow(
                      'Trust',
                      publisher == null ? 'No certificate on file' : (publisher.revoked ? 'Revoked' : 'Trusted'),
                    ),
                  ],
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: StudioColors.textDisabled, fontSize: 11.5)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
