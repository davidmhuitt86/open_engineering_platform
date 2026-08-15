import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/notifications/platform_notification_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../shared/widgets/property_field.dart';
import '../models/acquisition_job.dart';
import '../models/official_source.dart';
import '../models/vault_entry_record.dart';
import '../wizard/chain_of_custody_record.dart';
import '../wizard/chain_of_custody_storage.dart';

/// Property Inspector — Official Source mode.
class OfficialSourceProperties extends StatelessWidget {
  const OfficialSourceProperties({super.key, required this.source});

  final OfficialSource source;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('Official Source'),
        PropertyField(label: 'Name', value: source.name),
        PropertyField(label: 'Base URL', value: source.baseUrl.isEmpty ? '—' : source.baseUrl),
        PropertyField(label: 'Trust Level', value: '${source.trustLevel} of 5'),
        PropertyField(label: 'Status', value: source.status),
        PropertyField(label: 'Authentication', value: source.authenticationType),
        if (source.category.isNotEmpty) PropertyField(label: 'Category', value: source.category),
        if (source.country.isNotEmpty) PropertyField(label: 'Country', value: source.country),
        PropertyField(label: 'Identifier', value: source.id, monospace: true),
        PropertyField(label: 'Registered', value: source.createdAt),
      ],
    );
  }
}

/// Property Inspector — Acquisition Job mode.
class AcquisitionJobProperties extends StatelessWidget {
  const AcquisitionJobProperties({super.key, required this.job, this.sourceName});

  final AcquisitionJob job;
  final String? sourceName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('Acquisition Job'),
        PropertyField(label: 'Name', value: job.name),
        PropertyField(label: 'Status', value: job.status),
        PropertyField(label: 'Priority', value: _priorityLabel(job.priority)),
        PropertyField(label: 'Official Source', value: sourceName ?? job.sourceId),
        if (job.requestedBy.isNotEmpty) PropertyField(label: 'Requested By', value: job.requestedBy),
        PropertyField(label: 'Started', value: job.startedAt ?? 'Not started'),
        PropertyField(label: 'Completed', value: job.completedAt ?? 'Not completed'),
        if (job.errorMessage != null && job.errorMessage!.isNotEmpty)
          PropertyField(label: 'Error', value: job.errorMessage!),
        PropertyField(label: 'Identifier', value: job.id, monospace: true),
      ],
    );
  }

  String _priorityLabel(int priority) => switch (priority) {
        0 => 'Low (0)',
        1 => 'Normal (1)',
        2 => 'High (2)',
        3 => 'Urgent (3)',
        _ => '$priority',
      };
}

/// Property Inspector — Reference Vault Artifact mode, with the real
/// artifact interactions this Work Package asks for (Open, Reveal in
/// Explorer, Copy SHA-256, Copy File Path, Open Original Source URL,
/// View Metadata, View Chain of Custody).
class VaultArtifactProperties extends StatefulWidget {
  const VaultArtifactProperties({super.key, required this.artifact, this.sourceName, this.vaultRoot});

  final VaultEntryRecord artifact;
  final String? sourceName;

  /// Absolute directory the EAM backend's `[storage] root_path` resolves
  /// against, when known. `VaultEntryRecord.vaultPath` is stored relative
  /// to the backend's own working directory (`./data/vault/...`), which
  /// Studio can't resolve on its own -- so file actions are honestly
  /// disabled rather than silently opening the wrong path when this is
  /// null. See `_resolvedPath`.
  final String? vaultRoot;

  @override
  State<VaultArtifactProperties> createState() => _VaultArtifactPropertiesState();
}

class _VaultArtifactPropertiesState extends State<VaultArtifactProperties> {
  ChainOfCustodyRecord? _custody;
  bool _custodyLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCustody();
  }

  @override
  void didUpdateWidget(covariant VaultArtifactProperties oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artifact.id != widget.artifact.id) {
      _custodyLoaded = false;
      _loadCustody();
    }
  }

  Future<void> _loadCustody() async {
    final record = await ChainOfCustodyStorage.forVaultEntry(widget.artifact.id);
    if (mounted) {
      setState(() {
        _custody = record;
        _custodyLoaded = true;
      });
    }
  }

  /// The artifact's absolute path, or `null` when it can't be resolved
  /// (see [VaultArtifactProperties.vaultRoot]).
  String? get _resolvedPath {
    final raw = widget.artifact.vaultPath;
    if (raw.isEmpty) return null;
    if (File(raw).isAbsolute) return raw;
    final root = widget.vaultRoot;
    if (root == null) return null;
    final normalized = raw.replaceFirst(RegExp(r'^\.[\\/]'), '');
    return '$root${Platform.pathSeparator}$normalized';
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) PlatformNotificationService.success(context, '$label copied.');
  }

  Future<void> _open(String path) async {
    try {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } catch (error) {
      if (mounted) PlatformNotificationService.error(context, 'Couldn\'t open the artifact: $error');
    }
  }

  Future<void> _reveal(String path) async {
    try {
      await Process.run('explorer', ['/select,', path]);
    } catch (error) {
      if (mounted) PlatformNotificationService.error(context, 'Couldn\'t reveal the artifact: $error');
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      await Process.run('cmd', ['/c', 'start', '', url]);
    } catch (error) {
      if (mounted) PlatformNotificationService.error(context, 'Couldn\'t open the source URL: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final artifact = widget.artifact;
    final path = _resolvedPath;
    final originalUrl = _custody?.originalUrl;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionTitle('Reference Vault Artifact'),
        PropertyField(label: 'SHA-256', value: artifact.sha256Hash, monospace: true),
        PropertyField(label: 'Type', value: artifact.mimeType.isEmpty ? '—' : artifact.mimeType),
        PropertyField(label: 'Size', value: '${artifact.fileSizeBytes} bytes'),
        PropertyField(label: 'Status', value: artifact.status),
        PropertyField(label: 'Published', value: artifact.publishedAt),
        PropertyField(label: 'Official Source', value: widget.sourceName ?? artifact.sourceId),
        PropertyField(label: 'Vault Path', value: artifact.vaultPath, monospace: true),

        const SizedBox(height: 4),
        const _SectionTitle('Actions'),
        if (path == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'File actions need the Engineering Acquisition service\'s storage location, which Studio '
              'can\'t resolve from a relative vault path. Set it in Settings > Engineering Acquisition to '
              'enable Open and Reveal in Explorer.',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 11, height: 1.4),
            ),
          ),
        _ActionRow(Icons.open_in_new, 'Open', path == null ? null : () => _open(path)),
        _ActionRow(Icons.folder_open_outlined, 'Reveal in Explorer', path == null ? null : () => _reveal(path)),
        _ActionRow(Icons.tag, 'Copy SHA-256',
            artifact.sha256Hash.isEmpty ? null : () => _copy('SHA-256', artifact.sha256Hash)),
        _ActionRow(Icons.content_copy, 'Copy File Path',
            artifact.vaultPath.isEmpty ? null : () => _copy('File path', path ?? artifact.vaultPath)),
        _ActionRow(Icons.link, 'Open Original Source URL',
            (originalUrl == null || originalUrl.isEmpty) ? null : () => _openUrl(originalUrl)),

        const SizedBox(height: 12),
        const _SectionTitle('Chain of Custody'),
        if (!_custodyLoaded)
          const Text('Loading…', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12))
        else if (_custody == null)
          const Text(
            'No Chain of Custody recorded for this artifact. Artifacts acquired through the Engineering '
            'Acquisition Wizard have one; artifacts published directly through the API do not.',
            style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5, height: 1.4),
          )
        else ...[
          if (_custody!.knowledgeType.isNotEmpty)
            PropertyField(label: 'Knowledge Type', value: _custody!.knowledgeType),
          if (_custody!.originalUrl.isNotEmpty) PropertyField(label: 'Original URL', value: _custody!.originalUrl),
          if (_custody!.publisher.isNotEmpty) PropertyField(label: 'Publisher', value: _custody!.publisher),
          if (_custody!.publicationDate.isNotEmpty)
            PropertyField(label: 'Publication Date', value: _custody!.publicationDate),
          if (_custody!.revision.isNotEmpty) PropertyField(label: 'Revision', value: _custody!.revision),
          if (_custody!.license.isNotEmpty) PropertyField(label: 'License', value: _custody!.license),
          if (_custody!.language.isNotEmpty) PropertyField(label: 'Language', value: _custody!.language),
          if (_custody!.acquisitionMethod.isNotEmpty)
            PropertyField(label: 'Acquisition Method', value: _custody!.acquisitionMethod),
          if (_custody!.engineer.isNotEmpty) PropertyField(label: 'Engineer', value: _custody!.engineer),
          if (_custody!.scopeDescription.isNotEmpty)
            PropertyField(label: 'Scope', value: _custody!.scopeDescription),
          PropertyField(label: 'Recorded', value: _custody!.recordedAt),
        ],
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
            child: Row(
              children: [
                Icon(icon, size: 15, color: enabled ? StudioColors.textSecondary : StudioColors.textDisabled),
                const SizedBox(width: 10),
                Text(label,
                    style: TextStyle(
                        color: enabled ? StudioColors.textPrimary : StudioColors.textDisabled, fontSize: 12.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              color: StudioColors.textDisabled, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
    );
  }
}
