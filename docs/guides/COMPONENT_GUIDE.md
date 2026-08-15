# Component Guide

The reusable component catalog for `apps/publisher-portal` (TASK-EXC-0009, `docs/tasks/WP-EXC-009.md` §6), all in `src/components/`. Every component is presentational — none call `exchange-client` themselves; pages fetch data and pass it down as props.

This catalog is specific to the React web app. The OEP Studio Exchange workspace (WP-EXC-010, `docs/guides/STUDIO_INTEGRATION_GUIDE.md`) has its own, unrelated set of Flutter panel widgets (`oep_studio/lib/exchange/panels/`) that are not built from this catalog — Studio never embeds or reuses these React components.

## Shell

| Component  | Purpose                                                                                                                                                                                                                             |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AppShell` | The page layout: `Header` + `Sidebar` + a `<main>` rendering the matched route (`<Outlet/>`) + `Footer`. Mounted once, at the router's layout-route level (`App.tsx`).                                                              |
| `Header`   | Brand, the global `SearchBar` (submitting navigates to `/search?q=...`), and the mobile sidebar-toggle button.                                                                                                                      |
| `Sidebar`  | The primary navigation (Home, Search, Categories, Publishers, My Library, Downloads). Collapses to an off-canvas panel below the tablet breakpoint (`global.css`'s `@media (max-width: 900px)`), toggled by `Header`'s menu button. |
| `Footer`   | Static footer text.                                                                                                                                                                                                                 |

## Data display

| Component       | Props (key ones)                                                                      | Purpose                                                                        |
| --------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `PackageCard`   | `id, displayName, description, status, currentVersion, publisherName?, categoryName?` | One package as a card, linking to `/packages/{id}`. Used by `PackageList`.     |
| `PublisherCard` | `id, displayName, publisherType, description`                                         | One publisher as a card, linking to `/publishers/{id}`.                        |
| `CategoryCard`  | `id, name, packageCount`                                                              | One category as a card, linking to `/search?categoryId={id}`.                  |
| `PackageList`   | `items: PackageCardProps[], emptyTitle?, emptyMessage?`                               | A responsive grid of `PackageCard`s, or an `EmptyState` when `items` is empty. |
| `Breadcrumbs`   | `items: { label, to? }[]`                                                             | The last item (no `to`) renders as plain text, not a link.                     |
| `Pagination`    | `currentPage, totalPages, onPageChange`                                               | Renders nothing when `totalPages <= 1`.                                        |

## Input

| Component   | Props                                   | Purpose                                                                             |
| ----------- | --------------------------------------- | ----------------------------------------------------------------------------------- |
| `SearchBar` | `initialValue?, placeholder?, onSubmit` | A controlled text input + submit button; trims the value before calling `onSubmit`. |

## Status

| Component          | Props                      | Purpose                                                                                                               |
| ------------------ | -------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `LoadingIndicator` | `label?`                   | A spinner + label, `role="status"`. The only place "loading" content may substitute for real data (WP-EXC-009.md §7). |
| `EmptyState`       | `title, message?, action?` | A dashed-border placeholder for an empty list/result set. `action` accepts an arbitrary node (e.g. a link).           |
| `ErrorView`        | `message, onRetry?`        | `role="alert"`; renders a "Try again" button only when `onRetry` is provided.                                         |

## Styling

Every component is styled through class names defined once in `src/styles/global.css` (design tokens as CSS custom properties, then component classes: `.card`, `.badge--{status}`, `.btn`/`.btn--primary`/`.btn--secondary`, `.search-bar`, `.breadcrumbs`, `.pagination`, `.loading-indicator`, `.empty-state`, `.error-view`) — no CSS-in-JS, no per-component stylesheet, no utility-class framework. This keeps the visual language consistent across every view without introducing a styling dependency (WP-EXC-009.md §8 "Maintain a consistent visual language across all device sizes").

## Adding a new reusable component

1. Add `src/components/YourComponent.tsx`, exporting the component and its own `YourComponentProps` interface.
2. Style it with existing `global.css` classes where possible; add new classes to `global.css` only for a genuinely new visual pattern (see `.search-filters`/`.plain-list` for small, recent examples).
3. Add `src/components/YourComponent.test.tsx` — render it (wrapped in `<MemoryRouter>` if it renders a `Link`/`NavLink`) and assert the behavior that matters (what it renders, what it calls on interaction) — see any existing component test for the pattern.
