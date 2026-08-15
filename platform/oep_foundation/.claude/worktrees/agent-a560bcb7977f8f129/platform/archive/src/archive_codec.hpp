#pragma once

#include "oep/archive/export_manifest.hpp"
#include "oep/archive/template_manifest.hpp"
#include "oep/packages/package_manifest.hpp"
#include "oep/repository/audit_event.hpp"
#include "oep/repository/engineering_object.hpp"
#include "oep/repository/json_value.hpp"
#include "oep/repository/metadata.hpp"
#include "oep/repository/relationship.hpp"

// Internal (not part of the public API) JSON marshaling for the
// combined export archive document. The archive format is owned by
// Exchange and is intentionally independent of each store's own
// on-disk file schema — this is not a duplication of those schemas,
// it is the archive's own serialization concern.
namespace oep::archive::archive_codec {

namespace json = oep::repository::json;

json::Value to_json(const ExportManifest& manifest);
ExportManifest export_manifest_from_json(const json::Value& value);

json::Value to_json(const oep::repository::RepositoryMetadata& metadata);
oep::repository::RepositoryMetadata metadata_from_json(const json::Value& value);

json::Value to_json(const oep::repository::EngineeringObject& object);
oep::repository::EngineeringObject object_from_json(const json::Value& value, bool& ok);

json::Value to_json(const oep::repository::Relationship& relationship);
oep::repository::Relationship relationship_from_json(const json::Value& value, bool& ok);

json::Value to_json(const oep::repository::AuditEvent& event);
oep::repository::AuditEvent audit_event_from_json(const json::Value& value, bool& ok);

json::Value to_json(const oep::packages::PackageManifest& manifest);
oep::packages::PackageManifest package_manifest_from_json(const json::Value& value, bool& ok);

json::Value to_json(const TemplateManifest& manifest);
TemplateManifest template_manifest_from_json(const json::Value& value);

} // namespace oep::archive::archive_codec
