import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/credential_service.dart';
import '../../core/services/foundation_runtime_service.dart';
import '../../core/theme/studio_colors.dart';
import '../../knowledge/models/ai_connection_status.dart';
import '../../knowledge/services/ai_provider_registry.dart';
import '../controllers/settings_controller.dart';
import '../models/settings_entry.dart';
import '../models/settings_enums.dart';
import '../models/settings_page_id.dart';
import '../services/settings_provider.dart';
import '../widgets/settings_rows.dart';

/// Settings > Artificial Intelligence (SDD-023; STUDIO-TASK-000052,
/// extended by Work Package 018 STUDIO-TASK-000057/000058).
///
/// `providerId`/`modelId` are now genuinely consumed by
/// `AnthropicProvider` — superseding Work Package 017's deliberate
/// decoupling from `AiProviderRegistry` (itself scoped "yet"). This
/// page reads `AiProviderRegistry.defaultRegistry.availableModels` only
/// for its provider picker's metadata (id/display name) — it never
/// calls a provider's `complete`/`testConnection` directly; those go
/// through the Connection Manager (`testAiConnection`), keeping "No
/// Workspace code may call Anthropic APIs directly" true even here.
class AiSettingsProvider implements SettingsProvider {
  const AiSettingsProvider();

  @override
  String get pageId => CoreSettingsPageIds.artificialIntelligence;

  @override
  String get label => 'Artificial Intelligence';

  @override
  IconData get icon => Icons.smart_toy_outlined;

  @override
  List<SettingsEntry> get searchEntries => const [
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Enable AI',
      description: 'Master switch for AI features.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Provider',
      description: 'Which AI Provider to use.',
    ),
    SettingsEntry(pageId: CoreSettingsPageIds.artificialIntelligence, name: 'Model', description: 'Which model to use.'),
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'API Key',
      description: 'Credential for the selected provider, stored securely by the operating system.',
      keywords: ['credential', 'secret', 'token', 'anthropic'],
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Temperature',
      description: 'AI response randomness.',
    ),
    SettingsEntry(pageId: CoreSettingsPageIds.artificialIntelligence, name: 'Timeout', description: 'AI request timeout.'),
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Max Tokens',
      description: 'Maximum tokens the AI may generate in one response.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Context Window',
      description: 'Maximum context tokens (informational).',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Reasoning Depth',
      description: 'How much the AI reasons before responding.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Privacy Controls',
      description: 'AI privacy safeguards.',
    ),
    SettingsEntry(
      pageId: CoreSettingsPageIds.artificialIntelligence,
      name: 'Test Connection',
      description: 'Verify connectivity and authentication with the selected provider.',
    ),
  ];

  @override
  WidgetBuilder get pageBuilder => (context) => const AiSettingsPage();
}

class AiSettingsPage extends ConsumerWidget {
  const AiSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final ai = ref.watch(settingsControllerProvider.select((state) => state.configuration.ai));
    final availableModels = AiProviderRegistry.defaultRegistry.availableModels;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SettingsSection(
          title: 'Artificial Intelligence',
          description:
              'Choose a provider and configure how Studio\'s AI Review Workspace analyzes evidence. API keys are '
              'stored using this operating system\'s secure credential storage — never in Settings, a Repository, '
              'or a Knowledge Session.',
          children: [
            SettingsSwitchRow(label: 'Enable AI', value: ai.enabled, onChanged: controller.setAiEnabled),
            SettingsDropdownRow<String>(
              label: 'Provider',
              value: availableModels.any((model) => model.providerId == ai.providerId)
                  ? ai.providerId
                  : availableModels.first.providerId,
              items: [
                for (final model in availableModels)
                  DropdownMenuItem(value: model.providerId, child: Text(model.displayName)),
              ],
              onChanged: (value) {
                if (value != null) controller.setAiProviderId(value);
              },
            ),
            SettingsTextRow(
              label: 'Model',
              value: ai.modelId,
              hintText: 'e.g. claude-sonnet-4-5-20250929',
              helper: 'The exact model identifier the selected provider expects.',
              onChanged: controller.setAiModelId,
            ),
            _ApiKeyRow(providerId: ai.providerId),
            const SettingsPlaceholderRow(
              label: 'Local Server Configuration',
              helper: 'For future local providers (Ollama, LM Studio) — not implemented yet.',
            ),
            SettingsSliderRow(
              label: 'Temperature',
              value: ai.temperature,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              onChanged: controller.setAiTemperature,
            ),
            SettingsTextRow(
              label: 'Timeout (seconds)',
              value: ai.timeoutSeconds.toString(),
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) controller.setAiTimeoutSeconds(parsed);
              },
            ),
            SettingsTextRow(
              label: 'Max Tokens',
              value: ai.maxOutputTokens.toString(),
              helper: 'The maximum number of tokens the AI may generate in one response.',
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) controller.setAiMaxOutputTokens(parsed);
              },
            ),
            SettingsTextRow(
              label: 'Context Window (tokens)',
              value: ai.contextWindowTokens.toString(),
              helper: 'Informational — a fixed model property, not sent as a request parameter.',
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) controller.setAiContextWindowTokens(parsed);
              },
            ),
            SettingsDropdownRow<ReasoningDepthPreference>(
              label: 'Reasoning Depth',
              value: ai.reasoningDepth,
              items: const [
                DropdownMenuItem(value: ReasoningDepthPreference.standard, child: Text('Standard')),
                DropdownMenuItem(value: ReasoningDepthPreference.extended, child: Text('Extended')),
              ],
              onChanged: (value) {
                if (value != null) controller.setAiReasoningDepth(value);
              },
            ),
            SettingsSwitchRow(
              label: 'Privacy Controls',
              value: ai.privacyControlsEnabled,
              onChanged: controller.setAiPrivacyControlsEnabled,
            ),
          ],
        ),
        SettingsSection(
          title: 'Connection',
          children: [_TestConnectionRow(providerId: ai.providerId)],
        ),
      ],
    );
  }
}

/// API Key management (Work Package 018 STUDIO-TASK-000057). Never
/// bound to `SettingsController`/`UserConfiguration` — reads/writes
/// `CredentialService.instance` (a `CredentialStore`) directly, and
/// never re-displays a stored key's actual value (only whether one is
/// configured), so a saved secret is never shown back in plaintext
/// after the moment it's typed.
class _ApiKeyRow extends StatefulWidget {
  const _ApiKeyRow({required this.providerId});

  final String providerId;

  @override
  State<_ApiKeyRow> createState() => _ApiKeyRowState();
}

class _ApiKeyRowState extends State<_ApiKeyRow> {
  final _controller = TextEditingController();
  bool _hasKey = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _ApiKeyRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerId != widget.providerId) {
      _controller.clear();
      _refresh();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final key = await CredentialService.instance.readCredential(widget.providerId);
    if (!mounted) return;
    setState(() {
      _hasKey = key != null && key.isNotEmpty;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    await CredentialService.instance.saveCredential(providerId: widget.providerId, secret: value);
    _controller.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API key saved.')));
    await _refresh();
  }

  Future<void> _remove() async {
    await CredentialService.instance.deleteCredential(widget.providerId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API key removed.')));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('API Key', style: TextStyle(color: StudioColors.textPrimary, fontSize: 12.5)),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _loading
                        ? 'Checking…'
                        : (_hasKey ? 'A key is configured for this provider.' : 'No key configured.'),
                    style: TextStyle(
                      color: _hasKey ? StudioColors.success : StudioColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _controller,
                    obscureText: true,
                    style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _hasKey ? 'Enter a new key to replace it' : 'Paste API key',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasKey)
                      TextButton(onPressed: _remove, child: const Text('Remove')),
                    const SizedBox(width: 4),
                    ElevatedButton(onPressed: _save, child: const Text('Save')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Test Connection (Work Package 018 STUDIO-TASK-000058). Goes through
/// the Connection Manager (`testAiConnection`) rather than calling any
/// provider directly, and displays whatever
/// `FoundationServiceState.aiConnectionStatus` the Connection Manager
/// last recorded — "Status shall be visible inside Settings."
class _TestConnectionRow extends ConsumerWidget {
  const _TestConnectionRow({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);
    final notifier = ref.read(foundationRuntimeServiceProvider.notifier);
    final isTesting = foundation.activeAiRequestSourceId == '__test_connection__';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusBadge(status: foundation.aiConnectionStatus),
                  ],
                ),
                if (foundation.aiConnectionMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      foundation.aiConnectionMessage!,
                      style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isTesting ? null : () => notifier.testAiConnection(providerId: providerId),
                icon: isTesting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_tethering, size: 16),
                label: Text(isTesting ? 'Testing…' : 'Test Connection'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AiConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AiConnectionStatus.notTested => ('Not Tested', StudioColors.textSecondary),
      AiConnectionStatus.connected => ('Connected', StudioColors.success),
      AiConnectionStatus.authenticationFailed => ('Authentication Failed', StudioColors.error),
      AiConnectionStatus.networkError => ('Network Error', StudioColors.warning),
      AiConnectionStatus.providerError => ('Provider Error', StudioColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
