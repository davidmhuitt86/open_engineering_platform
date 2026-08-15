import 'settings_enums.dart';

/// Settings > Updates (SDD-023): "Automatic Updates, Update Channel,
/// Stable, Preview, Nightly." Stored, validated, and versioned — Studio
/// has no updater component yet, so these values are not yet consumed
/// by anything.
class UpdateSettings {
  const UpdateSettings({required this.automaticUpdatesEnabled, required this.channel});

  factory UpdateSettings.defaults() =>
      const UpdateSettings(automaticUpdatesEnabled: true, channel: UpdateChannel.stable);

  final bool automaticUpdatesEnabled;
  final UpdateChannel channel;

  UpdateSettings copyWith({bool? automaticUpdatesEnabled, UpdateChannel? channel}) {
    return UpdateSettings(
      automaticUpdatesEnabled: automaticUpdatesEnabled ?? this.automaticUpdatesEnabled,
      channel: channel ?? this.channel,
    );
  }

  Map<String, dynamic> toJson() => {'automaticUpdatesEnabled': automaticUpdatesEnabled, 'channel': channel.name};

  factory UpdateSettings.fromJson(Map<String, dynamic> json) {
    final defaults = UpdateSettings.defaults();
    return UpdateSettings(
      automaticUpdatesEnabled: json['automaticUpdatesEnabled'] as bool? ?? defaults.automaticUpdatesEnabled,
      channel: UpdateChannel.values.firstWhere(
        (value) => value.name == json['channel'],
        orElse: () => defaults.channel,
      ),
    );
  }
}
