#pragma once

#include <string>
#include <utility>
#include <variant>
#include <vector>

namespace oep::repository::json {

class Value;

using Array = std::vector<Value>;
using Object = std::vector<std::pair<std::string, Value>>; // preserves insertion order

// A minimal JSON value supporting the subset of JSON needed by
// Foundation's file-backed stores: null, bool, number, string, array,
// object. Not a general-purpose JSON library. Public so other platform
// modules (e.g. platform/packages) can reuse it instead of
// implementing their own parser.
class Value {
public:
    enum class Type { Null, Bool, Number, String, Array, Object };

    Value() : type_(Type::Null), data_(std::monostate{}) {}
    static Value null();
    static Value boolean(bool value);
    static Value number(double value);
    static Value string(std::string value);
    static Value array(Array value);
    static Value object(Object value);

    Type type() const { return type_; }
    bool is_bool() const { return type_ == Type::Bool; }
    bool is_string() const { return type_ == Type::String; }
    bool is_array() const { return type_ == Type::Array; }
    bool is_object() const { return type_ == Type::Object; }

    bool as_bool() const;
    double as_number() const;
    const std::string& as_string() const;
    const Array& as_array() const;
    const Object& as_object() const;

    // Returns nullptr if `key` is not present or this is not an object.
    const Value* find(const std::string& key) const;

private:
    Type type_;
    std::variant<std::monostate, bool, double, std::string, Array, Object> data_;
};

struct ParseResult {
    bool success = false;
    std::string error;
    Value value;
};

ParseResult parse(const std::string& text);
std::string serialize(const Value& value);

} // namespace oep::repository::json
