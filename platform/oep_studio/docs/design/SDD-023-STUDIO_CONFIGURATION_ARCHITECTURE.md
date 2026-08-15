# SDD-023

# Studio Configuration Architecture

Status: Frozen

Version: 1.0

---

# Revision History

| Version | Date | Description |
|----------|------|-------------|
| 1.0 | 2026-07 | Initial Studio Configuration Architecture |

---

# Purpose

This document defines the architecture governing all Studio configuration.

Configuration shall be centralized, searchable, extensible, and independent of any individual subsystem.

This specification applies to every future Studio feature.

---

# Philosophy

Configuration exists to customize Studio behavior.

Configuration shall never modify engineering data.

Engineering data belongs to:

- Foundation
- Repository
- Knowledge Session

Configuration belongs only to Studio.

---

# Configuration Scope

Studio configuration is divided into four persistence scopes.

## User Configuration

Applies to the current user across every repository.

Examples:

- Theme
- Language
- AI Provider
- Window Layout
- Plugin Settings

---

## Repository Configuration

Applies only to one repository.

Examples:

- Default Packages
- Validation Rules
- Naming Preferences

Repository configuration is stored with the repository.

---

## Knowledge Session Configuration

Applies only to one Knowledge Session.

Examples:

- OCR Overlay Visibility
- Active Filters
- Graph Layout
- Review Preferences

---

## Runtime Configuration

Temporary state.

Never persisted.

Examples:

- Current Selection
- Current Tool
- Open Dialogs
- Active AI Request

---

# Settings Workspace

Settings shall exist as a dedicated Studio Workspace.

Settings are not implemented as modal dialogs.

Navigation shall appear on the left.

Settings content shall appear on the right.

---

# Navigation

The Settings Workspace shall contain:

- General
- Appearance
- Workspace
- Repository
- Knowledge Studio
- Artificial Intelligence
- Plugins
- Updates
- Diagnostics
- Security
- About

Future modules may register additional pages.

---

# General

Contains:

- Language
- Region
- Units
- Date Format
- Time Format
- Autosave
- Startup Behavior
- Logging

---

# Appearance

Contains:

- Theme
- Accent Color
- Density
- Font Size
- Icon Size
- Animations
- Workspace Scaling

---

# Workspace

Contains:

- Default Workspace
- Recent Workspaces
- Window Behavior
- Docking
- Multi-monitor
- Restore Layout

---

# Repository

Contains:

- Default Repository
- Auto-open
- Backup
- Snapshots
- Cache
- Validation Defaults

---

# Knowledge Studio

Contains:

- Autosave
- OCR Overlay
- Evidence Colors
- Default Zoom
- Context Display
- Entity Display
- Review Preferences

---

# Artificial Intelligence

Contains:

- Enable AI
- Provider
- Model
- API Configuration
- Local Server Configuration
- Temperature
- Timeout
- Context Window
- Reasoning Depth
- Privacy Controls
- Test Connection

AI credentials shall never be stored inside Knowledge Sessions.

---

# Plugins

Contains:

- Installed Plugins
- Enable
- Disable
- Permissions
- Updates
- Marketplace

Plugins may register their own settings pages.

---

# Updates

Contains:

- Automatic Updates
- Update Channel
- Stable
- Preview
- Nightly

---

# Diagnostics

Contains:

- Logging
- Performance
- Memory
- GPU
- Foundation Runtime
- Studio Runtime
- Reset Studio

---

# Security

Contains:

- Credential Storage
- Certificate Management
- Privacy
- Encryption
- Secure Storage

Secrets shall use operating-system credential facilities whenever available.

---

# About

Contains:

- Studio Version
- Foundation Version
- API Version
- ABI Version
- Build Information
- License
- Third-party Notices

---

# Settings Search

Settings shall provide full-text search.

Search shall include:

- Setting Name
- Description
- Keywords

Selecting a search result navigates directly to the setting.

---

# Provider Registration

Subsystems may register settings pages.

Registration occurs through a Settings Provider interface.

Core Studio shall not contain subsystem-specific code.

---

# AI Provider Registration

AI Providers register:

- Configuration UI
- Model List
- Provider Status
- Connection Test

Changing providers shall not require changes to the Settings Workspace.

---

# Plugin Registration

Plugins register:

- Settings Pages
- Categories
- Validation
- Defaults

Plugin settings are isolated from core Studio.

---

# Configuration Storage

User configuration shall be versioned.

Migration shall occur automatically.

Defaults shall be applied when values are missing.

---

# Import / Export

Support:

- Export User Settings
- Import User Settings
- Reset to Defaults

Secrets shall never be exported.

---

# Validation

Settings shall be validated before persistence.

Invalid values shall never be written.

---

# Security

Credentials shall never be written to:

- Repository
- Knowledge Session
- Commit Report

Credentials remain external to engineering data.

---

# Architecture Rules

1. Configuration is independent of engineering data.

2. Settings Workspace owns configuration.

3. Foundation owns no user configuration.

4. Plugins extend Settings through registration.

5. AI Providers extend Settings through registration.

6. Secrets remain outside exported data.

7. Settings are searchable.

8. Settings are versioned.

9. Runtime state is never persisted as configuration.

10. Configuration shall remain provider-independent.