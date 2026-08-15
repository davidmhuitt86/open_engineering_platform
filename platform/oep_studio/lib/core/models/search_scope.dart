/// Which part of the repository a Search Workspace query searches
/// (STUDIO-TASK-000012: "Support: Repository Search, Object Search,
/// Relationship Search"). Not part of `FoundationServiceState` — like
/// Search History, this is Search Workspace presentation state, not
/// Foundation-derived state, so it lives as local `SearchPage` state
/// rather than in the Connection Manager.
enum SearchScope {
  repository('Repository'),
  objects('Objects'),
  relationships('Relationships');

  const SearchScope(this.label);

  final String label;
}
