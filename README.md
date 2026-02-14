# Claude Code Orchestration Template

A portable template for Claude Code projects with agent delegation, cost-conscious routing, and multi-model review capabilities.

Note that this work is derivative of https://github.com/glittercowboy/taches-cc-resources and credit goes to the cowboy's input as a starting point.

---

## 📖 Start Here: Prompt Examples

**Before diving into setup, read [docs/PROMPT-EXAMPLES.md](docs/PROMPT-EXAMPLES.md).**

This document shows you **how to actually use the system** with real-world examples:

| Section | What You'll Learn |
|---------|-------------------|
| **Core Workflow** | The `create-task → create-prompt → run-prompt` pipeline that drives all work |
| **Planning** | How to create development plans, research plans, and investigation plans |
| **Context Shedding** | Why subagents matter and how they save 99% of context window |
| **Agent Use Cases** | When to use @overseer, @doctor, @debug, @code-sentinel, etc. |
| **Collaboration** | How agents work together, escalate, and call each other |

**Why read it first?**
- The template enforces a delegation-first workflow - you need to understand *why*
- Knowing the patterns prevents fighting the system
- Real invocation examples (`"@overseer, review this architecture"`) show natural usage

---

## Quick Start

```bash
# Clone and run setup
git clone https://github.com/voronerd/claude-orchestration-template.git
cd claude-orchestration-template
./setup.sh
source ~/.bashrc

# Create your project
copier copy . ~/my-project --trust
cd ~/my-project
./scripts/bootstrap.sh

# Start Claude Code
claude
```

### Important: .env File Location

**BEFORE running copier**, you must have a `.env` file in one of these locations:
1. **Inside the template directory**: `~/claude-orchestration-template/.env` (recommended)
2. **Your home directory**: `~/.env` (fallback)

The template needs to read your API keys during project generation.

**If updating an existing project:**
- Answer "Yes" to "Updating an existing project?" to skip infrastructure questions
- Your existing `.env` in the target project will be preserved

**If creating a new project:**
- Answer "No" to configure infrastructure from scratch
- The bootstrap script will create `.env` from `.env.template`

---

Type in "run onboarding" to kick off interactive setup.

That's it. The `setup.sh` script installs prerequisites (pipx, copier, etc.) and the `bootstrap.sh` sets up your project.

## Prerequisites & Infrastructure

### Required

| Requirement | Purpose |
|-------------|---------|
| [Claude Code CLI](https://claude.ai/code) | Core AI assistant (includes API access) |
| Python 3.10+ | Bootstrap scripts |
| Bash shell | Hook execution (Linux/macOS/WSL2) |

Note: Claude Code already has your Anthropic API key configured - no additional setup needed.

### Optional Infrastructure

The template supports additional infrastructure for enhanced capabilities:

| Infrastructure | Required For | Setup Complexity |
|----------------|--------------|------------------|
| **Ollama** | @local-coder, @lite-general, @local-git (FREE local LLM) | Low - `curl -fsSL https://ollama.ai/install.sh \| sh` |
| **Gemini API** | @gemini-overseer, multi-model review | Low - API key only |
| **OpenAI API** | @openai-overseer, multi-model review | Low - API key only |
| **xAI/Grok API** | @grok agent in review panel | Low - API key only |

### Cost Tiers

The template routes work through a cost-conscious waterfall:

```
Tier 0 (FREE): Local Ollama models (qwen2.5-coder, etc.)
    ↓ if unavailable
Tier 1 (PAID): Claude Haiku for simple tasks
    ↓ if complex
Tier 2 (PAID): Claude Sonnet/Opus for complex tasks
```

**Without Ollama:** All coding tasks use Claude API (higher cost)
**With Ollama:** Most coding tasks use local GPU (zero cloud cost)

### Platform Notes

| Platform | Status | Notes |
|----------|--------|-------|
| Linux | ✅ Full support | Native |
| macOS | ✅ Full support | Native |
| Windows | ⚠️ WSL2 required | Hooks are bash scripts |
| Docker | ✅ DevContainer | Included if enabled |

## What's Included

### Core Features

- **Agent Delegation System**: Enforces code delegation to specialized agents
- **Hook Enforcement**: PreToolUse/PostToolUse hooks for safety and tracking
- **Cost-Conscious Routing**: Waterfall from FREE (local LLM) to PAID (cloud APIs)
- **Session Hygiene**: Prevents ghost code and context rot

### Agents (Conditional)

| Agent | Included By Default | Purpose |
|-------|---------------------|---------|
| @local-coder | If `has_local_llm` | FREE code generation via Ollama |
| @debug | Yes | Deep-dive debugging with test loops |
| @integration-check | Yes | Verify code wiring |
| @janitor | Yes | Codebase cleanup |
| @overseer | If `include_multi_model_overseer` | Multi-model architecture review |
| @code-sentinel | Yes | Security audit |

### Optional Features

- DevContainer configuration
- Pre-commit hooks for secret scanning
- Task management system

## Configuration

During `copier copy`, you'll be asked about:

### Required
- `project_name`: Your project identifier
- `project_description`: Brief description
- `admin_username`: Primary admin user

### Infrastructure
- `has_local_llm`: Do you have Ollama/vLLM?
- `ollama_endpoint`: URL for local LLM
### Features
- `include_multi_model_overseer`: Enable Gemini + OpenAI + Grok panel?
- `include_debug_agent`: Include @debug agent?
- `include_devcontainer`: Include DevContainer?
- `enable_cost_tracking`: Track API costs?

## Onboarding Guide

After running `copier copy`, follow these steps:

### Step 1: Navigate and Bootstrap

```bash
cd my-new-project
./scripts/bootstrap.sh
```

The bootstrap script will:
- Set up your `.env` file
- Offer to install the `cc` alias for `claude`
- Make hooks executable

### Step 2: Initialize Git

```bash
git init
git add .
git commit -m "Initial project from claude-orchestration-template"
```

### Step 3: Start Claude Code

```bash
cc  # or 'claude'
```

On first run, you'll see the **interactive onboarding** prompt. Say `/onboard` to:
1. Set up local LLM (Ollama) if available
2. Describe your project
4. Generate an initial plan

### Optional: Enhanced Features

For multi-model code review, add these to `.env`:

| Key | Where to Get It | Purpose |
|-----|-----------------|---------|
| `GEMINI_API_KEY` | [aistudio.google.com](https://aistudio.google.com/apikey) | @gemini-overseer |
| `OPENAI_API_KEY` | [platform.openai.com](https://platform.openai.com/api-keys) | @openai-overseer |

### Optional: Local LLM (Ollama)

For FREE code generation instead of using Claude API:

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull coding model
ollama pull <your-preferred-model>  # e.g., qwen2.5-coder:32b, codellama:34b
```

### Setup Comparison

| Setup | Cost | What You Get |
|-------|------|--------------|
| **Minimal** | Claude API only | Works out of the box |
| **With Ollama** | FREE coding | Local LLM handles code generation |
| **Full** | Multi-model | Gemini + OpenAI for reviews |

### Troubleshooting

| Issue | Solution |
|-------|----------|
| Hooks not firing | `chmod +x .claude/hooks/*.sh` |
| Git auth prompts | `gh auth login && gh auth setup-git` |
| Ollama not connecting | `ollama serve` |

## Updating from Template

### Standard Update (copier-created projects)

If your project was created with `copier copy`, updating is straightforward:

```bash
cd my-project
copier update --trust
```

Review changes, then commit:

```bash
git diff                    # Review what changed
git add -A && git commit -m "chore: copier update from template"
```

### Adopting an Existing Project

If your project was set up manually (not via `copier copy`), you can retroactively adopt it for future template updates:

1. **Create `.copier-answers.yml`** in your project root:

```yaml
# Changes here will be overwritten by Copier; NEVER EDIT MANUALLY
_commit: <latest-template-commit-hash>
_src_path: gh:voronerd/claude-orchestration-template
_vcs_ref: <latest-template-commit-hash>
project_name: my-project
project_description: "My project description"
admin_username: myuser
existing_project: true
customize_agents: false
```

2. **Get the latest template commit hash:**

```bash
git ls-remote https://github.com/voronerd/claude-orchestration-template.git HEAD
```

3. **Commit the answers file** (copier requires a clean repo):

```bash
git add .copier-answers.yml
git commit -m "chore: add copier answers for template sync"
```

4. **Run the update:**

```bash
copier update --trust --defaults
```

The `--defaults` flag accepts all default answers without prompting. Drop it if you want to reconfigure options interactively.

### What's Preserved During Updates

Copier will never overwrite these user-owned files:

| Path | Contents |
|------|----------|
| `tasks/detail/*`, `tasks/done/*` | Your active and completed tasks |
| `tasks/master.md`, `tasks/pipelines/*` | Your task dashboard and backlogs |
| `.env`, `*.age`, `secrets.yaml` | Your secrets and credentials |
| `.claude/.state/*` | Session state files |
| `.vscode/settings.json` | Your IDE settings |

### Handling Conflicts

If copier detects conflicts between your local changes and template updates:

- **Agent files** (`.claude/agents/*.md`): Template wins — your local customizations should go in project-specific overrides, not agent files
- **Hook scripts** (`.claude/hooks/*.sh`): Template wins for core hooks; put custom logic in `.d/` extension directories
- **CLAUDE.md**: Template provides the base; add project-specific sections below the generated content
- **Skills/commands**: New skills are added; existing ones are updated

If you need to keep local modifications to a template-managed file, consider opening a PR to make the template more configurable instead.

## Extending Hooks

Add custom hooks without modifying template-managed files:

```bash
# Create extension directory
mkdir -p .claude/hooks/pre-tool-use.d

# Add your custom hook (numbered for ordering)
cat > .claude/hooks/pre-tool-use.d/50-my-custom.sh << 'EOF'
#!/bin/bash
# Your custom logic here
echo "Custom hook fired" >&2
exit 0
EOF
chmod +x .claude/hooks/pre-tool-use.d/50-my-custom.sh
```

Hooks in `.d/` directories are run by the dispatcher in numeric order.

## Project Structure

```
my-new-project/
├── .claude/
│   ├── settings.json      # Hook configuration
│   ├── agents/            # Subagent definitions
│   ├── skills/            # Custom skills
│   └── hooks/             # Enforcement hooks
│       ├── enforce-delegation.sh   # Template-managed
│       └── pre-tool-use.d/         # Your extensions
├── docs/
│   ├── PROMPT-EXAMPLES.md # ⭐ Real-world usage examples (START HERE)
│   ├── WORKFLOW.md        # Daily workflow guide
│   └── CATALOGUE.md       # Agent and skill catalogue
├── tasks/
│   ├── master.md          # Task dashboard (priorities, status)
│   ├── pipelines/         # Pipeline-specific backlogs
│   ├── detail/            # Active task specs
│   ├── done/              # Completed tasks
│   └── templates/         # Task templates
├── scripts/
│   └── bootstrap.sh       # First-time setup
├── .env.template          # Secret placeholders
├── .gitignore
├── CLAUDE.md              # Project instructions
└── README.md
```

## Plan Execution & Resume

Plans are executed via `/run-plan <path-to-PLAN.md>`. The skill supports interruption and cross-session resume.

### How It Works

During execution, a `.progress.json` file is written alongside the plan after each task completes:

```json
{
  "plan": "04-01-PLAN.md",
  "started": "2026-02-14T10:00:00Z",
  "tasks_completed": ["Task 1: Create config schema", "Task 2: Add validation"],
  "last_completed": "Task 2: Add validation",
  "status": "in_progress"
}
```

### Resuming an Interrupted Plan

When you invoke `/run-plan` on a plan that was previously interrupted:

1. **Auto-detection**: The skill checks for `.progress.json` in the plan directory
2. **Status display**: Shows completed vs remaining tasks
3. **User choice**: Resume from where you left off, restart from scratch, or abort
4. **Selective execution**: Only remaining tasks are delegated to subagents

### Optional: whats-next.md Context

If you ran `/whats-next` before ending the previous session and the resulting `whats-next.md` is in the plan directory, the resume will also ingest the `<work_remaining>` and `<critical_context>` sections. This provides error history, decisions made, and failed approaches from the previous attempt without flooding the context window.

### Artifact Lifecycle

| Artifact | Created | Consumed | Cleaned Up |
|----------|---------|----------|------------|
| `.progress.json` | During execution (per task) | On resume | Deleted on successful completion |
| `whats-next.md` | Manually via `/whats-next` | On resume (optional) | Not auto-deleted |
| `SUMMARY.md` | On plan completion | By downstream plans | Never (permanent record) |

## Documentation

| Document | Purpose |
|----------|---------|
| **[docs/PROMPT-EXAMPLES.md](docs/PROMPT-EXAMPLES.md)** | Real invocation examples, agent patterns, workflow tutorials |
| [docs/WORKFLOW.md](docs/WORKFLOW.md) | Daily workflow, delegation patterns, session hygiene |
| [docs/CATALOGUE.md](docs/CATALOGUE.md) | Complete agent and skill reference |
| [CLAUDE.md](CLAUDE.md) | Project-specific instructions for Claude |

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the template repository
2. Make your changes
3. Test with `copier copy ./template /tmp/test-project --trust`
4. Submit a pull request
