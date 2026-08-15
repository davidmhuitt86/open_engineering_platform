#include "oep/installer/repository_change_set.hpp"

namespace oep::installer {

std::string to_string(ChangeKind kind) {
    switch (kind) {
        case ChangeKind::Create: return "Create";
        case ChangeKind::Update: return "Update";
        case ChangeKind::Delete: return "Delete";
    }
    return "Unknown";
}

} // namespace oep::installer
