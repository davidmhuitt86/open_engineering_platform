#pragma once

#include "oep/runtime/repository_events.hpp"

namespace oep::runtime {

class FoundationRuntime;

// Dependency injection for RuntimeService (WP-REP-006). RuntimeContext
// owns nothing and implements nothing: it is a small aggregate of
// references to the collaborators RuntimeService sequences calls
// against, handed to RuntimeService's constructor instead of
// RuntimeService reaching out and constructing (or locating) its own
// dependencies. This keeps RuntimeService testable in isolation and
// keeps the wiring of "which Runtime / which EventBus" a decision made
// once, by the owner (oep_runtime_impl in the Public C API today),
// rather than scattered across RuntimeService's methods.
//
// RuntimeContext does not, and must not, hold business logic — it is
// purely a reference bundle. Both references must outlive every
// RuntimeContext (and RuntimeService) that holds them; this mirrors
// FoundationRuntime's own existing non-owning `const X*` service
// registry accessors.
class RuntimeContext {
public:
    RuntimeContext(FoundationRuntime& runtime, EventBus& events) : runtime_(runtime), events_(events) {}

    FoundationRuntime& runtime() const { return runtime_; }
    EventBus& events() const { return events_; }

private:
    FoundationRuntime& runtime_;
    EventBus& events_;
};

} // namespace oep::runtime
