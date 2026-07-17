#include "oep/acquisition/api/server.hpp"

#include <optional>
#include <string>
#include <vector>

#include <httplib.h>
#include <nlohmann/json.hpp>

#include "oep/acquisition/acquisition/acquisition_job_json.hpp"
#include "oep/acquisition/acquisition/acquisition_job_service.hpp"
#include "oep/acquisition/acquisition/validation.hpp"
#include "oep/acquisition/registry/official_source_json.hpp"
#include "oep/acquisition/registry/official_source_service.hpp"
#include "oep/acquisition/registry/validation.hpp"

namespace oep::acquisition::api {

namespace {

using acquisition::AcquisitionJobService;
using acquisition::JobFilter;
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

// Same idea as guard_sources, plus UnknownSourceError -> 422 for a /jobs
// request whose source_id doesn't reference an existing Official Source
// (see acquisition::IAcquisitionJobRepository).
template <typename Fn>
void guard_jobs(httplib::Response& response, Fn&& fn) {
  try {
    fn();
  } catch (const acquisition::ValidationError& error) {
    respond_validation_error(response, error.violations());
  } catch (const acquisition::UnknownSourceError& ex) {
    respond_error(response, 422, "unknown_source", ex.what());
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

void register_routes(httplib::Server& server, OfficialSourceService* source_service,
                      AcquisitionJobService* job_service) {
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
}

}  // namespace

ApiServer::ApiServer(const common::ServerConfig& config, registry::OfficialSourceService* source_service,
                      acquisition::AcquisitionJobService* job_service)
    : config_(config),
      source_service_(source_service),
      job_service_(job_service),
      server_(std::make_unique<httplib::Server>()) {
  register_routes(*server_, source_service_, job_service_);
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
