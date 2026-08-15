# SDD-022

# Artificial Intelligence Architecture

Status: Frozen

Version: 1.0

---

# Purpose

This document defines the architectural principles governing all Artificial Intelligence capabilities within the Open Engineering Platform.

This specification applies to every current and future AI implementation.

No implementation may violate these principles.

---

# Philosophy

Artificial Intelligence exists to assist engineers.

Artificial Intelligence never replaces engineering judgment.

Engineering truth is established only through engineer review and, where applicable, Repository Commit.

AI generates hypotheses.

Engineers generate knowledge.

Foundation stores engineering truth.

---

# AI Architecture

The AI subsystem exists above the deterministic engineering pipeline.

The deterministic pipeline shall always execute before AI.

```
Source Material

↓

OCR

↓

Engineering Entity Extraction

↓

Engineering Context Detection

↓

AI Analysis

↓

Engineer Review

↓

Knowledge Candidate

↓

Validation

↓

Repository Commit

↓

Foundation Repository
```

AI consumes deterministic engineering evidence.

AI never consumes raw engineering documents directly.

---

# Inputs

AI may consume:

- OCR text
- Engineering Entities
- Engineering Contexts
- Existing Knowledge Candidates
- Evidence metadata

AI shall not consume:

- Raw images
- Raw PDFs
- Repository internals
- Foundation Runtime objects

---

# Outputs

AI produces:

- Knowledge Candidate Suggestions
- Relationship Suggestions
- Engineering Summaries
- Classification Suggestions
- Confidence
- Reasoning

AI outputs are Workspace artifacts.

AI outputs are never Engineering Objects.

---

# Engineer Authority

Every AI suggestion requires explicit engineer review.

Engineers may:

- Accept
- Edit
- Reject
- Defer

AI shall never automatically:

- Create Knowledge Candidates
- Modify Knowledge Candidates
- Delete Knowledge Candidates
- Modify Foundation
- Commit repositories

---

# Explainability

Every AI suggestion shall include:

- Supporting evidence
- Confidence
- Reasoning

Supporting evidence shall remain visible.

Engineers shall always be able to trace a suggestion back to the originating engineering evidence.

---

# Provider Independence

Studio shall not depend on a specific AI provider.

All providers shall implement a common interface.

Supported providers may include:

- OpenAI
- Anthropic
- Google Gemini
- Ollama
- LM Studio
- OpenRouter

Additional providers may be added without changing Knowledge Workspace architecture.

---

# Provider Architecture

```
Knowledge Workspace

↓

AI Analysis Service

↓

AI Provider Interface

├── OpenAI

├── Anthropic

├── Gemini

├── Ollama

├── LM Studio

├── OpenRouter

└── Future Providers
```

Knowledge Workspace shall communicate only with the AI Provider Interface.

No Workspace component shall depend upon provider-specific APIs.

---

# Prompt Construction

Prompt generation belongs entirely within the AI Analysis Service.

Widgets shall never construct prompts.

Connection Manager shall never construct prompts.

Prompt templates shall remain replaceable.

---

# AI Session Persistence

AI Suggestions shall persist with the Knowledge Session.

Persist:

- Suggestion
- Reasoning
- Confidence
- Provider
- Model
- Timestamp
- Review Status

Re-analysis shall occur only when deterministic engineering evidence changes.

---

# Confidence

Confidence is informational.

Confidence shall never:

- Automatically approve
- Automatically reject
- Automatically commit

Confidence assists engineers.

Confidence never replaces engineers.

---

# Security

API credentials shall never be persisted inside Knowledge Sessions.

Credentials shall remain external to session storage.

Prompt contents shall never include repository secrets or unrelated user data.

---

# Foundation

Foundation remains completely AI-independent.

Foundation stores engineering truth only.

Foundation has no knowledge of:

- AI providers
- AI prompts
- AI suggestions
- AI confidence
- AI reasoning

Only engineer-approved Engineering Objects reach Foundation.

---

# Extensibility

Future AI capabilities may include:

- Relationship Suggestions
- Procedure Generation
- Specification Extraction
- Wiring Diagram Understanding
- Table Understanding
- Conflict Detection
- Engineering Summarization

All future capabilities shall conform to this architecture.

---

# Architectural Principles

1. Deterministic processing precedes AI.

2. AI augments engineers.

3. Engineers remain authoritative.

4. AI is fully inspectable.

5. AI is provider-independent.

6. Foundation remains AI-independent.

7. AI never commits engineering knowledge.

8. Repository truth exists only after engineer approval and Repository Commit.