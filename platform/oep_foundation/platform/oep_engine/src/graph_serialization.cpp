#include "oep/engine/graph_serialization.hpp"

#include "oep/repository/json_value.hpp"

#include <algorithm>

namespace oep::engine {

namespace {
namespace json = oep::repository::json;

std::string escape_xml(const std::string& text) {
    std::string escaped;
    escaped.reserve(text.size());
    for (const char c : text) {
        switch (c) {
            case '&': escaped += "&amp;"; break;
            case '<': escaped += "&lt;"; break;
            case '>': escaped += "&gt;"; break;
            case '"': escaped += "&quot;"; break;
            default: escaped += c;
        }
    }
    return escaped;
}
} // namespace

std::string to_json(const KnowledgeGraph& graph) {
    std::vector<const KnowledgeGraphNode*> nodes = graph.all_nodes(); // already sorted by object_id
    std::vector<KnowledgeGraphEdge> edges(graph.all_edges().begin(), graph.all_edges().end());
    std::sort(edges.begin(), edges.end(),
              [](const KnowledgeGraphEdge& a, const KnowledgeGraphEdge& b) { return a.relationship_id < b.relationship_id; });

    json::Array object_array;
    for (const KnowledgeGraphNode* node : nodes) {
        json::Object fields;
        fields.emplace_back("objectId", json::Value::string(node->object_id));
        fields.emplace_back("objectType", json::Value::string(oep::repository::to_string(node->object_type)));
        fields.emplace_back("name", json::Value::string(node->name));
        json::Array domains;
        for (const std::string& domain : node->domains) {
            domains.push_back(json::Value::string(domain));
        }
        fields.emplace_back("domains", json::Value::array(std::move(domains)));
        fields.emplace_back("packageId", json::Value::string(node->package_id));
        fields.emplace_back("publisherId", json::Value::string(node->publisher_id));
        object_array.push_back(json::Value::object(std::move(fields)));
    }

    json::Array relationship_array;
    for (const KnowledgeGraphEdge& edge : edges) {
        json::Object fields;
        fields.emplace_back("relationshipId", json::Value::string(edge.relationship_id));
        fields.emplace_back("sourceObjectId", json::Value::string(edge.source_object_id));
        fields.emplace_back("targetObjectId", json::Value::string(edge.target_object_id));
        fields.emplace_back("relationshipType", json::Value::string(oep::repository::to_string(edge.relationship_type)));
        relationship_array.push_back(json::Value::object(std::move(fields)));
    }

    json::Object root;
    root.emplace_back("objects", json::Value::array(std::move(object_array)));
    root.emplace_back("relationships", json::Value::array(std::move(relationship_array)));
    return json::serialize(json::Value::object(std::move(root)));
}

std::string to_graphml_placeholder(const KnowledgeGraph& graph) {
    std::vector<const KnowledgeGraphNode*> nodes = graph.all_nodes();
    std::vector<KnowledgeGraphEdge> edges(graph.all_edges().begin(), graph.all_edges().end());
    std::sort(edges.begin(), edges.end(),
              [](const KnowledgeGraphEdge& a, const KnowledgeGraphEdge& b) { return a.relationship_id < b.relationship_id; });

    std::string out = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    out += "<!-- WP-EKE-002 placeholder GraphML export: node/edge identity only, no attribute schema. -->\n";
    out += "<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\">\n";
    out += "  <graph id=\"knowledge-graph\" edgedefault=\"directed\">\n";
    for (const KnowledgeGraphNode* node : nodes) {
        out += "    <node id=\"" + escape_xml(node->object_id) + "\"/>\n";
    }
    for (const KnowledgeGraphEdge& edge : edges) {
        out += "    <edge id=\"" + escape_xml(edge.relationship_id) + "\" source=\"" + escape_xml(edge.source_object_id) +
               "\" target=\"" + escape_xml(edge.target_object_id) + "\"/>\n";
    }
    out += "  </graph>\n";
    out += "</graphml>\n";
    return out;
}

} // namespace oep::engine
