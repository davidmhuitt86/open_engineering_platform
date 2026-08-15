#include "oep/repository/json_value.hpp"

#include <cctype>
#include <charconv>
#include <sstream>

namespace oep::repository::json {

Value Value::null() {
    return Value();
}

Value Value::boolean(bool value) {
    Value v;
    v.type_ = Type::Bool;
    v.data_ = value;
    return v;
}

Value Value::number(double value) {
    Value v;
    v.type_ = Type::Number;
    v.data_ = value;
    return v;
}

Value Value::string(std::string value) {
    Value v;
    v.type_ = Type::String;
    v.data_ = std::move(value);
    return v;
}

Value Value::array(Array value) {
    Value v;
    v.type_ = Type::Array;
    v.data_ = std::move(value);
    return v;
}

Value Value::object(Object value) {
    Value v;
    v.type_ = Type::Object;
    v.data_ = std::move(value);
    return v;
}

bool Value::as_bool() const {
    return std::get<bool>(data_);
}

double Value::as_number() const {
    return std::get<double>(data_);
}

const std::string& Value::as_string() const {
    return std::get<std::string>(data_);
}

const Array& Value::as_array() const {
    return std::get<Array>(data_);
}

const Object& Value::as_object() const {
    return std::get<Object>(data_);
}

const Value* Value::find(const std::string& key) const {
    if (type_ != Type::Object) {
        return nullptr;
    }
    for (const auto& [entry_key, entry_value] : std::get<Object>(data_)) {
        if (entry_key == key) {
            return &entry_value;
        }
    }
    return nullptr;
}

namespace {

// Minimal recursive-descent JSON parser covering the subset of JSON
// used by repository metadata: objects, arrays, strings, numbers,
// booleans, and null.
class Parser {
public:
    explicit Parser(const std::string& text) : text_(text) {}

    ParseResult run() {
        skip_whitespace();
        Value value;
        if (!parse_value(value)) {
            return {false, error_, Value()};
        }
        skip_whitespace();
        if (position_ != text_.size()) {
            return {false, "unexpected trailing content at offset " + std::to_string(position_), Value()};
        }
        return {true, "", value};
    }

private:
    const std::string& text_;
    std::size_t position_ = 0;
    std::string error_;

    bool at_end() const { return position_ >= text_.size(); }
    char peek() const { return text_[position_]; }

    void skip_whitespace() {
        while (!at_end() && std::isspace(static_cast<unsigned char>(peek()))) {
            ++position_;
        }
    }

    bool fail(const std::string& message) {
        error_ = message + " at offset " + std::to_string(position_);
        return false;
    }

    bool expect(char expected) {
        if (at_end() || peek() != expected) {
            return fail(std::string("expected '") + expected + "'");
        }
        ++position_;
        return true;
    }

    bool parse_value(Value& out) {
        if (at_end()) {
            return fail("unexpected end of input");
        }
        switch (peek()) {
            case '{': return parse_object(out);
            case '[': return parse_array(out);
            case '"': {
                std::string s;
                if (!parse_string(s)) return false;
                out = Value::string(std::move(s));
                return true;
            }
            case 't':
            case 'f':
                return parse_bool(out);
            case 'n':
                return parse_null(out);
            default:
                return parse_number(out);
        }
    }

    bool parse_object(Value& out) {
        Object object;
        if (!expect('{')) return false;
        skip_whitespace();
        if (!at_end() && peek() == '}') {
            ++position_;
            out = Value::object(std::move(object));
            return true;
        }
        while (true) {
            skip_whitespace();
            if (at_end() || peek() != '"') {
                return fail("expected string key");
            }
            std::string key;
            if (!parse_string(key)) return false;
            skip_whitespace();
            if (!expect(':')) return false;
            skip_whitespace();
            Value value;
            if (!parse_value(value)) return false;
            object.emplace_back(std::move(key), std::move(value));
            skip_whitespace();
            if (at_end()) return fail("unterminated object");
            if (peek() == ',') {
                ++position_;
                continue;
            }
            if (peek() == '}') {
                ++position_;
                break;
            }
            return fail("expected ',' or '}'");
        }
        out = Value::object(std::move(object));
        return true;
    }

    bool parse_array(Value& out) {
        Array array;
        if (!expect('[')) return false;
        skip_whitespace();
        if (!at_end() && peek() == ']') {
            ++position_;
            out = Value::array(std::move(array));
            return true;
        }
        while (true) {
            skip_whitespace();
            Value value;
            if (!parse_value(value)) return false;
            array.push_back(std::move(value));
            skip_whitespace();
            if (at_end()) return fail("unterminated array");
            if (peek() == ',') {
                ++position_;
                continue;
            }
            if (peek() == ']') {
                ++position_;
                break;
            }
            return fail("expected ',' or ']'");
        }
        out = Value::array(std::move(array));
        return true;
    }

    bool parse_string(std::string& out) {
        if (!expect('"')) return false;
        std::string result;
        while (true) {
            if (at_end()) return fail("unterminated string");
            char c = peek();
            if (c == '"') {
                ++position_;
                break;
            }
            if (c == '\\') {
                ++position_;
                if (at_end()) return fail("unterminated escape sequence");
                char escaped = peek();
                ++position_;
                switch (escaped) {
                    case '"': result += '"'; break;
                    case '\\': result += '\\'; break;
                    case '/': result += '/'; break;
                    case 'b': result += '\b'; break;
                    case 'f': result += '\f'; break;
                    case 'n': result += '\n'; break;
                    case 'r': result += '\r'; break;
                    case 't': result += '\t'; break;
                    case 'u': {
                        if (position_ + 4 > text_.size()) return fail("invalid unicode escape");
                        unsigned int codepoint = 0;
                        for (int i = 0; i < 4; ++i) {
                            char hex = text_[position_ + i];
                            codepoint <<= 4;
                            if (hex >= '0' && hex <= '9') codepoint |= static_cast<unsigned int>(hex - '0');
                            else if (hex >= 'a' && hex <= 'f') codepoint |= static_cast<unsigned int>(hex - 'a' + 10);
                            else if (hex >= 'A' && hex <= 'F') codepoint |= static_cast<unsigned int>(hex - 'A' + 10);
                            else return fail("invalid unicode escape");
                        }
                        position_ += 4;
                        // Encode as UTF-8 (basic multilingual plane only).
                        if (codepoint <= 0x7F) {
                            result += static_cast<char>(codepoint);
                        } else if (codepoint <= 0x7FF) {
                            result += static_cast<char>(0xC0 | (codepoint >> 6));
                            result += static_cast<char>(0x80 | (codepoint & 0x3F));
                        } else {
                            result += static_cast<char>(0xE0 | (codepoint >> 12));
                            result += static_cast<char>(0x80 | ((codepoint >> 6) & 0x3F));
                            result += static_cast<char>(0x80 | (codepoint & 0x3F));
                        }
                        break;
                    }
                    default:
                        return fail("invalid escape sequence");
                }
                continue;
            }
            result += c;
            ++position_;
        }
        out = std::move(result);
        return true;
    }

    bool parse_bool(Value& out) {
        if (text_.compare(position_, 4, "true") == 0) {
            position_ += 4;
            out = Value::boolean(true);
            return true;
        }
        if (text_.compare(position_, 5, "false") == 0) {
            position_ += 5;
            out = Value::boolean(false);
            return true;
        }
        return fail("invalid literal");
    }

    bool parse_null(Value& out) {
        if (text_.compare(position_, 4, "null") == 0) {
            position_ += 4;
            out = Value::null();
            return true;
        }
        return fail("invalid literal");
    }

    bool parse_number(Value& out) {
        std::size_t start = position_;
        if (!at_end() && peek() == '-') ++position_;
        while (!at_end() && (std::isdigit(static_cast<unsigned char>(peek())) || peek() == '.' ||
                              peek() == 'e' || peek() == 'E' || peek() == '+' || peek() == '-')) {
            ++position_;
        }
        if (position_ == start) return fail("invalid number");
        double value = 0.0;
        auto [ptr, ec] = std::from_chars(text_.data() + start, text_.data() + position_, value);
        (void)ptr;
        if (ec != std::errc{}) return fail("invalid number");
        out = Value::number(value);
        return true;
    }
};

void write_escaped_string(std::ostringstream& stream, const std::string& value) {
    stream << '"';
    for (char c : value) {
        switch (c) {
            case '"': stream << "\\\""; break;
            case '\\': stream << "\\\\"; break;
            case '\n': stream << "\\n"; break;
            case '\r': stream << "\\r"; break;
            case '\t': stream << "\\t"; break;
            default: stream << c; break;
        }
    }
    stream << '"';
}

void write_value(std::ostringstream& stream, const Value& value, int indent) {
    const std::string padding(static_cast<std::size_t>(indent) * 2, ' ');
    const std::string inner_padding(static_cast<std::size_t>(indent + 1) * 2, ' ');

    switch (value.type()) {
        case Value::Type::Null:
            stream << "null";
            break;
        case Value::Type::String:
            write_escaped_string(stream, value.as_string());
            break;
        case Value::Type::Array: {
            const Array& array = value.as_array();
            if (array.empty()) {
                stream << "[]";
                break;
            }
            stream << "[\n";
            for (std::size_t i = 0; i < array.size(); ++i) {
                stream << inner_padding;
                write_value(stream, array[i], indent + 1);
                if (i + 1 != array.size()) stream << ',';
                stream << '\n';
            }
            stream << padding << ']';
            break;
        }
        case Value::Type::Object: {
            const Object& object = value.as_object();
            if (object.empty()) {
                stream << "{}";
                break;
            }
            stream << "{\n";
            for (std::size_t i = 0; i < object.size(); ++i) {
                stream << inner_padding;
                write_escaped_string(stream, object[i].first);
                stream << ": ";
                write_value(stream, object[i].second, indent + 1);
                if (i + 1 != object.size()) stream << ',';
                stream << '\n';
            }
            stream << padding << '}';
            break;
        }
        case Value::Type::Bool:
            stream << (value.as_bool() ? "true" : "false");
            break;
        case Value::Type::Number:
            stream << value.as_number();
            break;
    }
}

} // namespace

ParseResult parse(const std::string& text) {
    Parser parser(text);
    return parser.run();
}

std::string serialize(const Value& value) {
    std::ostringstream stream;
    write_value(stream, value, 0);
    stream << '\n';
    return stream.str();
}

} // namespace oep::repository::json
