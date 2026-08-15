# OEP Desktop

# WORK PACKAGE 018

Status: Approved

Version: 1.0

---

# Objective

Implement the first production AI Provider using Anthropic.

This work package validates the AI Provider architecture introduced in Work Package 016 and the Settings architecture introduced in Work Package 017.

No Foundation changes.

No Public C API changes.

No architectural redesign.

---

# Knowledge Architecture

This work package shall conform to:

- SDD-013 through SDD-023

Implementation shall not introduce independent architectural decisions.

---

# STUDIO-TASK-000056

## Anthropic Provider

Implement AnthropicProvider.

AnthropicProvider shall implement AIProvider.

Support:

- Authentication
- Request execution
- Response parsing
- Retry
- Timeout
- Cancellation

Streaming support is optional.

---

# STUDIO-TASK-000057

## AI Settings Integration

Integrate Anthropic into the Artificial Intelligence page.

Support:

- Enable AI
- Provider Selection
- API Key
- Model
- Timeout
- Temperature
- Max Tokens

API Keys shall be stored using operating-system secure credential storage.

No credentials shall be written into:

- User Configuration
- Repository
- Knowledge Session

---

# STUDIO-TASK-000058

## Connection Verification

Implement:

- Test Connection

Display:

- Connected
- Authentication Failed
- Network Error
- Provider Error

Status shall be visible inside Settings.

---

# STUDIO-TASK-000059

## Live AI Analysis

Connect:

PromptService

↓

AnthropicProvider

↓

AI Review Workspace

Real AI Suggestions shall appear inside the existing review workflow.

The review workflow itself shall remain unchanged.

---

# Property Inspector

Extend support for:

- Provider
- Model
- Token Usage
- Response Metadata

---

# Connection Manager

Extend support for:

- AI Connection Status
- Current Model
- Active Request

Connection Manager coordinates application state only.

---

# Architecture Rules

AnthropicProvider is only an AIProvider implementation.

No Workspace component shall depend directly upon Anthropic.

Prompt construction remains inside PromptService.

Engineer approval remains mandatory.

Repository Commit remains unchanged.

---

# Error Handling

Handle:

- Missing API Key
- Invalid API Key
- Timeout
- Rate Limiting
- Network Failure
- Provider Failure
- Invalid Response

Display professional messages.

---

# Verification

Perform:

- flutter analyze
- flutter test
- flutter build windows

Verify:

- Authentication
- Connection Test
- Prompt Execution
- AI Suggestions
- Review Workflow
- Session Persistence

Manual verification shall use a real Anthropic API key.

---

# Documentation

Update:

- README.md
- docs/IMPLEMENTATION_STATUS.md
- docs/STUDIO_SETTINGS.md
- docs/AI_PROVIDER_ARCHITECTURE.md

Create:

docs/ANTHROPIC_PROVIDER.md

Document:

- Authentication
- Secure credential storage
- Provider implementation
- Prompt execution
- Response parsing
- Error handling
- Architectural observations

---

# Definition of Done

Complete when:

- AnthropicProvider functions.
- Settings integration functions.
- Connection testing functions.
- Live AI suggestions function.
- Documentation complete.
- flutter analyze passes.
- flutter tests pass.
- Windows build succeeds.
- Manual verification succeeds.

Stop after completion and await formal review.