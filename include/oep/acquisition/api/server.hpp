#pragma once

#include <atomic>
#include <cstdint>
#include <memory>
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

namespace oep::acquisition::api {

/// The Engineering Acquisition Manager's HTTP API.
///
/// Embeds `cpp-httplib` directly in-process rather than fronting the
/// service with a separate Node/Fastify gateway -- see README.md
/// "Implementation Decisions" and ADR-0007 (Platform API Strategy) for why.
///
/// `GET /health` (WORK_PACKAGE_001) is always registered. The `/sources`
/// routes (WORK_PACKAGE_002), `/jobs` routes (WORK_PACKAGE_003),
/// `/jobs/{id}/execute`, `/jobs/{id}/cancel`, `/jobs/{id}/status` routes
/// (WORK_PACKAGE_004), `/connectors` routes (WORK_PACKAGE_005),
/// `/downloads` routes (WORK_PACKAGE_006), and `/verifications` routes
/// (WORK_PACKAGE_007) are each registered only when their respective
/// service/registry pointer is non-null -- `main.cpp` passes `nullptr` if
/// a PostgreSQL repository could not be constructed at startup, so a
/// database outage degrades the process rather than preventing it from
/// starting at all (continuing WORK_PACKAGE_001's non-fatal-database
/// precedent). Unlike the others, `connector_registry` has no PostgreSQL
/// dependency (WORK_PACKAGE_005 keeps connector registration in-memory)
/// and so is effectively always non-null in practice.
class ApiServer {
 public:
  explicit ApiServer(const common::ServerConfig& config,
                      registry::OfficialSourceService* source_service = nullptr,
                      acquisition::AcquisitionJobService* job_service = nullptr,
                      acquisition::AcquisitionExecutionService* execution_service = nullptr,
                      connectors::ConnectorRegistry* connector_registry = nullptr,
                      downloads::DownloadService* download_service = nullptr,
                      integrity::IntegrityVerificationService* verification_service = nullptr);
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
  registry::OfficialSourceService* source_service_;
  acquisition::AcquisitionJobService* job_service_;
  acquisition::AcquisitionExecutionService* execution_service_;
  connectors::ConnectorRegistry* connector_registry_;
  downloads::DownloadService* download_service_;
  integrity::IntegrityVerificationService* verification_service_;
  std::unique_ptr<httplib::Server> server_;
  std::thread thread_;
  std::atomic<bool> running_{false};
  std::uint16_t bound_port_ = 0;
};

}  // namespace oep::acquisition::api
