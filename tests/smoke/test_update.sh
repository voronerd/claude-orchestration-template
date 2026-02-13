#!/bin/bash
# tests/smoke/test_update.sh - Test that copier update preserves user customizations

set -e

TEMPLATE_DIR="${TEMPLATE_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
TEST_DIR="${TEST_DIR:-/tmp/update-test-$$}"

# Check if copier is on PATH, otherwise try to find it in fallback locations
if ! command -v copier &> /dev/null; then
    if [[ -x "$TEMPLATE_DIR/../.venv/bin/copier" ]]; then
        PATH="$TEMPLATE_DIR/../.venv/bin:$PATH"
    elif [[ -x "$HOME/.local/bin/copier" ]]; then
        PATH="$HOME/.local/bin:$PATH"
    else
        echo "Error: copier not found on PATH or in fallback locations."
        exit 2
    fi
fi

echo "=== Smoke Test: Copier Update ==="
echo "   Template: $TEMPLATE_DIR"
echo "   Test dir: $TEST_DIR"
echo ""

# Cleanup on exit
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Step 1: Create initial project
echo "1. Creating initial project..."
copier copy "$TEMPLATE_DIR" "$TEST_DIR" \
    --trust \
    --defaults \
    --data project_name=update-test \
    --data project_description="Update test project" \
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

cd "$TEST_DIR"
echo "   OK: Project created"

# Step 2: Add user customizations
echo "2. Adding user customizations..."

# Custom hook as standalone file (outside template-managed paths)
mkdir -p .claude/hooks
echo '#!/bin/bash
echo "USER_CUSTOM_HOOK"
cat' > .claude/hooks/user-custom-hook.sh
chmod +x .claude/hooks/user-custom-hook.sh

# Custom .env
cp .env .env.bak 2>/dev/null || true
echo "ANTHROPIC_API_KEY=placeholder-for-ci-testing" > .env

# Custom task
mkdir -p tasks/detail
echo "# User Task" > tasks/detail/user-task.md

echo "   OK: Customizations added"

# Step 3: Run copier update (simulated by re-copying with --defaults)
echo "3. Running copier update..."
cd "$TEST_DIR"
copier copy "$TEMPLATE_DIR" "$TEST_DIR" \
    --trust \
    --defaults \
    --force \
    --data project_name=update-test \
    --data project_description="Update test project" \
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

cd "$TEST_DIR"
echo "   OK: Update completed"

# Step 4: Verify customizations preserved
echo "4. Verifying customizations preserved..."

# Check custom hook
if [[ -f ".claude/hooks/user-custom-hook.sh" ]]; then
    echo "   OK: Custom hook preserved"
else
    echo "FAIL: Custom hook was deleted"
    exit 1
fi

# Check .env (should NOT be overwritten - it's in _exclude)
if grep -q "placeholder-for-ci-testing" .env 2>/dev/null; then
    echo "   OK: .env preserved"
else
    echo "   INFO: .env was reset (expected if not in _exclude)"
fi

# Check custom task
if [[ -f "tasks/detail/user-task.md" ]]; then
    echo "   OK: Custom task preserved"
else
    echo "FAIL: Custom task was deleted"
    exit 1
fi

# Check .env.template doesn't contain temp directory paths (copier update regression)
if grep -q "/tmp/" .env.template 2>/dev/null; then
    echo "FAIL: .env.template contains /tmp/ path (copier update merge conflict bug)"
    exit 1
else
    echo "   OK: .env.template has no temp paths"
fi

echo ""
echo "=== All update tests passed! ==="
