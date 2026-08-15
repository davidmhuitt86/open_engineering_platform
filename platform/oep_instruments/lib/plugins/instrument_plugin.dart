import 'package:flutter/widgets.dart';

import '../capability/capability_registry.dart';
import '../protocol/oip_message.dart';
import 'plugin_manifest.dart';
import 'plugin_context.dart';

/// OIP-PLUGIN-001 §23 — the contract every instrument plugin implements.
/// "The Runtime owns invocation" — nothing outside the Plugin Manager
/// calls these methods directly.
///
/// Per §5/the whole Constitution: an [InstrumentPlugin] performs NO
/// engineering computation. It owns presentation, interaction,
/// instrument-specific configuration/history/bookmarks, and nothing
/// else. Every engineering value it displays arrives via
/// [receiveMeasurement]/[receiveEvent], sourced from the Host through
/// the Runtime — never computed locally.
abstract class InstrumentPlugin {
  PluginManifest get manifest;

  /// OIP-PLUGIN-001 §6 — this plugin's own declared capabilities,
  /// registered once during [initialize] (§20 of OIP-CAPABILITY-001:
  /// "Capabilities shall register during instrument initialization...
  /// deterministic.").
  CapabilityRegistry get capabilities;

  Future<void> initialize(PluginContext context);

  Future<void> shutdown();

  Future<void> activate();

  Future<void> deactivate();

  Future<void> suspend();

  Future<void> resume();

  /// Builds this instrument's UI. Per OIP-PLUGIN-001 §11: "Each Plugin
  /// owns its own UI... No Runtime modifications required." The Runtime
  /// hosts whatever [Widget] this returns; it never inspects or alters
  /// it.
  Widget render(BuildContext context);

  /// OIP-PLUGIN-001 §17 — Runtime event delivery (Measurement Updated,
  /// Selection Changed, Simulation Started, ...). Plugins never poll;
  /// the Runtime pushes.
  void receiveEvent(OipMessage event);

  /// OIP-PLUGIN-001 §17/OIP-MEASUREMENT-001 — a new/updated Measurement,
  /// delivered by the Runtime. Implementations must not derive a
  /// different value from this one — only present it (Constitution §13).
  void receiveMeasurement(OipMessage measurement);
}
