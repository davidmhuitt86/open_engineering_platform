# OEP CLI Usage

## Purpose

`oep` is the primary developer interface for the Open Engineering Platform Foundation. It is a thin presentation layer: every command that touches a repository does so exclusively through `FoundationRuntime`, and never constructs Repository, Search, Validation, or Package services directly. Business logic lives in Foundation; the CLI only presents it.

---

## Build Prerequisites

- A C++23 compiler (verified with MSVC 19.51 / Visual Studio Build Tools 18)
- CMake 3.25+
- A CMake generator with a working build tool (this project has been built and tested with Ninja)

---

## Build Instructions

From the repository root:

```bash
cmake -S . -B build -G Ninja
cmake --build build
```

The `oep` executable is produced at `build/platform/cli/oep` (`oep.exe` on Windows).

To run the test suite:

```bash
cd build
ctest --output-on-failure
```

---

## Running the CLI

```bash
oep --help
oep <command> [arguments]
```

Running `oep` with no arguments, or with `--help`/`-h`, shows the help listing.

---

## Commands

| Command | Syntax | Description |
|---|---|---|
| version | `oep version` | Display the OEP CLI version |
| init | `oep init <repository-name>` | Create a new OEP repository |
| open | `oep open <repository>` | Open a repository through the Foundation Runtime |
| validate | `oep validate [repository]` | Validate repository integrity and report health |
| packages | `oep packages [repository]` | List discovered packages and their state |
| status | `oep status [repository]` | Display Foundation Runtime status and repository information |
| object | `oep object <create\|list\|show\|delete> [arguments] [--repository <path>]` | Create, list, show, and delete Engineering Objects |
| relationship | `oep relationship <create\|list\|show\|delete> [arguments] [--repository <path>]` | Create, list, show, and delete Relationships |
| search | `oep search [objects\|relationships] <query> [--type <type>] [--author <author>] [--tag <tag>] [--repository <path>]` | Search Engineering Objects and Relationships |
| graph | `oep graph <neighbors\|traverse\|path> <object-id> [<target-object-id>] [--algorithm bfs\|dfs] [--repository <path>]` | Explore Engineering Objects through their Relationships |
| export | `oep export <output-file> [--include-packages] [--repository <path>]` | Export the repository to a single deterministic archive |
| import | `oep import <archive-file> [--destination <path>] [--overwrite]` | Reconstruct a repository from an exported archive |
| template | `oep template <create\|list\|instantiate> [arguments] [--templates-dir <path>]` | Create, list, and instantiate Repository Templates |
| batch | `oep batch <create\|delete\|validate> <input-file> [--repository <path>]` | Execute or validate a batch of object/relationship operations from a JSON file |
| help | `oep help` | Display available commands |

`validate`, `packages`, and `status` default to the current working directory when no repository path is given. `open` and `init` require an explicit argument. `object` and `relationship` subcommands default to the current working directory unless `--repository <path>` is given — a flag rather than a positional argument, since their `show`/`delete` subcommands already use the one positional slot for the object/relationship ID.

### Object commands

| Subcommand | Syntax | Description |
|---|---|---|
| create | `oep object create --type <type> --name <name> [--description <text>] [--author <name>] [--tags a,b,c] [--repository <path>]` | Create a new Engineering Object |
| list | `oep object list [--repository <path>]` | List every object (Object ID, Type, Name, Version), sorted by Object ID |
| show | `oep object show <object-id> [--repository <path>]` | Display every field of one object |
| delete | `oep object delete <object-id> [--repository <path>]` | Delete an object (automatically records an `ObjectDeleted` Audit Event) |

`--type` must be one of: `Document`, `Diagram`, `Component`, `Procedure`, `Project`, `Image`. Object IDs are generated automatically by `create` — they are never chosen by the caller.

### Relationship commands

| Subcommand | Syntax | Description |
|---|---|---|
| create | `oep relationship create --source <object-id> --target <object-id> --type <type> [--author <name>] [--description <text>] [--repository <path>]` | Create a new Relationship between two existing objects |
| list | `oep relationship list [--repository <path>]` | List every relationship (Relationship ID, Type, Source, Target), sorted by Relationship ID |
| show | `oep relationship show <relationship-id> [--repository <path>]` | Display every field of one relationship |
| delete | `oep relationship delete <relationship-id> [--repository <path>]` | Delete a relationship (automatically records a `RelationshipDeleted` Audit Event) |

`--type` must be one of: `References`, `Contains`, `DependsOn`, `ConnectedTo`, `Documents`, `Implements`. Relationship IDs are generated automatically. `create` enforces (via the existing `RelationshipStore`, not CLI-side logic) that both `--source` and `--target` reference objects that already exist, and that they differ from each other.

### Search commands

| Form | Syntax | Description |
|---|---|---|
| combined | `oep search <query> [filters]` | Search both objects and relationships |
| objects | `oep search objects <query> [filters]` | Search objects only |
| relationships | `oep search relationships <query> [filters]` | Search relationships only |

Available filters (applied by the CLI *after* the Search Engine returns results — they narrow the result set but never reorder it):

| Filter | Applies to | Description |
|---|---|---|
| `--type <type>` | objects and relationships | Object type or relationship type, matched exactly |
| `--author <author>` | objects and relationships | Exact author match |
| `--tag <tag>` | objects only | Exact tag match; has no effect on relationship search, since Relationships have no tags |

Object results show Object ID, Object Type, Name, Match Score, and Match Location. Relationship results show Relationship ID, Relationship Type, Source Object ID, Target Object ID, Match Score, and Match Location. Search is case-insensitive and partial-match capable (inherited from `SearchEngine`); the CLI never re-ranks or re-sorts what the Search Engine returns.

### Graph commands

| Subcommand | Syntax | Description |
|---|---|---|
| neighbors | `oep graph neighbors <object-id> [--repository <path>]` | List every object directly connected to `<object-id>` |
| traverse | `oep graph traverse <object-id> [--algorithm bfs\|dfs] [--repository <path>]` | Visit every object reachable from `<object-id>` |
| path | `oep graph path <source-object-id> <target-object-id> [--repository <path>]` | Report whether a path exists between two objects |

`traverse` defaults to Breadth-First Search (BFS); pass `--algorithm dfs` for Depth-First Search. Both algorithms are implemented entirely by `GraphEngine` (see `platform/repository`) — the CLI only formats what it returns. `neighbors` reports Neighbor Object ID/Type/Name and the connecting Relationship Type. `traverse` reports each visited object in traversal order, numbered, with its Object ID/Type/Name. `path` reports only `Path Found` or `No Path Found` — there is no shortest-path computation.

### Export and import commands

| Command | Syntax | Description |
|---|---|---|
| export | `oep export <output-file> [--include-packages] [--repository <path>]` | Export the currently open repository to a single archive file |
| import | `oep import <archive-file> [--destination <path>] [--overwrite]` | Reconstruct a repository from an archive |

**Export** produces a single deterministic JSON archive (not a zip/tar — a JSON document is sufficient to be "a single archive" without adding a compression-library dependency) containing: an Export Manifest (export version, timestamp, repository ID/version, object/relationship/package counts), Repository Metadata, every Engineering Object, every Relationship, the full Audit Log, and — only if `--include-packages` is given — every currently `Loaded` package's manifest. `--repository` defaults to the current working directory, matching every other command.

**Import** validates the entire archive (JSON well-formedness, export manifest fields, a supported `exportVersion`, and repository metadata validity) *before* writing anything to `--destination`, so a corrupt or incompatible archive never partially populates a repository. `--destination` defaults to the current working directory. If `--destination` already exists and is non-empty, import fails unless `--overwrite` is given, in which case the existing contents are removed first. Every restored object, relationship, and audit event keeps its exact original ID and timestamps — import never regenerates identifiers.

Only export archives produced by this same build's export format version are accepted; a mismatched `exportVersion` is rejected with a descriptive error rather than attempting a best-effort import.

### Template commands

| Subcommand | Syntax | Description |
|---|---|---|
| create | `oep template create --name <name> [--description <text>] [--author <name>] [--tags a,b,c] [--include-packages] [--repository <path>] [--templates-dir <path>]` | Capture the currently open repository into a new, reusable template |
| list | `oep template list [--templates-dir <path>]` | List every valid template |
| instantiate | `oep template instantiate <template-id> <new-repository-name> [--templates-dir <path>]` | Create a new repository from a template, under the current working directory |

A template is a single JSON file, reusing the same archive format Export/Import already produce, plus its own Template Manifest (template ID, name, version, description, author, tags, Foundation version). `--templates-dir` defaults to the current working directory. `template list` silently excludes any template file that fails validation — a corrupt template never crashes the listing, it's simply absent from it. `template instantiate` validates the target template's manifest and content *before* writing anything; an invalid template is never instantiated. Instantiation always creates a **new, independent repository**: a freshly generated repository ID and the name you provide, but every object and relationship keeps its exact identifier from the template.

### Batch commands

| Subcommand | Syntax | Description |
|---|---|---|
| create | `oep batch create <input-file> [--repository <path>]` | Create a batch of objects and relationships from a JSON file |
| delete | `oep batch delete <input-file> [--repository <path>]` | Delete a batch of objects and relationships from a JSON file |
| validate | `oep batch validate <input-file> [--repository <path>]` | Validate a create-format batch file without executing it |

`--repository` defaults to the current working directory. The CLI only reads the input file and passes its contents to `FoundationRuntime`; it never parses or manipulates repository contents directly — all parsing, validation, and execution happen in `BatchProcessor` (`platform/repository`).

**Create-format input** (used by `create` and `validate`):

```json
{
  "objects": [
    {"ref": "manual", "type": "Document", "name": "Manual", "description": "...", "author": "Jane", "tags": ["docs"]}
  ],
  "relationships": [
    {"source": "manual", "target": "coil", "type": "Documents", "author": "Jane", "description": "..."}
  ]
}
```

`ref` is a batch-local alias, not a real object ID — it lets a relationship in the same batch refer to an object also being created in that batch. `source`/`target` may be a `ref` from this batch or the real ID of an object that already exists in the repository. Every field but `ref`/`source`/`target`/`type`/`name` is optional.

The full batch is validated before anything is created: duplicate `ref`s, missing `name`, unresolvable `source`/`target` references, and a `source` equal to its `target` are all reported. If validation finds any problem, **nothing is created** — not even the objects that were fine.

**Delete-format input** (used by `delete`):

```json
{
  "objectIds": ["044ba21d-85b2-4502-a5ea-3787fec41367"],
  "relationshipIds": ["a1cc95de-a335-4231-9e59-2ce396f7863c"]
}
```

Every listed ID is confirmed to exist before anything is deleted; if any ID is missing, **nothing is deleted**.

---

## Example Sessions

### Creating and inspecting a repository

```text
$ oep init my-workshop
created repository 'my-workshop' at /path/to/my-workshop

$ oep status my-workshop
Foundation version: 0.1.0
Runtime state: RepositoryOpen
Repository: my-workshop
Repository ID: 838b6f5b-5f66-4fdf-90f6-fd6df20ac326
Loaded packages: 0

$ oep validate my-workshop
Repository status: Healthy
Errors: 0  Warnings: 0  Information: 0

$ oep packages my-workshop
No packages discovered.
```

### Opening a repository directly

```text
$ oep open my-workshop
Opened repository 'my-workshop' at my-workshop
```

### Creating and managing Engineering Objects

```text
$ oep object create --type Component --name "Ignition Coil" --description "Generates spark" --author "Jane" --tags electrical,ignition
Created object '044ba21d-85b2-4502-a5ea-3787fec41367' (Component) 'Ignition Coil'

$ oep object list
044ba21d-85b2-4502-a5ea-3787fec41367	Component	Ignition Coil	1.0.0

$ oep object show 044ba21d-85b2-4502-a5ea-3787fec41367
Object ID:        044ba21d-85b2-4502-a5ea-3787fec41367
Object Type:      Component
Name:             Ignition Coil
Description:      Generates spark
Author:           Jane
Tags:             electrical, ignition
Version:          1.0.0
Created:          2026-07-08T15:06:52.762Z
Last Modified:    2026-07-08T15:06:52.762Z

$ oep object delete 044ba21d-85b2-4502-a5ea-3787fec41367
Deleted object '044ba21d-85b2-4502-a5ea-3787fec41367'

$ oep object list
No objects found.

$ oep object show 044ba21d-85b2-4502-a5ea-3787fec41367
oep: could not show object: no object with id '044ba21d-85b2-4502-a5ea-3787fec41367'
```

Every `object` subcommand runs against the repository rooted at the current working directory by default; pass `--repository <path>` to target a different one.

### Building an engineering graph with Relationships

```text
$ oep object create --type Document --name "Manual"
Created object 'f137b405-41b9-401e-8334-f085f9278b90' (Document) 'Manual'

$ oep object create --type Component --name "Coil"
Created object 'd3ddc99c-27d6-4916-a582-c0af0fbcb276' (Component) 'Coil'

$ oep relationship create --source f137b405-41b9-401e-8334-f085f9278b90 --target d3ddc99c-27d6-4916-a582-c0af0fbcb276 --type Documents --author Jane --description "Manual documents the coil"
Created relationship 'a1cc95de-a335-4231-9e59-2ce396f7863c' (Documents) 'f137b405-41b9-401e-8334-f085f9278b90' -> 'd3ddc99c-27d6-4916-a582-c0af0fbcb276'

$ oep relationship list
a1cc95de-a335-4231-9e59-2ce396f7863c	Documents	f137b405-41b9-401e-8334-f085f9278b90	d3ddc99c-27d6-4916-a582-c0af0fbcb276

$ oep relationship show a1cc95de-a335-4231-9e59-2ce396f7863c
Relationship ID:  a1cc95de-a335-4231-9e59-2ce396f7863c
Type:             Documents
Source Object ID: f137b405-41b9-401e-8334-f085f9278b90
Target Object ID: d3ddc99c-27d6-4916-a582-c0af0fbcb276
Author:           Jane
Description:      Manual documents the coil
Created:          2026-07-09T02:08:06.026Z

$ oep relationship delete a1cc95de-a335-4231-9e59-2ce396f7863c
Deleted relationship 'a1cc95de-a335-4231-9e59-2ce396f7863c'

$ oep relationship list
No relationships found.
```

`relationship create` rejects invalid input using the same validation `RelationshipStore` already enforces everywhere else — a nonexistent `--source`/`--target`, a matching `--source`/`--target`, or an unrecognized `--type` all fail with a descriptive error and create nothing:

```text
$ oep relationship create --source f137b405-41b9-401e-8334-f085f9278b90 --target f137b405-41b9-401e-8334-f085f9278b90 --type References
oep: could not create relationship: refusing to create invalid relationship: sourceObjectId and targetObjectId must differ
```

### Searching a repository

```text
$ oep object create --type Component --name "Ignition Coil" --author Jane --tags electrical,ignition --description "Generates spark"
Created object 'b28d49c3-6cef-4d48-bf7c-24839fbe8b9a' (Component) 'Ignition Coil'

$ oep object create --type Document --name "Service Manual" --author John --description "Full documentation"
Created object 'f9a455e5-b6c1-4da1-9f07-5da5d255b382' (Document) 'Service Manual'

$ oep search coil
Objects:
  b28d49c3-6cef-4d48-bf7c-24839fbe8b9a	Component	Ignition Coil	0.5	Name
Relationships:
  No matching relationships found.

$ oep search objects manual
Objects:
  f9a455e5-b6c1-4da1-9f07-5da5d255b382	Document	Service Manual	0.5	Name

$ oep search objects e --type Document
Objects:
  f9a455e5-b6c1-4da1-9f07-5da5d255b382	Document	Service Manual	0.5	Name

$ oep search objects zzz-nomatch
Objects:
  No matching objects found.
```

### Exploring the graph

```text
$ oep object create --type Document --name A
Created object '2da6763b-970d-4ea9-940d-4209b7cb8a1d' (Document) 'A'

$ oep object create --type Component --name B
Created object '70d1bb99-d796-4aa1-bd66-a8491638340f' (Component) 'B'

$ oep object create --type Component --name C
Created object '17ee1e73-18ca-49fa-8ac0-6482d95d429d' (Component) 'C'

$ oep object create --type Component --name D
Created object '2b909019-c5ba-4e74-913e-dcd5e8c6d4ae' (Component) 'D'

$ oep relationship create --source 2da6763b-970d-4ea9-940d-4209b7cb8a1d --target 70d1bb99-d796-4aa1-bd66-a8491638340f --type ConnectedTo
Created relationship '...' (ConnectedTo) '2da6763b-...' -> '70d1bb99-...'

$ oep relationship create --source 70d1bb99-d796-4aa1-bd66-a8491638340f --target 17ee1e73-18ca-49fa-8ac0-6482d95d429d --type ConnectedTo
Created relationship '...' (ConnectedTo) '70d1bb99-...' -> '17ee1e73-...'

$ oep graph neighbors 70d1bb99-d796-4aa1-bd66-a8491638340f
Neighbors:
  2da6763b-970d-4ea9-940d-4209b7cb8a1d	Document	A	ConnectedTo
  17ee1e73-18ca-49fa-8ac0-6482d95d429d	Component	C	ConnectedTo

$ oep graph traverse 2da6763b-970d-4ea9-940d-4209b7cb8a1d
Traversal (BFS):
  1	2da6763b-970d-4ea9-940d-4209b7cb8a1d	Document	A
  2	70d1bb99-d796-4aa1-bd66-a8491638340f	Component	B
  3	17ee1e73-18ca-49fa-8ac0-6482d95d429d	Component	C

$ oep graph traverse 2da6763b-970d-4ea9-940d-4209b7cb8a1d --algorithm dfs
Traversal (DFS):
  1	2da6763b-970d-4ea9-940d-4209b7cb8a1d	Document	A
  2	70d1bb99-d796-4aa1-bd66-a8491638340f	Component	B
  3	17ee1e73-18ca-49fa-8ac0-6482d95d429d	Component	C

$ oep graph path 2da6763b-970d-4ea9-940d-4209b7cb8a1d 17ee1e73-18ca-49fa-8ac0-6482d95d429d
Path Found

$ oep graph path 2da6763b-970d-4ea9-940d-4209b7cb8a1d 2b909019-c5ba-4e74-913e-dcd5e8c6d4ae
No Path Found
```

`D` was never connected to anything, so it doesn't appear in `A`'s traversal and has no path to `A`.

### Exporting and importing a repository

```text
$ oep object create --type Document --name "Manual" --author Jane --tags docs
Created object '8eec9074-9ecf-455a-994c-e4127e229aab' (Document) 'Manual'

$ oep object create --type Component --name "Coil"
Created object 'c8c9aa2d-a066-429e-ba20-940e8dcfa1ba' (Component) 'Coil'

$ oep relationship create --source 8eec9074-9ecf-455a-994c-e4127e229aab --target c8c9aa2d-a066-429e-ba20-940e8dcfa1ba --type Documents
Created relationship '...' (Documents) '8eec9074-...' -> 'c8c9aa2d-...'

$ oep export ../backup.json
Exported repository to '../backup.json'
  Objects:       2
  Relationships: 1
  Packages:      0

$ cd ..
$ oep import backup.json --destination restored-workshop
Imported repository to 'restored-workshop'
  Objects:       2
  Relationships: 1
  Packages:      0

$ cd restored-workshop
$ oep object show 8eec9074-9ecf-455a-994c-e4127e229aab
Object ID:        8eec9074-9ecf-455a-994c-e4127e229aab
Object Type:      Document
Name:             Manual
Description:      
Author:           Jane
Tags:             docs
Version:          1.0.0
Created:          2026-07-09T04:17:38.651Z
Last Modified:    2026-07-09T04:17:38.651Z
```

The restored object's ID, author, tags, and both timestamps are exactly what was originally created — import never regenerates identifiers.

Attempting to import into a destination that already has content fails safely, and `--overwrite` replaces it:

```text
$ oep import backup.json --destination restored-workshop
oep: import failed: destination 'restored-workshop' already exists (use --overwrite)

$ oep import backup.json --destination restored-workshop --overwrite
Imported repository to 'restored-workshop'
  Objects:       2
  Relationships: 1
  Packages:      0
```

An archive that isn't valid JSON, or that declares an unsupported export version, is rejected the same way:

```text
$ oep import corrupt.json --destination somewhere
oep: import failed: archive 'corrupt.json' is not valid JSON: invalid literal at offset 0
```

### Creating and instantiating a template

```text
$ oep object create --type Component --name "Standard Widget" --tags standard
Created object 'fc89cf98-3340-44ed-b189-f4d791129586' (Component) 'Standard Widget'

$ oep template create --name "Standard Kit" --description "A reusable starting point" --author Jane --tags starter --templates-dir ../templates
Created template 'b1fd54c0-3bad-43a0-8224-f36acde73db4' ('Standard Kit')

$ cd ..
$ oep template list --templates-dir templates
b1fd54c0-3bad-43a0-8224-f36acde73db4	Standard Kit	1.0.0

$ oep template instantiate b1fd54c0-3bad-43a0-8224-f36acde73db4 new-workshop --templates-dir templates
Instantiated template 'b1fd54c0-3bad-43a0-8224-f36acde73db4' as repository 'new-workshop' at /path/to/new-workshop

$ cd new-workshop
$ oep object list
fc89cf98-3340-44ed-b189-f4d791129586	Component	Standard Widget	1.0.0

$ oep status
Foundation version: 0.1.0
Runtime state: RepositoryOpen
Repository: .
Repository ID: 7b9527e4-ded6-4a2b-9e55-b0acbd4a5a4e
Loaded packages: 0
```

`new-workshop` has its own, freshly generated repository ID (`7b9527e4-...`, different from the template's ID), but `Standard Widget` kept its exact original object ID from the template.

### Batch creating, validating, and deleting

```text
$ cat kit.json
{
  "objects": [
    {"ref": "manual", "type": "Document", "name": "Manual", "author": "Jane"},
    {"ref": "coil", "type": "Component", "name": "Ignition Coil", "tags": ["electrical"]}
  ],
  "relationships": [
    {"source": "manual", "target": "coil", "type": "Documents", "description": "docs the coil"}
  ]
}

$ oep batch create kit.json
Objects created:       2
Relationships created: 1

$ oep object list
044ba21d-85b2-4502-a5ea-3787fec41367	Document	Manual	1.0.0
7b9527e4-ded6-4a2b-9e55-b0acbd4a5a4e	Component	Ignition Coil	1.0.0

$ cat bad-kit.json
{
  "objects": [
    {"ref": "x", "type": "Component", "name": "A"},
    {"ref": "x", "type": "Component", "name": "B"}
  ]
}

$ oep batch validate bad-kit.json
Batch is invalid:
  duplicate ref 'x'

$ oep batch delete delete.json
Objects deleted:       1
Relationships deleted: 0
```

A `validate` run that finds no problems reports `Batch is valid.` and exits `0`; a run that finds problems exits non-zero and lists every finding, without creating or deleting anything.

### An invalid or missing repository

```text
$ oep validate ./does-not-exist
oep: could not open repository: could not load repository metadata: could not open './does-not-exist/repository.json'
```

`status` handles a missing repository without failing the command itself:

```text
$ oep status ./does-not-exist
Foundation version: 0.1.0
Runtime state: Initialized
Repository: none (could not load repository metadata: could not open './does-not-exist/repository.json')
```

---

## Repository Layout Expected by Foundation

A repository generated by `oep init` (per OEP-SPEC-002-FOUNDATION_REPOSITORY) has this top-level shape:

```text
my-workshop/
├── repository/
├── workspace/
├── packages/
├── cache/
├── logs/
├── exports/
├── settings/
├── README.md
├── .gitignore
├── repository.json
└── workspace.json
```

When `FoundationRuntime` opens a repository, it additionally expects (and will create as needed when writing) Engineering Objects, Relationships, and Audit Events at fixed locations beneath `repository/`:

```text
repository/
├── objects/         Engineering Objects (one JSON file per object)
├── relationships/    Relationships (one JSON file per relationship)
└── audit/            Audit Events (one JSON file per event)
```

Packages are discovered under the repository's top-level `packages/` directory; each package is a subdirectory containing a `package.json` manifest.

---

## Current Limitations

- No persistent session: every CLI invocation is a fresh process. `oep open` opens a repository through `FoundationRuntime`, reports the result, and shuts the Runtime down before exiting — it does not keep a repository open for subsequent commands. `validate`/`packages`/`status` each independently open (and close) the repository they operate on.
- Output is plain, human-readable text only; there is no structured/JSON output mode yet.
- No interactive shell, scripting support, or remote execution.
- `oep init` does not yet populate `repository/objects`, `repository/relationships`, or `repository/audit` — those directories are created on demand by the Runtime-backed commands the first time they're needed.
- Package installation, updates, and dependency resolution are not implemented; `oep packages` only discovers and reports what's already present.
- `oep object` supports create/list/show/delete only — there is no way to edit an existing object's fields from the CLI or import binary assets yet.
- `oep object list` always sorts by Object ID; there is no filtering or alternate sort order yet.
- `oep relationship` supports create/list/show/delete only — there is no editing, batch creation, or graph visualization from the CLI yet.
- `oep relationship list` always sorts by Relationship ID; there is no filtering or alternate sort order yet.
- `oep search` supports exact `--type`/`--author`/`--tag` matches only (no partial-match filters); `--tag` has no effect when searching relationships, since Relationships have no tags field.
- There is no semantic search, AI-assisted search, regular-expression search, saved searches, or query language — only the case-insensitive, partial-match search `SearchEngine` already provides.
- `oep graph` treats every relationship as connecting its two objects bidirectionally for traversal purposes, regardless of which end is `sourceObjectId` vs. `targetObjectId` (this mirrors `GraphEngine`'s own behavior, not a CLI-specific choice).
- `oep graph path` reports only whether a path exists — there is no shortest-path computation, path visualization, or listing of the relationships along the way.
- `oep graph traverse` supports BFS and DFS only; there is no weighted traversal or interactive/step-by-step exploration.
- The export archive is a single JSON file, not a compressed/binary container — there is no encryption, and large repositories will produce correspondingly large archive files.
- `oep export`/`oep import` do not support cloud synchronization, a package registry, incremental (partial) export, merge operations, or conflict resolution — import always reconstructs a whole repository from a whole archive.
- `oep import` restores package *manifests* only (writing `packages/<packageId>/package.json`); it does not restore any other files a package directory might contain, since `PackageManager` itself only ever inspects `package.json`.
- Archives are only accepted from the same export format version this build produces (`exportVersion` must match exactly) — there is no forward/backward compatibility handling across export format versions yet.
- There is no online template registry, template version upgrades, or template dependencies — `oep template` only creates, lists, and instantiates local template files.
- `oep template instantiate` always creates the new repository under the current working directory (using the name you give it); there is no `--destination` flag yet.
- Templates, like export archives, restore package manifests only, not arbitrary other package payload files.
- `oep batch` supports `create`/`delete`/`validate` only; there is no `update`/`edit` batch operation, and `validate` only checks the create-format, not delete-format, input.
- Batch input is plain JSON only, read from a local file — there is no streaming, chunking, or partial-batch execution; a batch either fully succeeds or fully fails.
- The `ref` aliasing mechanism only resolves within a single batch file; it cannot reference a `ref` used in a previous, separate `oep batch create` invocation.

---

## Troubleshooting

**"could not open repository: could not load repository metadata"**
The given path isn't an OEP repository, or `repository.json` is missing/corrupt. Confirm the path and that `oep init` completed successfully there.

**A command exits with a non-zero status but no explanation**
Every command prints a descriptive error to stderr before returning a non-zero exit code — check stderr, not just stdout. Commands never surface stack traces or internal exception text; if you see something that looks like one, it indicates a bug worth reporting.

**`oep validate` reports errors on a repository you believe is healthy**
Run `oep validate` again — reports are deterministic for unchanged repository state, so a differing result across runs indicates the repository itself changed between runs, not a flaky validator.
