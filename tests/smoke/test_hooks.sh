#!/bin/bash
# tests/smoke/test_hooks.sh - Validate hook dispatcher pattern

set -e

TEMPLATE_DIR="${TEMPLATE_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
TEST_DIR="${TEST_DIR:-/tmp/hooks-test-$$}"

# Ensure copier is on PATH
if ! command -v copier &> /dev/null; then
    COPIER_PATH="$TEMPLATE_DIR/../.venv/bin/copier"
    if [[ ! -x "$COPIER_PATH" ]]; then
        COPIER_PATH="$HOME/.local/bin/copier"
        if [[ ! -x "$COPIER_PATH" ]]; then
            echo "Error: copier not found on PATH, in $TEMPLATE_DIR/../.venv/bin, or in $HOME/.local/bin"
            exit 2
        fi
    fi
    export PATH="$(dirname "$COPIER_PATH"):$PATH"
fi

# Cleanup on exit
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "=== Smoke Test: Hook Dispatchers ==="
echo ""

if [[ -z "$1" ]]; then
    echo "   Generating project from template..."
    echo "   Template: $TEMPLATE_DIR"
    echo "   Test dir: $TEST_DIR"
    copier copy "$TEMPLATE_DIR" "$TEST_DIR" \
        --trust \
        --defaults \
        --data project_name=hooks-test \
        --data project_description="Hook dispatcher test project" \
        --data admin_username=testuser \
        --data has_local_llm=true \
        --data ollama_endpoint=http://localhost:11434 \
        --data primary_coding_model=codellama:7b \
        --data include_multi_model_overseer=false \
        --data include_debug_agent=true \
        --data include_integration_check=true \
        --data include_janitor=true \
        --data include_devcontainer=false \
        --data include_pre_commit=false \
        --data enable_task_system=true \
        --data enable_cost_tracking=true \
        --data existing_project=false \
        --data customize_agents=false \
        --data include_grok_agent=false \
        --data has_deployment_target=false
    PROJECT_DIR="$TEST_DIR"
    echo "   OK: Project generated"
else
    PROJECT_DIR="$1"
    echo "   Using existing project: $PROJECT_DIR"
fi

cd "$PROJECT_DIR"

# Test 1: Dispatcher scripts exist and are executable
echo "1. Checking dispatcher scripts..."
dispatchers=(
    ".claude/hooks/dispatcher-pre-tool-use.sh"
    ".claude/hooks/dispatcher-post-tool-use.sh"
    ".claude/hooks/dispatcher-subagent-stop.sh"
    ".claude/hooks/dispatcher-user-prompt-submit.sh"
    ".claude/hooks/dispatcher-session-start.sh"
)

for dispatcher in "${dispatchers[@]}"; do
    [[ -f "$dispatcher" ]] || { echo "FAIL: Missing: $dispatcher"; exit 1; }
    [[ -x "$dispatcher" ]] || { echo "FAIL: Not executable: $dispatcher"; exit 1; }
done
echo "   OK: All dispatchers present and executable"

# Test 2: Atomic hook scripts exist
echo "2. Checking atomic hook scripts..."
atomic_hooks=(
    ".claude/hooks/security-gate.sh"
    ".claude/hooks/enforce-delegation.sh"
    ".claude/hooks/enforce-delegation-bash.sh"
    ".claude/hooks/route-task.sh"
    ".claude/hooks/log-edit.sh"
)

for hook in "${atomic_hooks[@]}"; do
    [[ -f "$hook" ]] || { echo "FAIL: Missing atomic hook: $hook"; exit 1; }
done
echo "   OK: Atomic hook scripts present"

# Test 3: Atomic hooks are executable
echo "3. Checking atomic hooks are executable..."
for hook in "${atomic_hooks[@]}"; do
    [[ -x "$hook" ]] || { echo "FAIL: Not executable: $hook"; exit 1; }
done
echo "   OK: Atomic hooks are executable"

# Test 4: Hook execution - verify dispatcher routes and executes hooks
echo "4. Testing hook execution with realistic input..."

# Create agent-usage.log so enforce-delegation passes
echo "local-coder" > agent-usage.log

set +e
output=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"README.md"}}' | .claude/hooks/dispatcher-pre-tool-use.sh 2>&1)
exit_code=$?
set -e

# Clean up
rm -f agent-usage.log

if [[ $exit_code -ne 0 ]]; then
    echo "FAIL: dispatcher-pre-tool-use.sh exited with code $exit_code on valid Edit input"
    exit 1
fi
if [[ -z "$output" ]]; then
    echo "FAIL: dispatcher-pre-tool-use.sh produced no output"
    exit 1
fi
echo "   OK: Dispatcher routes Edit tool through hooks correctly"

# Test 5: Dispatcher exits cleanly with empty JSON input
echo "5. Testing dispatcher exit code with empty input..."
set +e
echo '{}' | .claude/hooks/dispatcher-pre-tool-use.sh > /dev/null 2>&1
exit_code=$?
set -e

if [[ $exit_code -ne 0 ]]; then
    echo "FAIL: Dispatcher exited non-zero ($exit_code) on empty input"
    exit 1
fi
echo "   OK: Dispatcher exits cleanly with empty input"

echo ""
echo "=== All hook tests passed! ==="
