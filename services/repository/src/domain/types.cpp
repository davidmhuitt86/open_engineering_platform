#include "oep/server_repository/domain/types.hpp"

namespace oep::server_repository::domain {

std::string to_string(ObjectType type) {
  switch (type) {
    case ObjectType::Document:
      return "document";
    case ObjectType::Diagram:
      return "diagram";
    case ObjectType::Component:
      return "component";
    case ObjectType::Procedure:
      return "procedure";
    case ObjectType::Project:
      return "project";
    case ObjectType::Image:
      return "image";
  }
  return "document";
}

std::optional<ObjectType> object_type_from_string(const std::string& value) {
  if (value == "document") return ObjectType::Document;
  if (value == "diagram") return ObjectType::Diagram;
  if (value == "component") return ObjectType::Component;
  if (value == "procedure") return ObjectType::Procedure;
  if (value == "project") return ObjectType::Project;
  if (value == "image") return ObjectType::Image;
  return std::nullopt;
}

std::string to_string(RelationshipType type) {
  switch (type) {
    case RelationshipType::References:
      return "references";
    case RelationshipType::Contains:
      return "contains";
    case RelationshipType::DependsOn:
      return "depends_on";
    case RelationshipType::ConnectedTo:
      return "connected_to";
    case RelationshipType::Documents:
      return "documents";
    case RelationshipType::Implements:
      return "implements";
  }
  return "references";
}

std::optional<RelationshipType> relationship_type_from_string(const std::string& value) {
  if (value == "references") return RelationshipType::References;
  if (value == "contains") return RelationshipType::Contains;
  if (value == "depends_on") return RelationshipType::DependsOn;
  if (value == "connected_to") return RelationshipType::ConnectedTo;
  if (value == "documents") return RelationshipType::Documents;
  if (value == "implements") return RelationshipType::Implements;
  return std::nullopt;
}

}  // namespace oep::server_repository::domain
