/// An Engineering Context's review status (Work Package 015
/// STUDIO-TASK-000043: "Engineers may: Accept, Ignore, Split, Merge.
/// No automatic repository changes."). Deliberately the same
/// `pending`/`accepted`/`ignored` vocabulary `EngineeringEntityStatus`
/// (Work Package 014) already established, for the same reason: a
/// Context is never a Knowledge Candidate ("Contexts are not Knowledge
/// Candidates" — this work package's own Architecture Rules), so
/// accepting or ignoring one carries no Knowledge Candidate
/// implication and no `KnowledgeCandidateStatus` vocabulary applies.
/// Accepting a Context here means only "I reviewed this grouping and
/// agree it is correct" — unlike `EngineeringEntityStatus.accepted`,
/// it never creates anything downstream (see
/// `docs/ENGINEERING_CONTEXT.md` § Context Explorer).
enum EngineeringContextStatus { pending, accepted, ignored }
