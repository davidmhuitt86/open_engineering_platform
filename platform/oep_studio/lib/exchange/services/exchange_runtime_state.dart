import '../models/exchange_connection_status.dart';
import '../models/exchange_package.dart';
import '../models/installation.dart';
import '../models/library_entry.dart';
import '../models/publisher.dart';
import '../models/search_result_item.dart';

/// The Exchange Studio's own Connection Manager state (WP-EXC-010),
/// structurally mirroring `AcquisitionServiceState`'s role for Engineering
/// Acquisition. Immutable; widgets watch this through
/// `exchangeRuntimeServiceProvider` and never call [ExchangeApiClient]
/// directly.
class ExchangeServiceState {
  const ExchangeServiceState({
    this.connectionStatus = ExchangeConnectionStatus.notTested,
    this.connectionMessage,
    this.loading = false,
    this.packages = const [],
    this.publishers = const [],
    this.searchResults = ExchangeSearchResponse.empty,
    this.selectedPackage,
    this.selectedPublisher,
    this.selectedPackageInstallation,
    this.library = const [],
    this.downloads = const [],
    this.lastError,
  });

  final ExchangeConnectionStatus connectionStatus;
  final String? connectionMessage;
  final bool loading;

  /// Marketplace Home's sample of packages (`GET /packages`).
  final List<ExchangePackage> packages;
  final List<Publisher> publishers;
  final ExchangeSearchResponse searchResults;

  /// Package Detail's selected package, `null` when no package is open.
  final ExchangePackage? selectedPackage;

  /// Publisher Profile's selected publisher, `null` when no profile is open.
  final Publisher? selectedPublisher;

  /// The most recent installation attempt for [selectedPackage] --
  /// WP-EXC-010 §5's "Installation Progress" / §6's "Show Installation
  /// Status" both read this field.
  final Installation? selectedPackageInstallation;

  /// My Library -- every package this Studio has ever installed,
  /// persisted locally (`ExchangeLibraryStorage`).
  final List<LibraryEntry> library;

  /// Downloads -- every package artifact downloaded from this Studio,
  /// persisted locally.
  final List<DownloadEntry> downloads;

  final String? lastError;

  bool get isConnected => connectionStatus == ExchangeConnectionStatus.connected;

  ExchangeServiceState copyWith({
    ExchangeConnectionStatus? connectionStatus,
    String? connectionMessage,
    bool? loading,
    List<ExchangePackage>? packages,
    List<Publisher>? publishers,
    ExchangeSearchResponse? searchResults,
    ExchangePackage? selectedPackage,
    bool clearSelectedPackage = false,
    Publisher? selectedPublisher,
    bool clearSelectedPublisher = false,
    Installation? selectedPackageInstallation,
    bool clearSelectedPackageInstallation = false,
    List<LibraryEntry>? library,
    List<DownloadEntry>? downloads,
    String? lastError,
    bool clearLastError = false,
  }) {
    return ExchangeServiceState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      connectionMessage: connectionMessage ?? this.connectionMessage,
      loading: loading ?? this.loading,
      packages: packages ?? this.packages,
      publishers: publishers ?? this.publishers,
      searchResults: searchResults ?? this.searchResults,
      selectedPackage: clearSelectedPackage ? null : (selectedPackage ?? this.selectedPackage),
      selectedPublisher: clearSelectedPublisher ? null : (selectedPublisher ?? this.selectedPublisher),
      selectedPackageInstallation: clearSelectedPackageInstallation
          ? null
          : (selectedPackageInstallation ?? this.selectedPackageInstallation),
      library: library ?? this.library,
      downloads: downloads ?? this.downloads,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}
