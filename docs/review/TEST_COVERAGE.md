# TEST_COVERAGE.md

## Totals

**62 registered CTest suites** in `oep_foundation` (verified: `grep -h "add_test(" $(find tests -iname CMakeLists.txt) | wc -l` → 62, exactly matching 1 test executable per `.cpp` file — no discrepancy). **56 Dart test files** in `oep_studio/test/`, of which 11 use `testWidgets` (real widget-pumping) and ~45 are plain unit tests.

## By category (C++)

| Module | Files | Classification |
|---|---|---|
| `tests/repository/` | 6 | Unit |
| `tests/search/` | 1 | Unit |
| `tests/validation/` | 1 | Unit |
| `tests/installer/` | 11 | Unit (crypto primitives, parsing, resolution logic) |
| `tests/packages/` | 1 | Unit/Integration (filesystem-backed) |
| `tests/archive/` | 3 | Integration |
| `tests/runtime/` | 8 | Integration (4 of 8 files literally named `*_integration_tests`) |
| `tests/api/` | 1 (4,063 lines) | Integration (single large file exercising the full public C API surface) |
| `tests/cli/` | 21 | Integration (one file per CLI subcommand, full behavioral + error-path coverage) |
| `tests/engine/` | 9 | Integration + 1 genuine End-to-End |

## Unit Tests
Solid at the base layer: `repository`, `search`, `validation`, `installer` are thoroughly unit-tested, including hand-rolled crypto (sha256/sha512/ed25519) verified against NIST test vectors. Weaker at the engine layer: several `oep_engine` internals (`QueryPlanner`, `QueryExecutor`, `QueryCache`, `graph_algorithms`, `graph_serialization`, `graph_statistics`, `graph_validator`, `traversal_engine`, `relationship_engine`, `rule_context`/`rule_evaluator`/`rule_registry`, `knowledge_session_manager`, `object_loader`) have **no dedicated unit test file** — grepping the whole test tree for `QueryPlanner`/`QueryExecutor`/`QueryCache` by name returns zero matches anywhere, meaning these classes are only exercised transitively through their owning engine's integration tests, never verified in isolation. `object_store.hpp`/`relationship_store.hpp` in `repository` are similarly never unit-tested standalone despite being referenced everywhere.

**`AnalysisEngine` has no dedicated test file at all** — the one clear gap among the "major, named, spec-required" engine classes. It is exercised only indirectly (CLI tests, the end-to-end test, EIP tests).

## Integration Tests
Strong: `tests/runtime/` explicitly names 4 of its 8 files as integration tests (dependency resolution, merge engine, package lifecycle, trust); `tests/cli/` gives every one of the 28 CLI command groups behavioral coverage including error paths; `tests/api/` is a single large (4,063-line) integration test exercising the public C boundary end-to-end.

## End-to-End Tests
**Exactly one file, `tests/engine/end_to_end_workflow_tests.cpp` (366 lines, 2 tests)**: the full acquire→install→graph-build→query→validate→analyze→reason→recommend→"Studio visualization data" pipeline, plus a determinism re-run test. This is genuinely the only test in the codebase spanning that full breadth — appropriately built, but a single point of coverage for the platform's single most complex workflow claim.

## Performance Tests
**None exist.** No benchmark framework (Google Benchmark or similar) is linked anywhere; no `BENCHMARK(...)`/`perf_test` pattern found. The only timing data anywhere in the test suite is informational `std::chrono` output printed inside the end-to-end correctness test — never asserted against a threshold, never averaged across repeated runs. Every "31.8595 ms" figure quoted in this session's documentation traces back to a single, unrepeated measurement inside a correctness test, not a real performance suite.

## Regression Tests
The full 62-suite CTest run itself functions as the platform's regression suite (re-run before every work package's freeze claim, verified in this session). No suite is marked skipped/disabled — confirmed via grep for `GTEST_SKIP`/`DISABLED_`/`xfail`/`TODO`, zero matches anywhere in the C++ test tree.

## Studio (Dart) tests
56 files total; only 11 are real widget-interaction tests. The new `engineering_intelligence_page_test.dart` is **explicitly documented by its own doc comment as smoke-test-only**: 3 tests covering (1) the "No Repository Open" gate renders, (2) the page registers correctly in `StudioRegistry` with 8 capabilities, (3) the `/engineering-intelligence` route exists. **No test exercises real interaction with live engine data through any of the 8 new pages** — the file itself states this is intentionally deferred to manual verification. This is the single largest gap in the newest work delivered this session: the pages exist and the plumbing is correct, but "does clicking through the Knowledge Graph Explorer with real data actually work" is unverified by automation.

## Missing coverage — summary
1. `AnalysisEngine` — no dedicated unit test.
2. `QueryPlanner`/`QueryExecutor`/`QueryCache` and most other `oep_engine` internal helper classes — no dedicated unit tests, transitive coverage only.
3. `ObjectStore`/`RelationshipStore` in `repository` — no dedicated unit test despite being the most-referenced classes in the codebase.
4. No performance/benchmark suite anywhere.
5. Studio's 8 new Engineering Intelligence pages — no automated interaction tests, smoke/registration only.
6. Single end-to-end test — sufficient to prove the pipeline works once, but a single test is a thin safety net for a claim as broad as "the full platform pipeline is verified."

## Weak areas (ranked)
1. **Studio interaction depth** — most consequential gap given it's the newest, least-manually-verified surface.
2. **Performance testing entirely absent** — a real risk given several documented O(V·(V+E)) and full-scan code paths exist by design; there is currently no automated way to notice if those paths regress at scale.
3. **`AnalysisEngine` and internal query/graph helper classes untested in isolation** — currently masked by good transitive coverage, but any bug localized to these classes specifically would surface as a confusing failure in an unrelated integration test rather than a clear, localized one.
