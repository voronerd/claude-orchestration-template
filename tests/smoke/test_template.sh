#!/bin/bash
# tests/smoke/test_template.sh - Validate template produces working project

set -e

TEMPLATE_DIR="${TEMPLATE_DIR:-$(dirname "$0")/../..}"
TEST_DIR="${TEST_DIR:-/tmp/smoke-test-$$}"

echo "=== Smoke Test: Template Validation ==="
echo "   Template: $TEMPLATE_DIR"
echo "   Test dir: $TEST_DIR"
echo ""

# Cleanup on exit
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Test 1: Copier copy works
echo "1. Testing copier copy..."
copier copy "$TEMPLATE_DIR" "$TEST_DIR" \
    --trust \
    --data project_name=smoke-test \
    --data project_description="Smoke test project" \
    --data admin_username=testuser \
    --data has_local_llm=true \
    --data ollama_endpoint=http://localhost:11434 \
    --data primary_coding_model=codellama:7b \
    --data has_deployment_target=false \
    --data include_multi_model_overseer=false \
    --data include_grok_agent=false \
    --data include_debug_agent=true \
    --data include_ralph_plugin=false \
    --data include_integration_check=true \
    --data include_janitor=true \
    --data include_devcontainer=false \
    --data include_pre_commit=true \
    --data enable_task_system=true \
    --data enable_cost_tracking=true \
    --data existing_project=false \
    --data customize_agents=false

[[ -f "$TEST_DIR/CLAUDE.md" ]] || { echo "FAIL: Project files not created"; exit 1; }
echo "   OK: Project created"

cd "$TEST_DIR"

# Test 2: Required files exist
echo "2. Checking required files..."
required_files=(
    "CLAUDE.md"
    ".claude/settings.json"
    ".claude/agents/local-coder.md"
    ".claude/agents/code-sentinel.md"
    ".claude/agents/gemini-overseer.md"
    ".claude/agents/debug.md"
    ".claude/agents/doctor.md"
    ".claude/agents/tester.md"
    ".claude/agents/reviewer.md"
    ".claude/agents/integration-check.md"
    ".claude/agents/janitor.md"
    ".claude/hooks/pre-tool-use.sh"
    ".env.template"
    "scripts/bootstrap.sh"
    "tasks/templates/task_spec.md"
    ".gitignore"
)

for file in "${required_files[@]}"; do
    [[ -f "$file" ]] || { echo "FAIL: Missing: $file"; exit 1; }
done
echo "   OK: All required files present"

# Test 3: Jinja2 substitution worked
echo "3. Verifying variable substitution..."
if grep -q "{{ project_name }}" CLAUDE.md; then
    echo "FAIL: Unsubstituted Jinja2 variable in CLAUDE.md"
    exit 1
fi
if grep -q "smoke-test" CLAUDE.md; then
    echo "   OK: Project name substituted correctly"
else
    echo "FAIL: Project name not found in CLAUDE.md"
    exit 1
fi

# Test 3b: Verify agent templates rendered correctly
echo "3b. Verifying agent template rendering..."
jinja_agents=(debug doctor tester reviewer integration-check janitor)
for agent in "${jinja_agents[@]}"; do
    agent_file=".claude/agents/${agent}.md"

    # Verify placeholder was substituted
    if grep -q '{{ primary_coding_model }}' "$agent_file" 2>/dev/null; then
        echo "FAIL: Unsubstituted variable in $agent_file"
        exit 1
    fi
done
echo "   OK: Agent templates rendered correctly"

# Test 4: Settings JSON is valid
echo "4. Validating settings.json..."
if ! jq . .claude/settings.json > /dev/null 2>&1; then
    echo "FAIL: settings.json is not valid JSON"
    exit 1
fi
echo "   OK: settings.json is valid JSON"

# Test 5: Scripts are executable
echo "5. Checking script permissions..."
[[ -x "scripts/bootstrap.sh" ]] || { echo "FAIL: bootstrap.sh not executable"; exit 1; }
[[ -x ".claude/hooks/pre-tool-use.sh" ]] || { echo "FAIL: pre-tool-use.sh not executable"; exit 1; }
echo "   OK: Scripts are executable"

# Test 6: Gitignore configured
echo "6. Checking .gitignore..."
grep -q "^\.env$" .gitignore || { echo "FAIL: .env not in .gitignore"; exit 1; }
echo "   OK: Gitignore configured correctly"

# Test 7: Hook dispatchers exist
echo "7. Checking hook dispatchers..."
dispatchers=(
    ".claude/hooks/pre-tool-use.sh"
    ".claude/hooks/post-tool-use.sh"
    ".claude/hooks/subagent-stop.sh"
    ".claude/hooks/user-prompt-submit.sh"
)
for d in "${dispatchers[@]}"; do
    [[ -f "$d" ]] || { echo "FAIL: Missing dispatcher: $d"; exit 1; }
done
echo "   OK: All dispatchers present"

# Test 8: Scan for forbidden/leaked patterns
echo "8. Scanning for forbidden patterns..."
forbidden_patterns=(
    "@clawdbot"
    "\.clawdbot"
    "CLAWDBOT_HOME"
    "XAI_API_KEY"
)

for pattern in "${forbidden_patterns[@]}"; do
    if grep -rE "$pattern" . --include="*.md" --include="*.sh" --include="*.json" 2>/dev/null | grep -v ".git" | grep -v ".copier-answers"; then
        echo "FAIL: Forbidden pattern '$pattern' found in output"
        exit 1
    fi
done
echo "   OK: No forbidden patterns detected"

# Test 9: Verify .env.template uses GROK_API_KEY not XAI_API_KEY
echo "9. Checking .env.template key names..."
if grep -q "XAI_API_KEY" .env.template 2>/dev/null; then
    echo "FAIL: .env.template uses XAI_API_KEY (should be GROK_API_KEY)"
    exit 1
fi
echo "   OK: Environment variable names correct"

echo ""
echo "=== All smoke tests passed! ==="
