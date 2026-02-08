# Changelog

All notable changes to this template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-02-08

### Added
- `/whats-next` slash command for secure context handoff documents
  - Creates comprehensive handoff docs for continuing work in fresh sessions
  - Security-hardened: only Read/Write tools, no secrets, file overwrite protection
  - Documentation in `docs/WORKFLOW.md` explaining when and how to use it

### Removed
- **BREAKING:** Removed copier questions: `has_guardrails_proxy`, `guardrails_endpoint`, `has_knowledge_graph`, `memgraph_host`, `memgraph_port`
  - Existing projects with these in `.copier-answers.yml` may see warnings on `copier update`
  - Remove these keys from your `.copier-answers.yml` to silence warnings
- Memgraph/Knowledge Graph integration (MCP server, graph scripts, agent graph queries)
- Obsidian/Vault integration (@archivist agent, vault routing in hooks)
- Tailscale onboarding step
- Guardrails proxy configuration
- Telegram-bot specific paths and examples (generalized to `src/app/`)

### Changed
- Template is now fully portable - no infrastructure-specific content
- Model references generalized (no hardcoded model names)
- Examples use generic `src/app/` paths

## [0.1.0] - 2026-02-04

### Added
- Initial template release
- **Core Orchestration**
  - Agent delegation system with hook enforcement
  - Cost-conscious routing (FREE local LLM -> PAID cloud APIs)
  - Session hygiene rules to prevent ghost code
- **Agents**
  - @local-coder: FREE code generation via Ollama
  - @code-sentinel: Multi-model security audit
  - @gemini-overseer: Single-model architecture review
  - @overseer: Multi-model panel (Gemini + OpenAI + Grok)
  - @debug: Deep-dive debugging with Ralph Wiggum pattern
  - @integration-check: Code wiring verification
  - @janitor: Codebase cleanup
- **Hook Dispatcher Pattern**
  - `.d/` directory structure for user extensions
  - Core hooks in numbered files (00-core-*.sh)
  - Custom hooks survive `copier update`
- **Secret Management**
  - `.env.template` with placeholder values
  - `bootstrap.sh` for first-time setup
  - Pre-commit secret scanning (detect-secrets)
- **Task System**
  - `tasks/master.md` backlog
  - `tasks/templates/` for task specs
  - Phase-based workflow (Planning -> Execution -> Completion)
- **Testing**
  - Smoke tests for template validation
  - Hook dispatcher tests
  - CI/CD workflow for GitHub Actions

### Known Limitations
- Bidirectional sync (project -> template) not yet implemented
- Some agents require paid API keys (Gemini, OpenAI, Grok)
- DevContainer not yet included

## [Unreleased]

### Planned
- Bidirectional sync support (`claude-template sync-up` CLI)
- Docker Compose for full stack
- DevContainer configuration
- More granular conditional rendering
- Skill templates
