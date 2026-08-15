import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/events/platform_event.dart';
import '../../core/events/platform_event_bus.dart';
import '../models/exchange_connection_status.dart';
import '../models/exchange_package.dart';
import '../models/installation.dart';
import '../models/library_entry.dart';
import '../models/publisher.dart';
import '../models/search_result_item.dart';
import '../settings/exchange_settings_provider.dart';
import 'exchange_api_client.dart';
import 'exchange_api_exception.dart';
import 'exchange_library_storage.dart';
import 'exchange_runtime_state.dart';

/// The Exchange Studio's own Connection Manager (WP-EXC-010),
/// structurally mirroring `AcquisitionRuntimeNotifier`'s role: the
/// single owner of Exchange connectivity and cached Exchange data.
/// Widgets watch `exchangeRuntimeServiceProvider` and call methods on
/// its notifier; no widget constructs an [ExchangeApiClient] or calls
/// `dart:http` itself, the same "widgets never touch the bridge
/// directly" rule `AcquisitionRuntimeNotifier` already follows.
///
/// Rebuilds its [ExchangeApiClient] whenever `exchangeSettingsProvider`'s
/// `apiBaseUrl` changes, so a corrected address takes effect without an
/// app restart.
class ExchangeRuntimeNotifier extends Notifier<ExchangeServiceState> {
  ExchangeApiClient? _client;
  bool _libraryLoaded = false;

  @override
  ExchangeServiceState build() {
    final baseUrl = ref.watch(exchangeSettingsProvider).apiBaseUrl;
    _client?.dispose();
    _client = ExchangeApiClient(baseUrl: baseUrl);
    ref.onDispose(() => _client?.dispose());
    if (!_libraryLoaded) {
      _libraryLoaded = true;
      _loadLibrary();
    }
    return const ExchangeServiceState();
  }

  ExchangeApiClient get _api => _client!;

  Future<void> _loadLibrary() async {
    final loaded = await ExchangeLibraryStorage.load();
    state = state.copyWith(library: loaded.library, downloads: loaded.downloads);
  }

  /// `GET /health` -- used by the workspace's connection banner and
  /// Settings' "Test Connection" action.
  Future<void> testConnection() async {
    state = state.copyWith(loading: true, clearLastError: true);
    final reachable = await _api.checkHealth();
    state = state.copyWith(
      loading: false,
      connectionStatus: reachable ? ExchangeConnectionStatus.connected : ExchangeConnectionStatus.networkError,
      connectionMessage: reachable ? 'Connected' : 'Could not reach the Engineering Exchange service.',
    );
  }

  /// Refreshes Marketplace Home's package/publisher samples.
  Future<void> refreshMarketplace() async {
    state = state.copyWith(loading: true, clearLastError: true);
    try {
      final packages = await _api.listPackages();
      final publishers = await _api.listPublishers();
      state = state.copyWith(
        loading: false,
        connectionStatus: ExchangeConnectionStatus.connected,
        packages: packages.map(ExchangePackage.fromJson).toList(),
        publishers: publishers.map(Publisher.fromJson).toList(),
      );
    } on ExchangeApiException catch (error) {
      state = state.copyWith(
        loading: false,
        connectionStatus: ExchangeConnectionStatus.networkError,
        lastError: error.message,
      );
    }
  }

  /// `GET /search` -- Search Results.
  Future<void> search({
    String? q,
    String? publisherId,
    String? categoryId,
    String? status,
    String? sortBy,
    String? sortDirection,
    int? page,
    int? pageSize,
  }) =>
      _runAction(() async {
        final response = await _api.search(
          q: q,
          publisherId: publisherId,
          categoryId: categoryId,
          status: status,
          sortBy: sortBy,
          sortDirection: sortDirection,
          page: page,
          pageSize: pageSize,
        );
        state = state.copyWith(searchResults: ExchangeSearchResponse.fromJson(response));
      });

  /// Package Detail -- loads the selected package and, if My Library
  /// already has an installation on record for it, that installation's
  /// last-known status (refreshed via [refreshInstallationStatus] on
  /// request, not implicitly here).
  Future<void> selectPackage(String packageId) => _runAction(() async {
        final response = await _api.getPackage(packageId);
        final package = ExchangePackage.fromJson(response);
        final existing = state.library.where((entry) => entry.packageId == packageId).toList();
        state = state.copyWith(
          selectedPackage: package,
          clearSelectedPackageInstallation: existing.isEmpty,
        );
      });

  void clearSelectedPackage() => state = state.copyWith(clearSelectedPackage: true, clearSelectedPackageInstallation: true);

  /// Publisher Profile -- loads the selected publisher.
  Future<void> selectPublisher(String publisherId) => _runAction(() async {
        final response = await _api.getPublisher(publisherId);
        state = state.copyWith(selectedPublisher: Publisher.fromJson(response));
      });

  void clearSelectedPublisher() => state = state.copyWith(clearSelectedPublisher: true);

  /// Install Package (WP-EXC-010 §6) -- calls the Exchange's own
  /// already-built Installation REST API (TASK-EXC-0008), then records
  /// the attempt into My Library and publishes an [OperationEvent] so
  /// `OperationManager`/`StudioStatusBar` show install progress the same
  /// way an Acquisition download does. The Exchange API resolves
  /// synchronously to a `completed`/`failed` result (no polling needed
  /// server-side; mirrors `PackageDetailPage`'s own Install button in
  /// `apps/publisher-portal`).
  Future<void> installPackage(String packageId, String displayName, {String? version}) async {
    final operationId = 'exchange.install.$packageId.${DateTime.now().microsecondsSinceEpoch}';
    final bus = PlatformEventBus.instance;
    bus.publish(OperationEvent(id: operationId, kind: OperationEventKind.started, label: 'Installing $displayName…'));
    await _runAction(() async {
      final response = await _api.install(packageId, version: version);
      final installation = Installation.fromJson(response);
      final entry = LibraryEntry(
        packageId: installation.packageId,
        displayName: displayName,
        version: installation.version,
        installationId: installation.id,
        status: installation.status,
        requestedAt: installation.requestedAt,
      );
      final library = [
        for (final existing in state.library) if (existing.packageId != packageId) existing,
        entry,
      ];
      state = state.copyWith(library: library, selectedPackageInstallation: installation);
      await ExchangeLibraryStorage.save(library, state.downloads);
      if (installation.isFailed) {
        bus.publish(OperationEvent(
          id: operationId,
          kind: OperationEventKind.failed,
          label: installation.errorMessage ?? 'Installing $displayName failed.',
        ));
      } else {
        bus.publish(OperationEvent(
          id: operationId,
          kind: OperationEventKind.completed,
          label: 'Installed $displayName.',
        ));
      }
    });
    if (state.lastError != null) {
      bus.publish(OperationEvent(id: operationId, kind: OperationEventKind.failed, label: state.lastError!));
    }
  }

  /// Show Installation Status (WP-EXC-010 §6) -- re-fetches the real
  /// `Installation` by id, mirroring `MyLibraryPage`'s own "Refresh
  /// status" action rather than trusting the cached status forever.
  Future<void> refreshInstallationStatus(String installationId) => _runAction(() async {
        final response = await _api.getInstallation(installationId);
        final installation = Installation.fromJson(response);
        final library = [
          for (final entry in state.library)
            if (entry.installationId == installationId) entry.copyWith(status: installation.status) else entry,
        ];
        state = state.copyWith(
          library: library,
          selectedPackageInstallation:
              state.selectedPackage?.id == installation.packageId ? installation : state.selectedPackageInstallation,
        );
        await ExchangeLibraryStorage.save(library, state.downloads);
      });

  /// Downloads the real package artifact (WP-EXC-010 §5's "Downloads")
  /// to [savePath] -- the caller obtains [savePath] from
  /// `file_selector`'s `getSaveLocation` (mirroring
  /// `DiagramStudioPage.saveDocumentAs`'s own use of that package), then
  /// hands it here so the notifier -- not the widget -- performs the
  /// actual HTTP fetch and file write, keeping "widgets never touch the
  /// bridge directly" intact.
  Future<void> downloadPackage(String packageId, String displayName, String savePath, {String? version}) =>
      _runAction(() async {
        final bytes = await _api.downloadBytes(packageId, version: version);
        await File(savePath).writeAsBytes(bytes);
        final entry = DownloadEntry(
          packageId: packageId,
          displayName: displayName,
          version: version,
          downloadedAt: DateTime.now().toIso8601String(),
        );
        final downloads = [entry, ...state.downloads];
        state = state.copyWith(downloads: downloads);
        await ExchangeLibraryStorage.save(state.library, downloads);
      });

  Future<void> _runAction(Future<void> Function() action) async {
    state = state.copyWith(loading: true, clearLastError: true);
    try {
      await action();
      state = state.copyWith(loading: false);
    } on ExchangeApiException catch (error) {
      state = state.copyWith(loading: false, lastError: error.message);
    }
  }
}

final exchangeRuntimeServiceProvider = NotifierProvider<ExchangeRuntimeNotifier, ExchangeServiceState>(
  ExchangeRuntimeNotifier.new,
);
