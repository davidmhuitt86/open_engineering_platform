#pragma once

#include <atomic>
#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <thread>

#include "oep/acquisition/common/config.hpp"

namespace httplib {
class Server;
}

namespace oep::acquisition::registry {
class OfficialSourceService;
}

namespace oep::acquisition::acquisition {
class AcquisitionJobService;
class AcquisitionExecutionService;
}

namespace oep::acquisition::connectors {
class ConnectorRegistry;
}

namespace oep::acquisition::downloads {
class DownloadService;
}

namespace oep::acquisition::integrity {
class IntegrityVerificationService;
}

namespace oep::acquisition::metadata {
class MetadataExtractionService;
}

namespace oep::acquisition::vault {
class ReferenceVaultService;
}

namespace oep::acquisition::provenance {
class AcquisitionRecordService;
}

namespace oep::acquisition::api {

/// The Engineering Acquisition Manager's HTTP API.
///
/// Embeds `cpp-httplib` directly in-process rather than fronting the
/// service with a separate Node/Fastify gateway -- see README.md
/// "Implementation Decisions" and ADR-0007 (Platform API Strategy) for why.
///
/// `GET /health` (WORK_PACKAGE_001) is always registered, and reflects
/// actual database reachability rather than merely "the process is
/// running" when `database_config` is supplied (non-null): each call
/// opens a short-lived probe connection and runs a trivial query, since a
/// persistent process-lifetime connection can look fine while every real
/// Repository connection has gone bad (see `database::ResilientConnection`)
/// -- `/health` needs to be trustworthy on its own, independent of
/// whichever Repository connections happen to be healthy at the moment.
/// A database outage never fails the probe fatally: `/health` reports
/// `{"status": "degraded", "database": "unavailable"}` with HTTP 503
/// instead of throwing, so `/health` itself stays a reliable diagnostic
/// even while the database is down. When `database_config` is null (e.g.
/// tests that only care about routing/auth), `/health` keeps its original
/// process-alive-only behavior: `{"status": "ok"}` with no `database`
/// field.
///
/// The `/sources`
/// routes (WORK_PACKAGE_002), `/jobs` routes (WORK_PACKAGE_003),
/// `/jobs/{id}/execute`, `/jobs/{id}/cancel`, `/jobs/{id}/status` routes
/// (WORK_PACKAGE_004), `/connectors` routes (WORK_PACKAGE_005),
/// `/downloads` routes (WORK_PACKAGE_006), `/verifications` routes
/// (WORK_PACKAGE_007), `/metadata` routes (WORK_PACKAGE_008), and `/vault`
/// routes (WORK_PACKAGE_009) are each registered only when their
/// respective service/registry pointer is non-null -- `main.cpp` passes
/// `nullptr` if a PostgreSQL repository could not be constructed at
/// startup, so a database outage degrades the process rather than
/// preventing it from starting at all (continuing WORK_PACKAGE_001's
/// non-fatal-database precedent). Unlike the others, `connector_registry`
/// has no PostgreSQL dependency (WORK_PACKAGE_005 keeps connector
/// registration in-memory) and so is effectively always non-null in
/// practice.
///
/// `/acquisition-records` routes (WP-018) follow the same nullable-pointer
/// precedent. Additionally, when `acquisition_record_service` is non-null,
/// the `/downloads`, `/verifications`, `/metadata`, and `/vault` POST
/// handlers each make one best-effort call into it after their own
/// existing service call returns -- see `server.cpp`'s route registration
/// functions and `provenance::AcquisitionRecordService`'s header comment
/// for why this integration lives at the route layer rather than inside
/// those four services themselves.
///
/// WP-SRV-003: `api_token` is required (never defaulted, never empty) --
/// every route this class registers except `GET /health` requires an
/// `Authorization: Bearer <api_token>` header, enforced once, at this
/// class's own boundary, via `httplib::Server::set_pre_routing_handler`
/// rather than inside each individual route handler (see ADR-0002). This
/// is deliberately the only place that check exists: a future Knowledge or
/// Exchange route registered on this same `ApiServer` inherits the same
/// enforcement automatically, and there is nowhere else in this class for
/// a route to accidentally bypass it. Callers (production `main.cpp` and
/// every test) must supply a real, non-empty token explicitly -- there is
/// no default and no way to construct an unauthenticated-by-default
/// instance short of registering no routes at all.
class ApiServer {
 public:
  explicit ApiServer(const common::ServerConfig& config, std::string api_token,
                      registry::OfficialSourceService* source_service = nullptr,
                      acquisition::AcquisitionJobService* job_service = nullptr,
                      acquisition::AcquisitionExecutionService* execution_service = nullptr,
                      connectors::ConnectorRegistry* connector_registry = nullptr,
                      downloads::DownloadService* download_service = nullptr,
                      integrity::IntegrityVerificationService* verification_service = nullptr,
                      metadata::MetadataExtractionService* metadata_service = nullptr,
                      vault::ReferenceVaultService* vault_service = nullptr,
                      provenance::AcquisitionRecordService* acquisition_record_service = nullptr,
                      const common::DatabaseConfig* database_config = nullptr);
  ~ApiServer();

  ApiServer(const ApiServer&) = delete;
  ApiServer& operator=(const ApiServer&) = delete;

  /// Binds the configured host/port and starts accepting connections on a
  /// background thread. Returns false if the bind failed (e.g. the port
  /// is already in use). Passing `config.port == 0` binds an OS-assigned
  /// ephemeral port -- `bound_port()` reports which one, which is how
  /// tests avoid colliding with a fixed port number.
  bool start();

  /// Stops accepting connections and joins the background thread. Safe
  /// to call even if `start()` was never called or already failed.
  void stop();

  [[nodiscard]] bool is_running() const;

  /// The actual bound port once `start()` has succeeded (0 beforehand).
  [[nodiscard]] std::uint16_t bound_port() const;

 private:
  common::ServerConfig config_;
  std::string api_token_;
  registry::OfficialSourceService* source_service_;
  acquisition::AcquisitionJobService* job_service_;
  acquisition::AcquisitionExecutionService* execution_service_;
  connectors::ConnectorRegistry* connector_registry_;
  downloads::DownloadService* download_service_;
  integrity::IntegrityVerificationService* verification_service_;
  metadata::MetadataExtractionService* metadata_service_;
  vault::ReferenceVaultService* vault_service_;
  provenance::AcquisitionRecordService* acquisition_record_service_;
  // Empty when no `database_config` was supplied -- see this class's
  // header comment on `GET /health`'s database-reachability behavior.
  std::optional<std::string> health_connection_string_;
  std::unique_ptr<httplib::Server> server_;
  std::thread thread_;
  std::atomic<bool> running_{false};
  std::uint16_t bound_port_ = 0;
};

}  // namespace oep::acquisition::api
