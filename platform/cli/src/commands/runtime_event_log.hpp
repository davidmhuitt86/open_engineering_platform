#pragma once

#include "oep/runtime/repository_events.hpp"

namespace oep::cli::commands {

// A process-wide Repository Events log (WP-REP-006), shared by every CLI
// command in this process. This mirrors, at the CLI layer, the single
// EventBus a Studio or the C API's oep_runtime_impl holds per session:
// each `oep` invocation is its own short-lived process, so this bus is
// naturally scoped to a single command run — but within one process
// (as CLI tests do, invoking several Command::execute() calls back to
// back against the same repository) it lets a mutation published by one
// command (`oep object create`, `oep relationship create`, `oep package
// install`, ...) be observed by a later `oep runtime events` query, just
// as it would be observed by a longer-lived host process embedding the
// Runtime directly. See oep::runtime::EventBus's own documentation for
// the underlying single-process, in-memory, no-persistence contract this
// inherits.
oep::runtime::EventBus& global_event_bus();

} // namespace oep::cli::commands
