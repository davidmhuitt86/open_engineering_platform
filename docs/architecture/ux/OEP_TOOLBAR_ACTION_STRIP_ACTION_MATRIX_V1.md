OEP TOOLBAR / ACTION STRIP
ACTION MATRIX — V1

PURPOSE
-------
The Toolbar / Action Strip is a context-sensitive command surface.
It presents the commands most relevant to the active Studio and
workspace.

The toolbar does NOT define application navigation.
The toolbar does NOT replace the Studio Tab Bar.
The toolbar does NOT contain global header functions.

Visual treatment is shared across OEP.
Command content is determined by the active Studio/workspace.

===============================================================
GLOBAL RULES
===============================================================

GLOBAL HEADER FUNCTIONS
    Search
    Notifications
    User / Account
    System Status
    Window Controls

    → NEVER duplicated in the toolbar.

STUDIO NAVIGATION
    Home
    Diagram Studio
    EAM
    Knowledge Studio
    Engineering Exchange
    Tools
    Settings

    → NEVER duplicated in the toolbar.

WORKSPACE NAVIGATION
    Workspace tabs
    New workspace
    Tab overflow
    Tab close

    → NEVER duplicated in the toolbar.

===============================================================
COMMAND GROUP TYPES
===============================================================

FILE
    New
    Open
    Save
    Save As
    Import
    Export

EDIT
    Undo
    Redo
    Cut
    Copy
    Paste
    Delete

VIEW
    Zoom In
    Zoom Out
    Fit
    Pan
    Full Screen
    View Options

SEARCH
    Find
    Filter
    Sort
    Advanced Search

TOOLS
    Studio-specific tools

ENGINEERING
    Engineering-specific operations

VALIDATION
    Validate
    Review
    Issues

SIMULATION
    Run
    Stop
    Pause
    Reset
    Simulation Options

LAYOUT
    Align
    Distribute
    Arrange
    Auto Layout
    Grid
    Snap

DATA
    Capture
    Record
    Refresh
    Import
    Export

MORE
    Secondary / infrequent commands


===============================================================
01 — HOME
===============================================================

PRIMARY PURPOSE
    Landing / work selection

TOOLBAR
    None by default

OPTIONAL CONTEXT ACTIONS
    New Work
    Open Work
    Refresh

RULE
    Home should not feel like an engineering editor.


===============================================================
02 — DIAGRAM STUDIO
===============================================================

FILE
    New Diagram
    Open
    Save

EDIT
    Undo
    Redo
    Cut
    Copy
    Paste
    Delete

VIEW
    Zoom In
    Zoom Out
    Fit
    Pan
    View Options

DIAGRAM
    Select
    Wire
    Component
    Connector
    Annotation
    Measure

LAYOUT
    Align
    Distribute
    Arrange
    Auto Layout
    Grid
    Snap

ENGINEERING
    Inspect
    Trace
    Validate

SIMULATION
    Run
    Pause
    Stop
    Reset

MORE
    Secondary diagram commands


===============================================================
03 — ENGINEERING ACQUISITION (EAM)
===============================================================

SOURCE
    Add Source
    Open Source
    Refresh

ACQUISITION
    Acquire
    Queue
    Pause
    Resume
    Cancel

VERIFICATION
    Verify
    Review
    Inspect Evidence

KNOWLEDGE
    Extract
    Preview
    Commit

PIPELINE
    View Pipeline
    Retry
    View Errors

MORE
    Secondary acquisition commands


===============================================================
04 — KNOWLEDGE STUDIO
===============================================================

OBJECT
    New Object
    Edit
    Inspect

RELATIONSHIP
    Create Relationship
    Inspect Relationship

GRAPH
    Expand
    Collapse
    Trace
    Layout

SEARCH
    Find
    Filter
    Sort

VALIDATION
    Validate
    Review Issues

VIEW
    Zoom
    Fit
    Pan
    View Options

MORE
    Secondary knowledge commands


===============================================================
05 — ENGINEERING EXCHANGE
===============================================================

DISCOVER
    Search
    Browse
    Filter
    Sort

ASSET
    Open
    Preview
    Inspect

PUBLISH
    Publish
    Update
    Unpublish

LICENSE
    License
    Manage License

PACKAGE
    Install
    Export

MORE
    Secondary Exchange commands


===============================================================
06 — TOOLS
===============================================================

TOOL
    New Tool
    Open Tool
    Close Tool

INSTRUMENT
    Connect
    Configure
    Start
    Stop

DATA
    Capture
    Record
    Export
    Clear

VIEW
    Zoom
    Fit
    View Options

MORE
    Tool-specific commands


===============================================================
07 — SETTINGS
===============================================================

CONFIGURATION
    Apply
    Reset

DATA
    Import
    Export
    Backup
    Restore

SYSTEM
    Diagnostics
    Check for Updates

MORE
    Advanced configuration


===============================================================
08 — REPOSITORY
===============================================================

REPOSITORY
    New Repository
    Open
    Refresh

OBJECTS
    New
    Import
    Export

VIEW
    List
    Details
    History

SEARCH
    Find
    Filter
    Sort

MORE
    Repository-specific commands

NOTE
    Synchronization commands remain subject to the repository
    architecture and synchronization contract. Do not implement
    Pull / Push / Sync merely because they appear in this UI matrix.


===============================================================
09 — SEARCH
===============================================================

SEARCH
    New Search
    Search
    Clear

FILTER
    Filter
    Sort

RESULTS
    Open
    Inspect
    Add to Workspace

MORE
    Advanced search commands


===============================================================
COMMAND PRIORITY
===============================================================

The toolbar should NOT display every available command simultaneously.

PRIORITY 1 — PRIMARY
    Most frequently used commands.
    Always visible when applicable.

PRIORITY 2 — SECONDARY
    Frequently useful but less common.
    Visible when space permits.

PRIORITY 3 — ADVANCED
    Infrequent / specialized commands.
    Placed under More or an appropriate command menu.

===============================================================
RESPONSIVE DENSITY
===============================================================

WIDE WINDOW
    Primary + secondary commands visible.

NORMAL WINDOW
    Primary commands visible.
    Secondary commands may collapse.

DENSE WINDOW
    Primary commands remain.
    Secondary commands collapse into More.

VERY DENSE
    Icon-only representation may be used where appropriate.

RULE
    The toolbar must never force the primary work surface to become
    unusably small merely to keep every command visible.


===============================================================
COLOR RULE
===============================================================

Toolbar controls inherit the ACTIVE STUDIO accent identity.

DIAGRAM STUDIO
    Blue

EAM
    Green / Teal

KNOWLEDGE STUDIO
    Gold

ENGINEERING EXCHANGE
    Purple

TOOLS
    Red

SETTINGS
    Slate

ACTIVE / IMPORTANT COMMAND
    Luminous version of Studio accent

NORMAL COMMAND
    Subdued version of Studio accent

DANGER / DESTRUCTIVE ACTION
    May use an appropriate warning treatment when necessary.

RULE
    Do not create a rainbow toolbar by assigning arbitrary colors
    to command groups.


===============================================================
IMPORTANT ARCHITECTURAL DISTINCTION
===============================================================

TOOLBAR FRAMEWORK
    Global / shared UI component

COMMAND CONTENT
    Studio-owned

COMMAND EXECUTION
    Existing command / Engine / service architecture

VISUAL STATE
    UI responsibility

ENGINEERING SEMANTICS
    Engine / domain responsibility


Example:

    [WIRE]

        UI
         ↓
        Command
         ↓
        Diagram Engine
         ↓
        Engineering Object / Relationship
         ↓
        Renderer
         ↓
        UI


The toolbar must not contain engineering logic.


===============================================================
STAGE 1 vs STAGE 2
===============================================================

STAGE 1 — UI DESIGN

    Build toolbar geometry
    Build button components
    Build groups
    Build active / hover / disabled states
    Build overflow behavior
    Use representative placeholder commands
    Validate visual hierarchy

    Functional execution is NOT required.


STAGE 2 — FUNCTIONAL INTEGRATION

    Connect toolbar commands
    Connect command routing
    Connect Engine
    Connect Repository
    Connect EAM
    Connect validation
    Connect simulation
    Connect events / state

    Existing visual design remains the target.


===============================================================
SECTION 7 DEFINITION OF DONE
===============================================================

[ ] Toolbar boundary established
[ ] Toolbar height established
[ ] Toolbar ownership established
[ ] Studio-specific command matrix established
[ ] Primary vs secondary commands established
[ ] Overflow behavior established
[ ] Button geometry established
[ ] Angular/polygon geometry matches OEP navigation
[ ] Studio accent inheritance established
[ ] Active state established
[ ] Hover state established
[ ] Disabled state established
[ ] Destructive state established
[ ] Command grouping established
[ ] Density behavior established
[ ] Stage 1 / Stage 2 separation documented
[ ] 1920×1080 visual reference approved
[ ] Toolbar frozen