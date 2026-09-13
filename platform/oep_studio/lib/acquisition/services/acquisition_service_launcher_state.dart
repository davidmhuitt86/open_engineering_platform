/// WP-EAM-LOCAL-SERVICE-001 — the local EAM backend process's own
/// lifecycle, as tracked by [AcquisitionServiceLauncherNotifier]. Distinct
/// from [AcquisitionConnectionStatus] (the *last HTTP check* result),
/// since a service can be `running` (this launcher started it and it is
/// still alive) while a Test Connection has never been re-run, or a
/// remote/externally-managed service can be `connected` while this
/// launcher's own status stays [stopped] forever (it never started it).
enum AcquisitionServiceLauncherStatus { stopped, starting, running, error }

/// Immutable state for [AcquisitionServiceLauncherNotifier].
class AcquisitionServiceLauncherState {
  const AcquisitionServiceLauncherState({
    this.status = AcquisitionServiceLauncherStatus.stopped,
    this.errorMessage,
    this.technicalDetail,
  });

  final AcquisitionServiceLauncherStatus status;

  /// A short, user-facing message (WP-EAM-LOCAL-SERVICE-001: "Do not
  /// expose raw stack traces as the primary user-facing message") — set
  /// only when [status] is [AcquisitionServiceLauncherStatus.error].
  final String? errorMessage;

  /// The tail of the spawned process's own stdout/stderr, kept only for
  /// diagnostics (e.g. a future "show details" affordance) — never
  /// substituted for [errorMessage] as the primary message.
  final String? technicalDetail;

  AcquisitionServiceLauncherState copyWith({
    AcquisitionServiceLauncherStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? technicalDetail,
  }) =>
      AcquisitionServiceLauncherState(
        status: status ?? this.status,
        errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
        technicalDetail: technicalDetail ?? this.technicalDetail,
      );
}
