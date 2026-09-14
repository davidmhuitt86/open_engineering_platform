#include "oep/server_repository/api/server.hpp"

#include <optional>
#include <stdexcept>
#include <string>
#include <vector>

#include <httplib.h>
#include <nlohmann/json.hpp>
#include <pqxx/pqxx>

#include "oep/server_repository/api/auth.hpp"
#include "oep/server_repository/common/logger.hpp"
#include "oep/server_repository/common/uuid.hpp"
#include "oep/server_repository/domain/errors.hpp"
#include "oep/server_repository/persistence/store.hpp"

namespace oep::server_repository::api {

namespace {

using domain::CommitRequest;
using domain::CommitResult;
using domain::ConcurrencyConflictError;
using domain::EngineeringObject;
using domain::IdempotencyConflictError;
using domain::NotFoundError;
using domain::ObjectMutation;
using domain::Relationship;
using domain::RelationshipMutation;
using domain::RepositoryCreateRequest;
using domain::RepositoryMetadata;
using domain::ValidationError;
using persistence::ServerRepositoryStore;

// ---------------------------------------------------------------------
// JSON <-> domain translation (ADR-0006 SS16: application/json, ISO 8601
// timestamps, canonical UUID strings -- no binary content, no new
// convention beyond what EAM already established).
// ---------------------------------------------------------------------

nlohmann::json tags_to_json(const std::string& csv_tags) {
  nlohmann::json array = nlohmann::json::array();
  if (csv_tags.empty()) {
    return array;
  }
  std::size_t start = 0;
  while (start <= csv_tags.size()) {
    const std::size_t comma = csv_tags.find(',', start);
    const std::size_t end = (comma == std::string::npos) ? csv_tags.size() : comma;
    array.push_back(csv_tags.substr(start, end - start));
    if (comma == std::string::npos) {
      break;
    }
    start = comma + 1;
  }
  return array;
}

std::string tags_from_json(const nlohmann::json& body) {
  if (!body.contains("tags") || !body.at("tags").is_array()) {
    return "";
  }
  std::string csv;
  for (const auto& tag : body.at("tags")) {
    if (!tag.is_string()) {
      continue;
    }
    if (!csv.empty()) {
      csv += ",";
    }
    csv += tag.get<std::string>();
  }
  return csv;
}

std::string get_string(const nlohmann::json& body, const std::string& key, const std::string& fallback = "") {
  if (body.contains(key) && body.at(key).is_string()) {
    return body.at(key).get<std::string>();
  }
  return fallback;
}

nlohmann::json repository_to_json(const RepositoryMetadata& repository) {
  return nlohmann::json{
      {"id", repository.repository_id},   {"name", repository.name},
      {"description", repository.description}, {"author", repository.author},
      {"organization", repository.organization}, {"tags", tags_to_json(repository.tags)},
      {"created_at", repository.created_at}, {"updated_at", repository.updated_at},
  };
}

nlohmann::json object_to_json(const EngineeringObject& object) {
  return nlohmann::json{
      {"id", object.object_id},           {"repository_id", object.repository_id},
      {"revision", object.revision},      {"object_type", domain::to_string(object.object_type)},
      {"name", object.name},              {"description", object.description},
      {"author", object.author},          {"tags", tags_to_json(object.tags)},
      {"content", object.content},        {"version", object.version},
      {"commit_id", object.commit_id},    {"created_at", object.created_at},
  };
}

nlohmann::json relationship_to_json(const Relationship& relationship) {
  return nlohmann::json{
      {"id", relationship.relationship_id},
      {"repository_id", relationship.repository_id},
      {"revision", relationship.revision},
      {"source_object_id", relationship.source_object_id},
      {"target_object_id", relationship.target_object_id},
      {"relationship_type", domain::to_string(relationship.relationship_type)},
      {"description", relationship.description},
      {"author", relationship.author},
      {"commit_id", relationship.commit_id},
      {"created_at", relationship.created_at},
  };
}

nlohmann::json commit_result_to_json(const CommitResult& result) {
  nlohmann::json object_results = nlohmann::json::array();
  for (const auto& mutation : result.object_results) {
    object_results.push_back(nlohmann::json{{"object_id", mutation.id}, {"revision", mutation.resulting_revision}});
  }
  nlohmann::json relationship_results = nlohmann::json::array();
  for (const auto& mutation : result.relationship_results) {
    relationship_results.push_back(
        nlohmann::json{{"relationship_id", mutation.id}, {"revision", mutation.resulting_revision}});
  }
  return nlohmann::json{
      {"commit_id", result.commit_id},     {"operation_id", result.operation_id},
      {"repository_id", result.repository_id}, {"object_results", object_results},
      {"relationship_results", relationship_results}, {"audit_event_id", result.audit_event_id},
      {"created_at", result.created_at},
  };
}

void respond_json(httplib::Response& response, int status, const nlohmann::json& body) {
  response.status = status;
  response.set_content(body.dump(), "application/json");
}

// ADR-0006 SS13: stable, machine-readable error categories, never
// leaking a filesystem path, credential, connection string, or raw
// exception text.
void respond_error(httplib::Response& response, int status, const std::string& category, const std::string& message) {
  respond_json(response, status, nlohmann::json{{"error", category}, {"message", message}});
}

void respond_unauthorized(httplib::Response& response) {
  response.set_header("WWW-Authenticate", "Bearer");
  respond_error(response, 401, "AUTHENTICATION_REQUIRED", "Authentication required.");
}

// The sole authentication gate for this service's API surface (ADR-0002
// SS3 / ADR-0006 SS12), installed once via `set_pre_routing_handler` --
// the same pattern EAM's own `server.cpp` already established, not
// duplicated per-route. `GET /health` is the one exempted path.
httplib::Server::HandlerResponse authenticate_request(const std::string& api_token, const httplib::Request& request,
                                                          httplib::Response& response) {
  if (request.path == "/health") {
    return httplib::Server::HandlerResponse::Unhandled;
  }
  if (!request.has_header("Authorization")) {
    respond_unauthorized(response);
    return httplib::Server::HandlerResponse::Handled;
  }
  const auto token = parse_bearer_token(request.get_header_value("Authorization"));
  if (!token.has_value() || !constant_time_equals(*token, api_token)) {
    respond_unauthorized(response);
    return httplib::Server::HandlerResponse::Handled;
  }
  return httplib::Server::HandlerResponse::Unhandled;
}

// ADR-0006 SS8/SS15's own guard pattern, mirroring EAM's `guard_vault`
// exactly: domain errors (whose messages this service authored itself,
// known-safe) pass their message through; anything unexpected is
// reported generically, NEVER via `ex.what()` -- a stricter rule than
// EAM's own current one, applying the WP-SRV-005 path-leak lesson from
// the very first line of this service rather than discovering it later.
template <typename Fn>
void guard(httplib::Response& response, Fn&& fn) {
  try {
    fn();
  } catch (const NotFoundError& ex) {
    respond_error(response, 404, "NOT_FOUND", ex.what());
  } catch (const ValidationError& ex) {
    respond_error(response, 422, "VALIDATION_FAILED", ex.what());
  } catch (const ConcurrencyConflictError& ex) {
    respond_error(response, 409, "CONCURRENCY_CONFLICT", ex.what());
  } catch (const IdempotencyConflictError& ex) {
    respond_error(response, 409, "IDEMPOTENCY_CONFLICT", ex.what());
  } catch (const pqxx::broken_connection& ex) {
    common::Logger::get().error("database connection error: {}", ex.what());
    respond_error(response, 503, "INTERNAL_FAILURE", "A database error occurred.");
  } catch (const std::exception& ex) {
    // Logged server-side only, at "error" level -- never sent to the
    // client (ADR-0006 SS13's leak-prevention rule). Server-side logs
    // are an operator-only surface, not a public API response.
    common::Logger::get().error("unexpected internal error: {}", ex.what());
    respond_error(response, 500, "INTERNAL_FAILURE", "An internal error occurred.");
  }
}

std::optional<ObjectMutation> parse_object_mutation(const nlohmann::json& item, bool is_update, std::string& error) {
  ObjectMutation mutation;
  mutation.is_update = is_update;
  mutation.object_id = get_string(item, "object_id");
  if (!common::is_uuid_like(mutation.object_id)) {
    error = "object mutation requires a valid object_id";
    return std::nullopt;
  }
  if (is_update) {
    if (!item.contains("expected_revision") || !item.at("expected_revision").is_number_integer()) {
      error = "object update mutation requires an integer expected_revision";
      return std::nullopt;
    }
    mutation.expected_revision = item.at("expected_revision").get<std::int64_t>();
  }
  if (!item.contains("object") || !item.at("object").is_object()) {
    error = "object mutation requires an 'object' body";
    return std::nullopt;
  }
  const auto& object = item.at("object");
  const auto type = domain::object_type_from_string(get_string(object, "object_type", "document"));
  if (!type.has_value()) {
    error = "object mutation has an unrecognized object_type";
    return std::nullopt;
  }
  mutation.object_type = *type;
  mutation.name = get_string(object, "name");
  if (mutation.name.empty()) {
    error = "object mutation requires a non-empty name";
    return std::nullopt;
  }
  mutation.description = get_string(object, "description");
  mutation.author = get_string(object, "author");
  mutation.tags = tags_from_json(object);
  mutation.content = get_string(object, "content");
  mutation.version = get_string(object, "version", "1.0.0");
  return mutation;
}

std::optional<RelationshipMutation> parse_relationship_mutation(const nlohmann::json& item, bool is_update,
                                                                    std::string& error) {
  RelationshipMutation mutation;
  mutation.is_update = is_update;
  mutation.relationship_id = get_string(item, "relationship_id");
  if (!common::is_uuid_like(mutation.relationship_id)) {
    error = "relationship mutation requires a valid relationship_id";
    return std::nullopt;
  }
  if (is_update) {
    if (!item.contains("expected_revision") || !item.at("expected_revision").is_number_integer()) {
      error = "relationship update mutation requires an integer expected_revision";
      return std::nullopt;
    }
    mutation.expected_revision = item.at("expected_revision").get<std::int64_t>();
  }
  if (!item.contains("relationship") || !item.at("relationship").is_object()) {
    error = "relationship mutation requires a 'relationship' body";
    return std::nullopt;
  }
  const auto& relationship = item.at("relationship");
  mutation.source_object_id = get_string(relationship, "source_object_id");
  mutation.target_object_id = get_string(relationship, "target_object_id");
  if (!common::is_uuid_like(mutation.source_object_id) || !common::is_uuid_like(mutation.target_object_id)) {
    error = "relationship mutation requires valid source_object_id and target_object_id";
    return std::nullopt;
  }
  const auto type = domain::relationship_type_from_string(get_string(relationship, "relationship_type", "references"));
  if (!type.has_value()) {
    error = "relationship mutation has an unrecognized relationship_type";
    return std::nullopt;
  }
  mutation.relationship_type = *type;
  mutation.description = get_string(relationship, "description");
  mutation.author = get_string(relationship, "author");
  return mutation;
}

std::optional<CommitRequest> parse_commit_request(const nlohmann::json& body, std::string& error) {
  CommitRequest request;
  request.operation_id = get_string(body, "operation_id");
  if (!common::is_uuid_like(request.operation_id)) {
    error = "operation_id must be a valid UUID";
    return std::nullopt;
  }
  if (!body.contains("mutations") || !body.at("mutations").is_array()) {
    error = "mutations must be an array";
    return std::nullopt;
  }
  for (const auto& item : body.at("mutations")) {
    const std::string kind = get_string(item, "kind");
    if (kind == "object_create" || kind == "object_update") {
      auto mutation = parse_object_mutation(item, kind == "object_update", error);
      if (!mutation.has_value()) {
        return std::nullopt;
      }
      request.object_mutations.push_back(*mutation);
    } else if (kind == "relationship_create" || kind == "relationship_update") {
      auto mutation = parse_relationship_mutation(item, kind == "relationship_update", error);
      if (!mutation.has_value()) {
        return std::nullopt;
      }
      request.relationship_mutations.push_back(*mutation);
    } else {
      error = "mutation kind must be one of object_create, object_update, relationship_create, relationship_update";
      return std::nullopt;
    }
  }
  return request;
}

std::optional<std::int64_t> parse_revision_param(const std::string& text) {
  if (text.empty()) {
    return std::nullopt;
  }
  try {
    std::size_t consumed = 0;
    const long long value = std::stoll(text, &consumed);
    if (consumed != text.size() || value < 0) {
      return std::nullopt;
    }
    return static_cast<std::int64_t>(value);
  } catch (const std::exception&) {
    return std::nullopt;
  }
}

void register_routes(httplib::Server& server, ServerRepositoryStore& store) {
  server.Get("/health", [](const httplib::Request&, httplib::Response& response) {
    respond_json(response, 200, nlohmann::json{{"status", "ok"}});
  });

  server.Post("/repositories", [&store](const httplib::Request& request, httplib::Response& response) {
    nlohmann::json body;
    try {
      body = nlohmann::json::parse(request.body);
    } catch (const nlohmann::json::exception&) {
      respond_error(response, 400, "VALIDATION_FAILED", "Request body is not valid JSON.");
      return;
    }

    RepositoryCreateRequest create_request;
    create_request.operation_id = get_string(body, "operation_id");
    if (!common::is_uuid_like(create_request.operation_id)) {
      respond_error(response, 400, "VALIDATION_FAILED", "operation_id must be a valid UUID.");
      return;
    }
    create_request.name = get_string(body, "name");
    if (create_request.name.empty()) {
      respond_error(response, 400, "VALIDATION_FAILED", "name is required.");
      return;
    }
    create_request.description = get_string(body, "description");
    create_request.author = get_string(body, "author");
    create_request.organization = get_string(body, "organization");
    create_request.tags = tags_from_json(body);

    guard(response, [&] {
      const auto created = store.create_repository(create_request);
      respond_json(response, 201, repository_to_json(created));
    });
  });

  server.Get(R"(/repositories/([^/]+))", [&store](const httplib::Request& request, httplib::Response& response) {
    const std::string repository_id = request.matches[1];
    guard(response, [&] {
      const auto repository = store.get_repository(repository_id);
      if (!repository.has_value()) {
        respond_error(response, 404, "NOT_FOUND", "No repository exists with that id.");
        return;
      }
      respond_json(response, 200, repository_to_json(*repository));
    });
  });

  server.Post(R"(/repositories/([^/]+)/commits)", [&store](const httplib::Request& request,
                                                               httplib::Response& response) {
    const std::string repository_id = request.matches[1];
    nlohmann::json body;
    try {
      body = nlohmann::json::parse(request.body);
    } catch (const nlohmann::json::exception&) {
      respond_error(response, 400, "VALIDATION_FAILED", "Request body is not valid JSON.");
      return;
    }
    std::string parse_error;
    auto commit_request = parse_commit_request(body, parse_error);
    if (!commit_request.has_value()) {
      respond_error(response, 400, "VALIDATION_FAILED", parse_error);
      return;
    }
    guard(response, [&] {
      const auto result = store.submit_commit(repository_id, *commit_request);
      respond_json(response, 201, commit_result_to_json(result));
    });
  });

  server.Get(R"(/repositories/([^/]+)/objects/([^/]+)/revisions/([^/]+))",
              [&store](const httplib::Request& request, httplib::Response& response) {
                const std::string repository_id = request.matches[1];
                const std::string object_id = request.matches[2];
                const auto revision = parse_revision_param(request.matches[3]);
                if (!revision.has_value()) {
                  respond_error(response, 400, "VALIDATION_FAILED", "revision must be a non-negative integer.");
                  return;
                }
                guard(response, [&] {
                  const auto object = store.get_object_revision(repository_id, object_id, *revision);
                  if (!object.has_value()) {
                    respond_error(response, 404, "NOT_FOUND", "No such object revision exists.");
                    return;
                  }
                  respond_json(response, 200, object_to_json(*object));
                });
              });

  server.Get(R"(/repositories/([^/]+)/objects/([^/]+))", [&store](const httplib::Request& request,
                                                                      httplib::Response& response) {
    const std::string repository_id = request.matches[1];
    const std::string object_id = request.matches[2];
    guard(response, [&] {
      const auto object = store.get_object(repository_id, object_id);
      if (!object.has_value()) {
        respond_error(response, 404, "NOT_FOUND", "No object exists with that id.");
        return;
      }
      respond_json(response, 200, object_to_json(*object));
    });
  });

  server.Get(R"(/repositories/([^/]+)/relationships/([^/]+)/revisions/([^/]+))",
              [&store](const httplib::Request& request, httplib::Response& response) {
                const std::string repository_id = request.matches[1];
                const std::string relationship_id = request.matches[2];
                const auto revision = parse_revision_param(request.matches[3]);
                if (!revision.has_value()) {
                  respond_error(response, 400, "VALIDATION_FAILED", "revision must be a non-negative integer.");
                  return;
                }
                guard(response, [&] {
                  const auto relationship = store.get_relationship_revision(repository_id, relationship_id, *revision);
                  if (!relationship.has_value()) {
                    respond_error(response, 404, "NOT_FOUND", "No such relationship revision exists.");
                    return;
                  }
                  respond_json(response, 200, relationship_to_json(*relationship));
                });
              });

  server.Get(R"(/repositories/([^/]+)/relationships/([^/]+))", [&store](const httplib::Request& request,
                                                                            httplib::Response& response) {
    const std::string repository_id = request.matches[1];
    const std::string relationship_id = request.matches[2];
    guard(response, [&] {
      const auto relationship = store.get_relationship(repository_id, relationship_id);
      if (!relationship.has_value()) {
        respond_error(response, 404, "NOT_FOUND", "No relationship exists with that id.");
        return;
      }
      respond_json(response, 200, relationship_to_json(*relationship));
    });
  });

  server.Get(R"(/repositories/([^/]+)/commits/([^/]+))", [&store](const httplib::Request& request,
                                                                      httplib::Response& response) {
    const std::string repository_id = request.matches[1];
    const std::string commit_id = request.matches[2];
    guard(response, [&] {
      const auto commit = store.get_commit(repository_id, commit_id);
      if (!commit.has_value()) {
        respond_error(response, 404, "NOT_FOUND", "No commit exists with that id.");
        return;
      }
      respond_json(response, 200, commit_result_to_json(*commit));
    });
  });
}

}  // namespace

ApiServer::ApiServer(const common::ServerConfig& config, std::string api_token, persistence::ServerRepositoryStore& store)
    : config_(config), api_token_(std::move(api_token)), store_(store), server_(std::make_unique<httplib::Server>()) {
  if (api_token_.empty()) {
    // WP-SRV-011, mirroring EAM's own ApiServer (WP-SRV-003): an empty
    // token must never silently mean "auth disabled."
    throw std::invalid_argument("ApiServer: api_token must not be empty");
  }
  server_->set_pre_routing_handler([this](const httplib::Request& request, httplib::Response& response) {
    return authenticate_request(api_token_, request, response);
  });
  register_routes(*server_, store_);
}

ApiServer::~ApiServer() {
  stop();
}

bool ApiServer::start() {
  if (running_) {
    return true;
  }
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

}  // namespace oep::server_repository::api
