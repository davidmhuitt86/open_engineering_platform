#include "oep/acquisition/api/server.hpp"

#include <optional>
#include <string>
#include <vector>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "oep/acquisition/acquisition/acquisition_execution_json.hpp"
#include "oep/acquisition/acquisition/acquisition_execution_service.hpp"
#include "oep/acquisition/acquisition/acquisition_job_json.hpp"
#include "oep/acquisition/acquisition/acquisition_job_service.hpp"
#include "oep/acquisition/acquisition/validation.hpp"
#include "oep/acquisition/connectors/connector_json.hpp"
#include "oep/acquisition/connectors/connector_registry.hpp"
#include "oep/acquisition/downloads/download_errors.hpp"
#include "oep/acquisition/downloads/download_json.hpp"
#include "oep/acquisition/downloads/download_service.hpp"
#include "oep/acquisition/downloads/validation.hpp"
#include "oep/acquisition/integrity/integrity_verification_service.hpp"
#include "oep/acquisition/integrity/validation.hpp"
#include "oep/acquisition/integrity/verification_errors.hpp"
#include "oep/acquisition/integrity/verification_json.hpp"
#include "oep/acquisition/metadata/artifact_metadata_errors.hpp"
#include "oep/acquisition/metadata/artifact_metadata_json.hpp"
#include "oep/acquisition/metadata/metadata_extraction_service.hpp"
#include "oep/acquisition/metadata/validation.hpp"
#include "oep/acquisition/registry/official_source_json.hpp"
#include "oep/acquisition/registry/official_source_service.hpp"
#include "oep/acquisition/registry/validation.hpp"

namespace oep::acquisition::api {

namespace {

using acquisition::AcquisitionExecutionService;
using acquisition::AcquisitionJobService;
using acquisition::JobFilter;
using connectors::ConnectorRegistry;
using downloads::DownloadFilter;
using downloads::DownloadService;
using integrity::IntegrityVerificationService;
using integrity::VerificationFilter;
using metadata::MetadataExtractionService;
using metadata::MetadataFilter;
using registry::OfficialSourceService;
using registry::SourceFilter;

void respond_json(httplib::Response& response, int status, const nlohmann::json& body) {
  response.status = status;
  response.set_content(body.dump(), "application/json");
}

void respond_error(httplib::Response& response, int status, const std::string& code,
                    const std::string& message) {
  respond_json(response, status, nlohmann::json{{"error", code}, {"message", message}});
}

void respond_validation_error(httplib::Response& response, const std::vector<std::string>& violations) {
  respond_json(response, 422, nlohmann::json{{"error", "validation_failed"}, {"violations", violations}});
}

// Every /sources handler runs a repository call under this so a database
// outage after startup (connection lost, statement timeout, etc.) surfaces
// as a 503 rather than tearing down the whole HTTP server.
template <typename Fn>
void guard_sources(httplib::Response& response, Fn&& fn) {
  try {
    fn();
  } catch (const registry::ValidationError& error) {
    respond_validation_error(response, error.violations());
  } catch (const std::exception& ex) {
    respond_error(response, 503, "service_unavailable", ex.what());
  }
}

// Same idea as guard_sources, plus:
// - UnknownSourceError -> 422 for a /jobs request whose source_id doesn't
//   reference an existing Official Source (see
//   acquisition::IAcquisitionJobRepository).
// - InvalidTransitionError / SourceNotAvailableError -> 409 for a
//   WORK_PACKAGE-004 execution request (/execute, /cancel) that conflicts
//   with the job's or its source's current state.
template <typename Fn>
void guard_jobs(httplib::Response& response, Fn&& fn) {
  try {
    fn();
  } catch (const acquisition::ValidationError& error) {
    respond_validation_error(response, error.violations());
  } catch (const acquisition::UnknownSourceError& ex) {
    respond_error(response, 422, "unknown_source", ex.what());
  } catch (const acquisition::InvalidTransitionError& ex) {
    respond_error(response, 409, "invalid_transition", ex.what());
  } catch (const acquisition::SourceNotAvailableError& ex) {
    respond_error(response, 409, "source_unavailable", ex.what());
  } catch (const std::exception& ex) {
    respond_error(response, 503, "service_unavailable", ex.what());
  }
}

std::optional<SourceFilter> parse_filter(const httplib::Request& request, httplib::Response& response) {
  SourceFilter filter;

  if (request.has_param("status")) {
    const auto status = registry::source_status_from_string(request.get_param_value("status"));
    if (!status.has_value()) {
      respond_error(response, 400, "invalid_query_parameter", "status is not a recognized Source Status.");
      return std::nullopt;
    }
    filter.status = status;
  }

  if (request.has_param("trust_level")) {
    try {
      const int value = std::stoi(request.get_param_value("trust_level"));
      const auto level = registry::trust_level_from_int(value);
      if (!level.has_value()) {
        respond_error(response, 400, "invalid_query_parameter", "trust_level must be an integer between 0 and 5.");
        return std::nullopt;
      }
      filter.trust_level = level;
    } catch (const std::exception&) {
      respond_error(response, 400, "invalid_query_parameter", "trust_level must be an integer between 0 and 5.");
      return std::nullopt;
    }
  }

  if (request.has_param("category")) {
    filter.category = request.get_param_value("category");
  }
  if (request.has_param("country")) {
    filter.country = request.get_param_value("country");
  }

  return filter;
}

void register_sources_routes(httplib::Server& server, OfficialSourceService& service) {
  server.Get("/sources", [&service](const httplib::Request& request, httplib::Response& response) {
    const auto filter = parse_filter(request, response);
    if (!filter.has_value()) {
      return;  // parse_filter already populated a 400 response.
    }
    guard_sources(response, [&] {
      const auto sources = service.list(*filter);
      nlohmann::json body = nlohmann::json::array();
      for (const auto& source : sources) {
        body.push_back(registry::to_json(source));
      }
      respond_json(response, 200, body);
    });
  });

  server.Get(R"(/sources/([^/]+))", [&service](const httplib::Request& request, httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_sources(response, [&] {
      const auto source = service.get(id);
      if (!source.has_value()) {
        respond_error(response, 404, "not_found", "No source exists with that id.");
        return;
      }
      respond_json(response, 200, registry::to_json(*source));
    });
  });

  server.Post("/sources", [&service](const httplib::Request& request, httplib::Response& response) {
    nlohmann::json body;
    try {
      body = nlohmann::json::parse(request.body);
    } catch (const nlohmann::json::exception&) {
      respond_error(response, 400, "invalid_json", "Request body is not valid JSON.");
      return;
    }
    guard_sources(response, [&] {
      const auto created = service.create(body);
      response.set_header("Location", "/sources/" + created.id);
      respond_json(response, 201, registry::to_json(created));
    });
  });

  server.Put(R"(/sources/([^/]+))", [&service](const httplib::Request& request, httplib::Response& response) {
    const std::string id = request.matches[1];
    nlohmann::json body;
    try {
      body = nlohmann::json::parse(request.body);
    } catch (const nlohmann::json::exception&) {
      respond_error(response, 400, "invalid_json", "Request body is not valid JSON.");
      return;
    }
    guard_sources(response, [&] {
      const auto updated = service.update(id, body);
      if (!updated.has_value()) {
        respond_error(response, 404, "not_found", "No source exists with that id.");
        return;
      }
      respond_json(response, 200, registry::to_json(*updated));
    });
  });

  server.Delete(R"(/sources/([^/]+))", [&service](const httplib::Request& request, httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_sources(response, [&] {
      if (!service.remove(id)) {
        respond_error(response, 404, "not_found", "No source exists with that id.");
        return;
      }
      response.status = 204;
    });
  });
}

std::optional<JobFilter> parse_job_filter(const httplib::Request& request, httplib::Response& response) {
  JobFilter filter;

  if (request.has_param("status")) {
    const auto status = acquisition::job_status_from_string(request.get_param_value("status"));
    if (!status.has_value()) {
      respond_error(response, 400, "invalid_query_parameter", "status is not a recognized Job Status.");
      return std::nullopt;
    }
    filter.status = status;
  }

  if (request.has_param("priority")) {
    try {
      const int value = std::stoi(request.get_param_value("priority"));
      const auto priority = acquisition::job_priority_from_int(value);
      if (!priority.has_value()) {
        respond_error(response, 400, "invalid_query_parameter", "priority must be an integer between 0 and 3.");
        return std::nullopt;
      }
      filter.priority = priority;
    } catch (const std::exception&) {
      respond_error(response, 400, "invalid_query_parameter", "priority must be an integer between 0 and 3.");
      return std::nullopt;
    }
  }

  if (request.has_param("source_id")) {
    filter.source_id = request.get_param_value("source_id");
  }
  if (request.has_param("requested_by")) {
    filter.requested_by = request.get_param_value("requested_by");
  }

  return filter;
}

void register_jobs_routes(httplib::Server& server, AcquisitionJobService& service) {
  server.Get("/jobs", [&service](const httplib::Request& request, httplib::Response& response) {
    const auto filter = parse_job_filter(request, response);
    if (!filter.has_value()) {
      return;  // parse_job_filter already populated a 400 response.
    }
    guard_jobs(response, [&] {
      const auto jobs = service.list(*filter);
      nlohmann::json body = nlohmann::json::array();
      for (const auto& job : jobs) {
        body.push_back(acquisition::to_json(job));
      }
      respond_json(response, 200, body);
    });
  });

  server.Get(R"(/jobs/([^/]+))", [&service](const httplib::Request& request, httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_jobs(response, [&] {
      const auto job = service.get(id);
      if (!job.has_value()) {
        respond_error(response, 404, "not_found", "No job exists with that id.");
        return;
      }
      respond_json(response, 200, acquisition::to_json(*job));
    });
  });

  server.Post("/jobs", [&service](const httplib::Request& request, httplib::Response& response) {
    nlohmann::json body;
    try {
      body = nlohmann::json::parse(request.body);
    } catch (const nlohmann::json::exception&) {
      respond_error(response, 400, "invalid_json", "Request body is not valid JSON.");
      return;
    }
    guard_jobs(response, [&] {
      const auto created = service.create(body);
      response.set_header("Location", "/jobs/" + created.id);
      respond_json(response, 201, acquisition::to_json(created));
    });
  });

  server.Put(R"(/jobs/([^/]+))", [&service](const httplib::Request& request, httplib::Response& response) {
    const std::string id = request.matches[1];
    nlohmann::json body;
    try {
      body = nlohmann::json::parse(request.body);
    } catch (const nlohmann::json::exception&) {
      respond_error(response, 400, "invalid_json", "Request body is not valid JSON.");
      return;
    }
    guard_jobs(response, [&] {
      const auto updated = service.update(id, body);
      if (!updated.has_value()) {
        respond_error(response, 404, "not_found", "No job exists with that id.");
        return;
      }
      respond_json(response, 200, acquisition::to_json(*updated));
    });
  });

  server.Delete(R"(/jobs/([^/]+))", [&service](const httplib::Request& request, httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_jobs(response, [&] {
      if (!service.remove(id)) {
        respond_error(response, 404, "not_found", "No job exists with that id.");
        return;
      }
      response.status = 204;
    });
  });
}

void register_execution_routes(httplib::Server& server, AcquisitionExecutionService& service) {
  server.Post(R"(/jobs/([^/]+)/execute)", [&service](const httplib::Request& request,
                                                        httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_jobs(response, [&] {
      const auto job = service.execute(id);
      if (!job.has_value()) {
        respond_error(response, 404, "not_found", "No job exists with that id.");
        return;
      }
      respond_json(response, 200, acquisition::to_json(*job));
    });
  });

  server.Post(R"(/jobs/([^/]+)/cancel)", [&service](const httplib::Request& request,
                                                        httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_jobs(response, [&] {
      const auto job = service.cancel(id);
      if (!job.has_value()) {
        respond_error(response, 404, "not_found", "No job exists with that id.");
        return;
      }
      respond_json(response, 200, acquisition::to_json(*job));
    });
  });

  server.Get(R"(/jobs/([^/]+)/status)", [&service](const httplib::Request& request,
                                                       httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_jobs(response, [&] {
      const auto status = service.get_status(id);
      if (!status.has_value()) {
        respond_error(response, 404, "not_found", "No job exists with that id.");
        return;
      }
      respond_json(response, 200, acquisition::to_json(*status));
    });
  });
}

// Every /connectors handler is read-only (WORK_PACKAGE-005's REST API
// section lists only GET routes -- connectors are registered by
// main.cpp at startup, not created through this API), so the only
// failure mode besides "not found" is an unexpected exception.
template <typename Fn>
void guard_connectors(httplib::Response& response, Fn&& fn) {
  try {
    fn();
  } catch (const std::exception& ex) {
    respond_error(response, 503, "service_unavailable", ex.what());
  }
}

void register_connectors_routes(httplib::Server& server, ConnectorRegistry& registry) {
  server.Get("/connectors", [&registry](const httplib::Request&, httplib::Response& response) {
    guard_connectors(response, [&] {
      nlohmann::json body = nlohmann::json::array();
      for (const connectors::IConnector* connector : registry.list()) {
        body.push_back(connectors::to_json(connector->config()));
      }
      respond_json(response, 200, body);
    });
  });

  server.Get(R"(/connectors/([^/]+))", [&registry](const httplib::Request& request,
                                                       httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_connectors(response, [&] {
      const connectors::IConnector* connector = registry.resolve(id);
      if (connector == nullptr) {
        respond_error(response, 404, "not_found", "No connector exists with that id.");
        return;
      }
      respond_json(response, 200, connectors::to_json(connector->config()));
    });
  });

  server.Get(R"(/connectors/([^/]+)/capabilities)", [&registry](const httplib::Request& request,
                                                                    httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_connectors(response, [&] {
      const connectors::IConnector* connector = registry.resolve(id);
      if (connector == nullptr) {
        respond_error(response, 404, "not_found", "No connector exists with that id.");
        return;
      }
      respond_json(response, 200, connectors::capabilities_to_json(id, connector->capabilities()));
    });
  });

  server.Get(R"(/connectors/([^/]+)/health)", [&registry](const httplib::Request& request,
                                                              httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_connectors(response, [&] {
      const connectors::IConnector* connector = registry.resolve(id);
      if (connector == nullptr) {
        respond_error(response, 404, "not_found", "No connector exists with that id.");
        return;
      }
      respond_json(response, 200, connectors::health_to_json(id, connector->health_check()));
    });
  });
}

// Same idea as guard_jobs, for WORK_PACKAGE-006's Validation Rules and
// state transitions:
// - ValidationError -> 422 (missing job_id/connector_id/source_uri).
// - UnknownJobError / UnknownConnectorError -> 422 ("Job shall exist" /
//   "Connector shall exist").
// - JobNotExecutableError / ConnectorUnhealthyError -> 409 ("Job shall
//   be executable" / "Connector shall be healthy").
// - InvalidDestinationError -> 422 ("Download destination shall
//   validate").
// - InvalidTransitionError -> 409 (cancelling a terminal download).
template <typename Fn>
void guard_downloads(httplib::Response& response, Fn&& fn) {
  try {
    fn();
  } catch (const downloads::ValidationError& error) {
    respond_validation_error(response, error.violations());
  } catch (const downloads::UnknownJobError& ex) {
    respond_error(response, 422, "unknown_job", ex.what());
  } catch (const downloads::UnknownConnectorError& ex) {
    respond_error(response, 422, "unknown_connector", ex.what());
  } catch (const downloads::InvalidDestinationError& ex) {
    respond_error(response, 422, "invalid_destination", ex.what());
  } catch (const downloads::JobNotExecutableError& ex) {
    respond_error(response, 409, "job_not_executable", ex.what());
  } catch (const downloads::ConnectorUnhealthyError& ex) {
    respond_error(response, 409, "connector_unhealthy", ex.what());
  } catch (const downloads::InvalidTransitionError& ex) {
    respond_error(response, 409, "invalid_transition", ex.what());
  } catch (const std::exception& ex) {
    respond_error(response, 503, "service_unavailable", ex.what());
  }
}

std::optional<DownloadFilter> parse_download_filter(const httplib::Request& request,
                                                       httplib::Response& response) {
  DownloadFilter filter;

  if (request.has_param("status")) {
    const auto status = downloads::download_status_from_string(request.get_param_value("status"));
    if (!status.has_value()) {
      respond_error(response, 400, "invalid_query_parameter", "status is not a recognized Download Status.");
      return std::nullopt;
    }
    filter.status = status;
  }

  if (request.has_param("job_id")) {
    filter.job_id = request.get_param_value("job_id");
  }
  if (request.has_param("connector_id")) {
    filter.connector_id = request.get_param_value("connector_id");
  }

  return filter;
}

void register_downloads_routes(httplib::Server& server, DownloadService& service) {
  server.Post("/downloads", [&service](const httplib::Request& request, httplib::Response& response) {
    nlohmann::json body;
    try {
      body = nlohmann::json::parse(request.body);
    } catch (const nlohmann::json::exception&) {
      respond_error(response, 400, "invalid_json", "Request body is not valid JSON.");
      return;
    }
    guard_downloads(response, [&] {
      const auto created = service.start_download(body);
      response.set_header("Location", "/downloads/" + created.id);
      respond_json(response, 201, downloads::to_json(created));
    });
  });

  server.Get("/downloads", [&service](const httplib::Request& request, httplib::Response& response) {
    const auto filter = parse_download_filter(request, response);
    if (!filter.has_value()) {
      return;  // parse_download_filter already populated a 400 response.
    }
    guard_downloads(response, [&] {
      const auto downloads_list = service.list(*filter);
      nlohmann::json body = nlohmann::json::array();
      for (const auto& download : downloads_list) {
        body.push_back(downloads::to_json(download));
      }
      respond_json(response, 200, body);
    });
  });

  server.Get(R"(/downloads/([^/]+))", [&service](const httplib::Request& request,
                                                    httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_downloads(response, [&] {
      const auto download = service.get(id);
      if (!download.has_value()) {
        respond_error(response, 404, "not_found", "No download exists with that id.");
        return;
      }
      respond_json(response, 200, downloads::to_json(*download));
    });
  });

  server.Get(R"(/downloads/([^/]+)/status)", [&service](const httplib::Request& request,
                                                            httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_downloads(response, [&] {
      const auto download = service.get(id);
      if (!download.has_value()) {
        respond_error(response, 404, "not_found", "No download exists with that id.");
        return;
      }
      respond_json(response, 200, downloads::status_to_json(*download));
    });
  });

  server.Post(R"(/downloads/([^/]+)/cancel)", [&service](const httplib::Request& request,
                                                             httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_downloads(response, [&] {
      const auto download = service.cancel(id);
      if (!download.has_value()) {
        respond_error(response, 404, "not_found", "No download exists with that id.");
        return;
      }
      respond_json(response, 200, downloads::to_json(*download));
    });
  });
}

// Same idea as guard_downloads, for WORK_PACKAGE-007's Validation Rules:
// - ValidationError -> 422 (missing download_session_id).
// - UnknownDownloadSessionError -> 422 ("Download session shall exist").
// A missing/empty/unreadable/corrupt artifact is NOT an exception here --
// IntegrityVerificationService records those as a Failed Verification and
// returns normally (see its header comment), so no additional catch clause
// is needed for them.
template <typename Fn>
void guard_verifications(httplib::Response& response, Fn&& fn) {
  try {
    fn();
  } catch (const integrity::ValidationError& error) {
    respond_validation_error(response, error.violations());
  } catch (const integrity::UnknownDownloadSessionError& ex) {
    respond_error(response, 422, "unknown_download_session", ex.what());
  } catch (const std::exception& ex) {
    respond_error(response, 503, "service_unavailable", ex.what());
  }
}

std::optional<VerificationFilter> parse_verification_filter(const httplib::Request& request,
                                                                httplib::Response& response) {
  VerificationFilter filter;

  if (request.has_param("status")) {
    const auto status = integrity::verification_status_from_string(request.get_param_value("status"));
    if (!status.has_value()) {
      respond_error(response, 400, "invalid_query_parameter",
                     "status is not a recognized Verification Status.");
      return std::nullopt;
    }
    filter.status = status;
  }

  if (request.has_param("download_session_id")) {
    filter.download_session_id = request.get_param_value("download_session_id");
  }

  return filter;
}

void register_verifications_routes(httplib::Server& server, IntegrityVerificationService& service) {
  server.Post("/verifications", [&service](const httplib::Request& request, httplib::Response& response) {
    nlohmann::json body;
    try {
      body = nlohmann::json::parse(request.body);
    } catch (const nlohmann::json::exception&) {
      respond_error(response, 400, "invalid_json", "Request body is not valid JSON.");
      return;
    }
    guard_verifications(response, [&] {
      const auto created = service.verify(body);
      response.set_header("Location", "/verifications/" + created.id);
      respond_json(response, 201, integrity::to_json(created));
    });
  });

  server.Get("/verifications", [&service](const httplib::Request& request, httplib::Response& response) {
    const auto filter = parse_verification_filter(request, response);
    if (!filter.has_value()) {
      return;  // parse_verification_filter already populated a 400 response.
    }
    guard_verifications(response, [&] {
      const auto verifications = service.list(*filter);
      nlohmann::json body = nlohmann::json::array();
      for (const auto& verification : verifications) {
        body.push_back(integrity::to_json(verification));
      }
      respond_json(response, 200, body);
    });
  });

  server.Get(R"(/verifications/([^/]+))", [&service](const httplib::Request& request,
                                                         httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_verifications(response, [&] {
      const auto verification = service.get(id);
      if (!verification.has_value()) {
        respond_error(response, 404, "not_found", "No verification exists with that id.");
        return;
      }
      respond_json(response, 200, integrity::to_json(*verification));
    });
  });

  server.Get(R"(/verifications/([^/]+)/status)", [&service](const httplib::Request& request,
                                                                 httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_verifications(response, [&] {
      const auto verification = service.get(id);
      if (!verification.has_value()) {
        respond_error(response, 404, "not_found", "No verification exists with that id.");
        return;
      }
      respond_json(response, 200, integrity::status_to_json(*verification));
    });
  });
}

// Same idea as guard_verifications, for WORK_PACKAGE-008's Validation
// Rules:
// - ValidationError -> 422 (missing verification_id).
// - UnknownVerificationError -> 422 ("Verification shall exist").
// - VerificationNotSuccessfulError -> 409 ("Verification shall be
//   successful" -- a state conflict on an otherwise-valid reference,
//   mirroring guard_downloads' job_not_executable/connector_unhealthy).
// A missing/unreadable artifact or an unrecognized file type is NOT an
// exception here -- MetadataExtractionService records those as a
// Failed/Extracted-with-type-Unknown ArtifactMetadata and returns
// normally (see its header comment), so no additional catch clause is
// needed for them.
template <typename Fn>
void guard_metadata(httplib::Response& response, Fn&& fn) {
  try {
    fn();
  } catch (const metadata::ValidationError& error) {
    respond_validation_error(response, error.violations());
  } catch (const metadata::UnknownVerificationError& ex) {
    respond_error(response, 422, "unknown_verification", ex.what());
  } catch (const metadata::VerificationNotSuccessfulError& ex) {
    respond_error(response, 409, "verification_not_successful", ex.what());
  } catch (const std::exception& ex) {
    respond_error(response, 503, "service_unavailable", ex.what());
  }
}

std::optional<MetadataFilter> parse_metadata_filter(const httplib::Request& request,
                                                        httplib::Response& response) {
  MetadataFilter filter;

  if (request.has_param("status")) {
    const auto status = metadata::extraction_status_from_string(request.get_param_value("status"));
    if (!status.has_value()) {
      respond_error(response, 400, "invalid_query_parameter",
                     "status is not a recognized Extraction Status.");
      return std::nullopt;
    }
    filter.status = status;
  }

  if (request.has_param("verification_id")) {
    filter.verification_id = request.get_param_value("verification_id");
  }

  return filter;
}

void register_metadata_routes(httplib::Server& server, MetadataExtractionService& service) {
  server.Post("/metadata", [&service](const httplib::Request& request, httplib::Response& response) {
    nlohmann::json body;
    try {
      body = nlohmann::json::parse(request.body);
    } catch (const nlohmann::json::exception&) {
      respond_error(response, 400, "invalid_json", "Request body is not valid JSON.");
      return;
    }
    guard_metadata(response, [&] {
      const auto created = service.extract(body);
      response.set_header("Location", "/metadata/" + created.id);
      respond_json(response, 201, metadata::to_json(created));
    });
  });

  server.Get("/metadata", [&service](const httplib::Request& request, httplib::Response& response) {
    const auto filter = parse_metadata_filter(request, response);
    if (!filter.has_value()) {
      return;  // parse_metadata_filter already populated a 400 response.
    }
    guard_metadata(response, [&] {
      const auto records = service.list(*filter);
      nlohmann::json body = nlohmann::json::array();
      for (const auto& record : records) {
        body.push_back(metadata::to_json(record));
      }
      respond_json(response, 200, body);
    });
  });

  server.Get(R"(/metadata/([^/]+))", [&service](const httplib::Request& request,
                                                    httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_metadata(response, [&] {
      const auto record = service.get(id);
      if (!record.has_value()) {
        respond_error(response, 404, "not_found", "No metadata record exists with that id.");
        return;
      }
      respond_json(response, 200, metadata::to_json(*record));
    });
  });

  server.Get(R"(/metadata/([^/]+)/status)", [&service](const httplib::Request& request,
                                                           httplib::Response& response) {
    const std::string id = request.matches[1];
    guard_metadata(response, [&] {
      const auto record = service.get(id);
      if (!record.has_value()) {
        respond_error(response, 404, "not_found", "No metadata record exists with that id.");
        return;
      }
      respond_json(response, 200, metadata::status_to_json(*record));
    });
  });
}

void register_routes(httplib::Server& server, OfficialSourceService* source_service,
                      AcquisitionJobService* job_service, AcquisitionExecutionService* execution_service,
                      ConnectorRegistry* connector_registry, DownloadService* download_service,
                      IntegrityVerificationService* verification_service,
                      MetadataExtractionService* metadata_service) {
  server.Get("/health", [](const httplib::Request&, httplib::Response& response) {
    const nlohmann::json body{{"status", "ok"}};
    response.set_content(body.dump(), "application/json");
  });

  if (source_service != nullptr) {
    register_sources_routes(server, *source_service);
  }
  if (job_service != nullptr) {
    register_jobs_routes(server, *job_service);
  }
  if (execution_service != nullptr) {
    register_execution_routes(server, *execution_service);
  }
  if (connector_registry != nullptr) {
    register_connectors_routes(server, *connector_registry);
  }
  if (download_service != nullptr) {
    register_downloads_routes(server, *download_service);
  }
  if (verification_service != nullptr) {
    register_verifications_routes(server, *verification_service);
  }
  if (metadata_service != nullptr) {
    register_metadata_routes(server, *metadata_service);
  }
}

}  // namespace

ApiServer::ApiServer(const common::ServerConfig& config, registry::OfficialSourceService* source_service,
                      acquisition::AcquisitionJobService* job_service,
                      acquisition::AcquisitionExecutionService* execution_service,
                      connectors::ConnectorRegistry* connector_registry,
                      downloads::DownloadService* download_service,
                      integrity::IntegrityVerificationService* verification_service,
                      metadata::MetadataExtractionService* metadata_service)
    : config_(config),
      source_service_(source_service),
      job_service_(job_service),
      execution_service_(execution_service),
      connector_registry_(connector_registry),
      download_service_(download_service),
      verification_service_(verification_service),
      metadata_service_(metadata_service),
      server_(std::make_unique<httplib::Server>()) {
  register_routes(*server_, source_service_, job_service_, execution_service_, connector_registry_,
                   download_service_, verification_service_, metadata_service_);
}

ApiServer::~ApiServer() {
  stop();
}

bool ApiServer::start() {
  if (running_) {
    return true;
  }

  // `bind_to_port` returns bool, not the bound port -- port 0 (an
  // OS-assigned ephemeral port, used by tests) needs `bind_to_any_port`,
  // which is the one overload that actually returns the resulting port
  // number.
  if (config_.port == 0) {
    const int bound = server_->bind_to_any_port(config_.host);
    if (bound <= 0) {
      return false;
    }
    bound_port_ = static_cast<std::uint16_t>(bound);
  } else {
    if (!server_->bind_to_port(config_.host, config_.port)) {
      return false;
    }
    bound_port_ = config_.port;
  }

  running_ = true;
  thread_ = std::thread([this]() { server_->listen_after_bind(); });
  server_->wait_until_ready();
  return true;
}

void ApiServer::stop() {
  if (!running_) {
    return;
  }
  server_->stop();
  if (thread_.joinable()) {
    thread_.join();
  }
  running_ = false;
  bound_port_ = 0;
}

bool ApiServer::is_running() const {
  return running_;
}

std::uint16_t ApiServer::bound_port() const {
  return bound_port_;
}

}  // namespace oep::acquisition::api
