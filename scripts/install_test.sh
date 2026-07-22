#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Kurama — Install Script Tests
# Run: bash scripts/install_test.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
SETUP_SCRIPT="$SCRIPT_DIR/setup.sh"
UNINSTALL_SCRIPT="$SCRIPT_DIR/uninstall.sh"
MANIFEST_FILE="$REPO_DIR/skills/manifest.json"

# ============================================================================
# Test state
# ============================================================================

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILURES=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
# shellcheck disable=SC2034  # kept for a complete color palette
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# All 25 expected default skills (sdd-core + quality + review + optional + tdd).
# The tdd and kanban-github modules ship by default now; installing either does NOT
# activate it (TDD stays opt-in per project; the kanban board stays opt-in via
# kanban.enabled and requires a configured gh — never probed here).
EXPECTED_SKILLS=(
    sdd-apply
    sdd-archive
    sdd-design
    sdd-explore
    sdd-init
    sdd-propose
    sdd-spec
    sdd-tasks
    sdd-verify
    sdd-new
    sdd-continue
    sdd-ff
    skill-registry
    judgment-day
    review-risk
    review-readability
    review-reliability
    review-resilience
    review-refuter
    go-testing
    kanban-github
    tdd
    skill-creator
    branch-pr
    issue-creation
)

# ============================================================================
# Test helpers
# ============================================================================

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export HOME="$TEST_TMPDIR/home"
    mkdir -p "$HOME"
    # Fake Windows-style env vars for cross-platform path tests
    export USERPROFILE="$TEST_TMPDIR/home"
    export APPDATA="$TEST_TMPDIR/appdata"
    mkdir -p "$APPDATA"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-}"
    if [[ "$expected" == "$actual" ]]; then
        return 0
    fi
    echo "  Expected: $expected"
    echo "  Actual:   $actual"
    [[ -n "$msg" ]] && echo "  Message:  $msg"
    return 1
}

assert_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        return 0
    fi
    echo "  File not found: $file"
    return 1
}

assert_dir_exists() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        return 0
    fi
    echo "  Directory not found: $dir"
    return 1
}

assert_file_not_empty() {
    local file="$1"
    local min_bytes="${2:-100}"
    if [[ ! -f "$file" ]]; then
        echo "  File not found: $file"
        return 1
    fi
    local size
    size=$(wc -c < "$file" | tr -d ' ')
    if [[ "$size" -lt "$min_bytes" ]]; then
        echo "  File too small: $file ($size bytes, expected >= $min_bytes)"
        return 1
    fi
    return 0
}

assert_all_skills_installed() {
    local base_dir="$1"
    for skill in "${EXPECTED_SKILLS[@]}"; do
        assert_dir_exists "$base_dir/$skill" || return 1
        assert_file_exists "$base_dir/$skill/SKILL.md" || return 1
        assert_file_not_empty "$base_dir/$skill/SKILL.md" || return 1
    done
    return 0
}

run_test() {
    local name="$1"
    local func="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    setup
    echo -n "  $name ... "
    local output
    if output=$($func 2>&1); then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}"
        if [[ -n "$output" ]]; then
            printf '%s\n' "$output" | awk '{ print "    " $0 }'
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILURES="$FAILURES\n  - $name"
    fi
    teardown
}

# ============================================================================
# Tests — Help & Error Handling
# ============================================================================

test_help_flag() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --help 2>&1)
    echo "$output" | grep -q "Usage:" || { echo "Help output missing 'Usage:'"; return 1; }
    echo "$output" | grep -q "claude-code" || { echo "Help output missing 'claude-code'"; return 1; }
    echo "$output" | grep -q "opencode" || { echo "Help output missing 'opencode'"; return 1; }
    echo "$output" | grep -q "all-global" || { echo "Help output missing 'all-global'"; return 1; }
    echo "$output" | grep -q "\-\-agent" || { echo "Help output missing '--agent'"; return 1; }
    echo "$output" | grep -q "\-\-path" || { echo "Help output missing '--path'"; return 1; }
}

test_help_exits_zero() {
    bash "$INSTALL_SCRIPT" --help > /dev/null 2>&1
    # If we get here, exit code was 0
    return 0
}

test_invalid_agent() {
    if bash "$INSTALL_SCRIPT" --agent nonexistent > /dev/null 2>&1; then
        echo "Expected non-zero exit for invalid agent, but got 0"
        return 1
    fi
    return 0
}

test_invalid_option() {
    if bash "$INSTALL_SCRIPT" --bogus-flag > /dev/null 2>&1; then
        echo "Expected non-zero exit for unknown option, but got 0"
        return 1
    fi
    return 0
}

# ============================================================================
# Tests — Claude Code
# ============================================================================

test_install_claude_code() {
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.claude/skills"
}

test_claude_code_skill_count() {
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    local count
    count=$(find "$HOME/.claude/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "Expected exactly 25 skills for Claude Code"
}

# ============================================================================
# Tests — OpenCode
# ============================================================================

test_install_opencode() {
    bash "$INSTALL_SCRIPT" --agent opencode > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.config/opencode/skills"
}

test_opencode_skill_count() {
    bash "$INSTALL_SCRIPT" --agent opencode > /dev/null 2>&1
    local count
    count=$(find "$HOME/.config/opencode/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "Expected exactly 25 skills for OpenCode"
}

test_opencode_commands() {
    bash "$INSTALL_SCRIPT" --agent opencode > /dev/null 2>&1
    local commands_dir="$HOME/.config/opencode/commands"
    assert_dir_exists "$commands_dir" || return 1
    assert_file_exists "$commands_dir/sdd-init.md" || return 1
    assert_file_exists "$commands_dir/sdd-apply.md" || return 1
    assert_file_exists "$commands_dir/sdd-explore.md" || return 1
    assert_file_exists "$commands_dir/sdd-verify.md" || return 1
    assert_file_exists "$commands_dir/sdd-archive.md" || return 1
    assert_file_exists "$commands_dir/sdd-new.md" || return 1
    assert_file_exists "$commands_dir/sdd-ff.md" || return 1
    assert_file_exists "$commands_dir/sdd-continue.md" || return 1
    local count
    count=$(find "$commands_dir" -name "sdd-*.md" | wc -l | tr -d ' ')
    assert_eq "8" "$count" "Expected exactly 8 OpenCode commands"
}

# ============================================================================
# Tests — Gemini CLI
# ============================================================================

test_install_gemini_cli() {
    bash "$INSTALL_SCRIPT" --agent gemini-cli > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.gemini/skills"
}

test_gemini_cli_skill_count() {
    bash "$INSTALL_SCRIPT" --agent gemini-cli > /dev/null 2>&1
    local count
    count=$(find "$HOME/.gemini/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "Expected exactly 25 skills for Gemini CLI"
}

# ============================================================================
# Tests — Codex
# ============================================================================

test_install_codex() {
    bash "$INSTALL_SCRIPT" --agent codex > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.codex/skills"
}

test_codex_skill_count() {
    bash "$INSTALL_SCRIPT" --agent codex > /dev/null 2>&1
    local count
    count=$(find "$HOME/.codex/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "Expected exactly 25 skills for Codex"
}

# ============================================================================
# Tests — VS Code (Copilot, global ~/.copilot/skills)
# ============================================================================

test_install_vscode() {
    bash "$INSTALL_SCRIPT" --agent vscode > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.copilot/skills"
}

test_vscode_skill_count() {
    bash "$INSTALL_SCRIPT" --agent vscode > /dev/null 2>&1
    local count
    count=$(find "$HOME/.copilot/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "Expected exactly 25 skills for VS Code"
}

# ============================================================================
# Tests — Antigravity (~/.gemini/antigravity/skills/)
# ============================================================================

test_install_antigravity() {
    bash "$INSTALL_SCRIPT" --agent antigravity > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.gemini/antigravity/skills"
}

test_antigravity_skill_count() {
    bash "$INSTALL_SCRIPT" --agent antigravity > /dev/null 2>&1
    local count
    count=$(find "$HOME/.gemini/antigravity/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "Expected exactly 25 skills for Antigravity"
}

# ============================================================================
# Tests — Cursor
# ============================================================================

test_install_cursor() {
    bash "$INSTALL_SCRIPT" --agent cursor > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.cursor/skills"
}

test_cursor_skill_count() {
    bash "$INSTALL_SCRIPT" --agent cursor > /dev/null 2>&1
    local count
    count=$(find "$HOME/.cursor/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "Expected exactly 25 skills for Cursor"
}

# ============================================================================
# Tests — Project-local
# ============================================================================

test_install_project_local() {
    local project="$TEST_TMPDIR/local-project"
    mkdir -p "$project"
    (cd "$project" && bash "$INSTALL_SCRIPT" --agent project-local > /dev/null 2>&1)
    assert_all_skills_installed "$project/skills"
}

test_project_local_skill_count() {
    local project="$TEST_TMPDIR/local-project"
    mkdir -p "$project"
    (cd "$project" && bash "$INSTALL_SCRIPT" --agent project-local > /dev/null 2>&1)
    local count
    count=$(find "$project/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "Expected exactly 25 skills for project-local"
}

# ============================================================================
# Tests — Custom path
# ============================================================================

test_custom_path() {
    local custom="$TEST_TMPDIR/custom-skills"
    bash "$INSTALL_SCRIPT" --agent custom --path "$custom" > /dev/null 2>&1
    assert_all_skills_installed "$custom"
}

test_custom_path_skill_count() {
    local custom="$TEST_TMPDIR/custom-skills"
    bash "$INSTALL_SCRIPT" --agent custom --path "$custom" > /dev/null 2>&1
    local count
    count=$(find "$custom" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "Expected exactly 25 skills for custom path"
}

# ============================================================================
# Tests — All-global
# ============================================================================

test_all_global() {
    bash "$INSTALL_SCRIPT" --agent all-global > /dev/null 2>&1
    # Claude Code
    assert_all_skills_installed "$HOME/.claude/skills" || return 1
    # OpenCode
    assert_all_skills_installed "$HOME/.config/opencode/skills" || return 1
    # Gemini CLI
    assert_all_skills_installed "$HOME/.gemini/skills" || return 1
    # Codex
    assert_all_skills_installed "$HOME/.codex/skills" || return 1
    # Cursor
    assert_all_skills_installed "$HOME/.cursor/skills" || return 1
}

test_all_global_total_skill_count() {
    bash "$INSTALL_SCRIPT" --agent all-global > /dev/null 2>&1
    # 5 targets x 25 skills = 125 SKILL.md files
    local total=0
    for dir in \
        "$HOME/.claude/skills" \
        "$HOME/.config/opencode/skills" \
        "$HOME/.gemini/skills" \
        "$HOME/.codex/skills" \
        "$HOME/.cursor/skills"; do
        local count
        count=$(find "$dir" -name "SKILL.md" | wc -l | tr -d ' ')
        assert_eq "25" "$count" "Expected 25 skills in $dir" || return 1
        total=$((total + count))
    done
    assert_eq "125" "$total" "Expected 125 total SKILL.md files across all targets"
}

test_all_global_opencode_commands() {
    bash "$INSTALL_SCRIPT" --agent all-global > /dev/null 2>&1
    local commands_dir="$HOME/.config/opencode/commands"
    assert_dir_exists "$commands_dir" || return 1
    local count
    count=$(find "$commands_dir" -name "sdd-*.md" | wc -l | tr -d ' ')
    assert_eq "8" "$count" "Expected 8 OpenCode commands with all-global"
}

# ============================================================================
# Tests — Idempotency
# ============================================================================

test_idempotent_claude_code() {
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.claude/skills"
    local count
    count=$(find "$HOME/.claude/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "Expected exactly 25 skills after double install"
}

test_idempotent_opencode() {
    bash "$INSTALL_SCRIPT" --agent opencode > /dev/null 2>&1
    bash "$INSTALL_SCRIPT" --agent opencode > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.config/opencode/skills" || return 1
    local skill_count
    skill_count=$(find "$HOME/.config/opencode/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$skill_count" "Expected exactly 25 skills after double install" || return 1
    local cmd_count
    cmd_count=$(find "$HOME/.config/opencode/commands" -name "sdd-*.md" | wc -l | tr -d ' ')
    assert_eq "8" "$cmd_count" "Expected exactly 8 commands after double install"
}

test_idempotent_all_global() {
    bash "$INSTALL_SCRIPT" --agent all-global > /dev/null 2>&1
    bash "$INSTALL_SCRIPT" --agent all-global > /dev/null 2>&1
    for dir in \
        "$HOME/.claude/skills" \
        "$HOME/.config/opencode/skills" \
        "$HOME/.gemini/skills" \
        "$HOME/.codex/skills" \
        "$HOME/.cursor/skills"; do
        local count
        count=$(find "$dir" -name "SKILL.md" | wc -l | tr -d ' ')
        assert_eq "25" "$count" "Expected 25 skills in $dir after double install" || return 1
    done
}

# ============================================================================
# Tests — Content integrity
# ============================================================================

test_skill_content_matches_source() {
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    local source_dir="$REPO_DIR/skills"
    for skill in "${EXPECTED_SKILLS[@]}"; do
        local src="$source_dir/$skill/SKILL.md"
        local dst="$HOME/.claude/skills/$skill/SKILL.md"
        if ! diff -q "$src" "$dst" > /dev/null 2>&1; then
            echo "Content mismatch: $skill/SKILL.md"
            echo "  Source: $src"
            echo "  Dest:   $dst"
            return 1
        fi
    done
    return 0
}

test_opencode_command_content_matches_source() {
    bash "$INSTALL_SCRIPT" --agent opencode > /dev/null 2>&1
    local source_dir="$REPO_DIR/examples/opencode/commands"
    local target_dir="$HOME/.config/opencode/commands"
    for cmd_file in "$source_dir"/sdd-*.md; do
        local name
        name=$(basename "$cmd_file")
        if ! diff -q "$cmd_file" "$target_dir/$name" > /dev/null 2>&1; then
            echo "Content mismatch: commands/$name"
            return 1
        fi
    done
    return 0
}

# ============================================================================
# Tests — Output verification
# ============================================================================

test_output_shows_skill_names() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --agent claude-code 2>&1)
    for skill in "${EXPECTED_SKILLS[@]}"; do
        echo "$output" | grep -q "$skill" || {
            echo "Output missing skill name: $skill"
            return 1
        }
    done
    return 0
}

test_output_shows_done_message() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --agent claude-code 2>&1)
    echo "$output" | grep -q "Done!" || {
        echo "Output missing 'Done!' message"
        return 1
    }
}

test_output_shows_install_count() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --agent claude-code 2>&1)
    echo "$output" | grep -q "25 skills installed" || {
        echo "Output missing '25 skills installed' message"
        return 1
    }
}

test_output_shows_next_step() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --agent claude-code 2>&1)
    echo "$output" | grep -q "Next step" || {
        echo "Output missing 'Next step' guidance"
        return 1
    }
}

test_output_shows_engram_note() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --agent claude-code 2>&1)
    echo "$output" | grep -q "Engram" || {
        echo "Output missing Engram recommendation"
        return 1
    }
}

# ============================================================================
# Tests — OS detection (limited — we can only test the current OS)
# ============================================================================

test_os_detection_runs() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --help 2>&1 || true)
    [[ -n "$output" ]] || { echo "No output from --help"; return 1; }
}

test_header_shows_detected_os() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --agent claude-code 2>&1)
    echo "$output" | grep -q "Detected:" || {
        echo "Output missing 'Detected:' OS label"
        return 1
    }
}

# ============================================================================
# Tests — Edge cases
# ============================================================================

test_pre_existing_dir_not_clobbered() {
    # Create a pre-existing file that should NOT be deleted
    mkdir -p "$HOME/.claude/skills/my-custom-skill"
    echo "custom content" > "$HOME/.claude/skills/my-custom-skill/SKILL.md"
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    # SDD skills should be installed
    assert_all_skills_installed "$HOME/.claude/skills" || return 1
    # Custom skill should still exist
    assert_file_exists "$HOME/.claude/skills/my-custom-skill/SKILL.md" || return 1
    local content
    content=$(cat "$HOME/.claude/skills/my-custom-skill/SKILL.md")
    assert_eq "custom content" "$content" "Custom skill content should be preserved"
}

test_overwrite_stale_skill() {
    # Pre-create a stale SKILL.md
    mkdir -p "$HOME/.claude/skills/sdd-apply"
    echo "stale" > "$HOME/.claude/skills/sdd-apply/SKILL.md"
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    # Should be replaced with actual content (not "stale")
    local content
    content=$(head -c 5 "$HOME/.claude/skills/sdd-apply/SKILL.md")
    if [[ "$content" == "stale" ]]; then
        echo "SKILL.md was NOT overwritten — still contains stale data"
        return 1
    fi
    assert_file_not_empty "$HOME/.claude/skills/sdd-apply/SKILL.md"
}

test_nested_custom_path() {
    local deep="$TEST_TMPDIR/a/b/c/d/skills"
    bash "$INSTALL_SCRIPT" --agent custom --path "$deep" > /dev/null 2>&1
    assert_all_skills_installed "$deep"
}

# ============================================================================
# Tests — setup.sh orchestrator safety (marker corruption / data loss)
# ============================================================================

test_setup_unbalanced_marker_aborts() {
    # A prompt file containing BEGIN without END (manual edit, merge conflict,
    # external tool) must NOT be truncated. setup.sh must abort (non-zero exit)
    # and leave the user's file byte-for-byte intact.
    mkdir -p "$HOME/.claude"
    local f="$HOME/.claude/CLAUDE.md"
    printf '%s\n' '# User config' \
        '<!-- BEGIN:kurama -->' \
        'stale orchestrator body' \
        'CRITICAL USER CONTENT AFTER BEGIN' > "$f"
    cp "$f" "$TEST_TMPDIR/claude.orig"

    if bash "$SETUP_SCRIPT" --agent claude-code > /dev/null 2>&1; then
        echo "Expected setup.sh to abort on unbalanced markers, but it exited 0"
        return 1
    fi

    grep -qF 'CRITICAL USER CONTENT AFTER BEGIN' "$f" || {
        echo "User content after BEGIN was lost"
        return 1
    }
    if ! cmp -s "$f" "$TEST_TMPDIR/claude.orig"; then
        echo "CLAUDE.md was modified despite the abort"
        return 1
    fi
    return 0
}

test_setup_balanced_marker_updates_and_backs_up() {
    # A balanced marker pair updates in place, preserves the surrounding user
    # content, stays idempotent, and writes a timestamped backup first.
    mkdir -p "$HOME/.claude"
    local f="$HOME/.claude/CLAUDE.md"
    printf '%s\n' '# Header' \
        '<!-- BEGIN:kurama -->' \
        'old body' \
        '<!-- END:kurama -->' \
        '# trailing user notes' > "$f"

    bash "$SETUP_SCRIPT" --agent claude-code > /dev/null 2>&1 || {
        echo "setup.sh failed on a balanced-marker update"
        return 1
    }

    grep -qF '# Header' "$f" || { echo "Header lost"; return 1; }
    grep -qF '# trailing user notes' "$f" || { echo "Trailing user notes lost"; return 1; }
    if grep -qF 'old body' "$f"; then
        echo "Old orchestrator body was not replaced"
        return 1
    fi

    local begin end
    begin=$(grep -c 'BEGIN:kurama' "$f")
    end=$(grep -c 'END:kurama' "$f")
    assert_eq "1" "$begin" "Exactly one BEGIN marker after update" || return 1
    assert_eq "1" "$end" "Exactly one END marker after update" || return 1

    local backups
    backups=$(find "$HOME/.claude" -name 'CLAUDE.md.bak.*' | wc -l | tr -d ' ')
    if [ "$backups" -lt 1 ]; then
        echo "No timestamped backup was created before rewriting"
        return 1
    fi
    return 0
}

# ============================================================================
# Tests — setup.sh manifest-driven install + receipt (parity with install.sh)
# ============================================================================

test_setup_installs_default_skill_set() {
    bash "$SETUP_SCRIPT" --agent claude-code > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.claude/skills" || return 1
    local count
    count=$(find "$HOME/.claude/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "setup.sh should install the 25 default skills"
}

test_setup_includes_tdd() {
    # setup.sh installs the default set, which now includes the tdd module.
    # Installing the module does NOT activate TDD — activation stays opt-in per
    # project.
    bash "$SETUP_SCRIPT" --agent claude-code > /dev/null 2>&1
    assert_dir_exists "$HOME/.claude/skills/tdd" || return 1
    assert_file_exists "$HOME/.claude/skills/tdd/SKILL.md" || return 1
    return 0
}

test_setup_writes_install_manifest() {
    # setup.sh installs must leave the same receipt install.sh does, so uninstall
    # works on the recommended (setup.sh) install path.
    bash "$SETUP_SCRIPT" --agent claude-code > /dev/null 2>&1
    local manifest="$HOME/.claude/skills/.kurama-install-manifest.json"
    assert_file_exists "$manifest" || return 1
    grep -q '"version"' "$manifest" || { echo "setup.sh install manifest missing version field"; return 1; }
    grep -q '"files"' "$manifest" || { echo "setup.sh install manifest missing files array"; return 1; }
    grep -q 'sdd-apply/SKILL.md' "$manifest" || { echo "setup.sh install manifest missing an installed skill path"; return 1; }
    return 0
}

test_setup_uninstall_round_trip() {
    # A setup.sh install must uninstall cleanly via uninstall.sh (receipt-driven),
    # while user-created skills survive.
    bash "$SETUP_SCRIPT" --agent claude-code > /dev/null 2>&1
    mkdir -p "$HOME/.claude/skills/my-custom"
    echo "keep me" > "$HOME/.claude/skills/my-custom/SKILL.md"

    bash "$UNINSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1

    if [ -d "$HOME/.claude/skills/sdd-apply" ]; then
        echo "sdd-apply should have been removed by uninstall after a setup.sh install"
        return 1
    fi
    if [ -f "$HOME/.claude/skills/.kurama-install-manifest.json" ]; then
        echo "install manifest should have been removed by uninstall"
        return 1
    fi
    assert_file_exists "$HOME/.claude/skills/my-custom/SKILL.md" || return 1
    local content
    content=$(cat "$HOME/.claude/skills/my-custom/SKILL.md")
    assert_eq "keep me" "$content" "User-created skill preserved through setup.sh-install uninstall"
}

test_setup_matches_manifest_default_set() {
    # setup.sh derives its skill list from skills/manifest.json (no hardcoded list):
    # the installed tree must equal install.sh's default tree exactly.
    bash "$SETUP_SCRIPT" --agent claude-code > /dev/null 2>&1
    local setup_list
    setup_list=$(find "$HOME/.claude/skills" -name SKILL.md | sed "s#$HOME/.claude/skills/##" | sort)

    # Fresh HOME for the install.sh reference tree.
    rm -rf "$HOME/.claude/skills"
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    local install_list
    install_list=$(find "$HOME/.claude/skills" -name SKILL.md | sed "s#$HOME/.claude/skills/##" | sort)

    assert_eq "$install_list" "$setup_list" "setup.sh and install.sh must install the same default skill set"
}

# ============================================================================
# Tests — installer references point to files that exist (opencode templates)
# ============================================================================

test_no_broken_opencode_json_reference() {
    # examples/opencode/opencode.json does not exist; the real templates are
    # opencode.single.json / opencode.multi.json. Neither installer may point at
    # the nonexistent template path.
    if grep -E 'examples[/\\]opencode[/\\]opencode\.json' \
        "$SCRIPT_DIR/install.sh" "$SCRIPT_DIR/install.ps1" > /dev/null 2>&1; then
        echo "Found reference to the nonexistent examples/opencode/opencode.json"
        return 1
    fi
    return 0
}

test_opencode_json_reference_fixed() {
    grep -qE 'opencode\.single\.json' "$SCRIPT_DIR/install.sh" || {
        echo "install.sh missing opencode.single.json reference"
        return 1
    }
    grep -qE 'opencode\.single\.json' "$SCRIPT_DIR/install.ps1" || {
        echo "install.ps1 missing opencode.single.json reference"
        return 1
    }
    return 0
}

test_opencode_template_files_exist() {
    assert_file_exists "$REPO_DIR/examples/opencode/opencode.single.json" || return 1
    assert_file_exists "$REPO_DIR/examples/opencode/opencode.multi.json" || return 1
    if [ -f "$REPO_DIR/examples/opencode/opencode.json" ]; then
        echo "Unexpected examples/opencode/opencode.json exists (installers reference single/multi)"
        return 1
    fi
    return 0
}

# ============================================================================
# Tests — Manifest-driven install + versioning (E10)
# ============================================================================

test_manifest_exists_and_parses() {
    assert_file_exists "$MANIFEST_FILE" || return 1
    if command -v jq > /dev/null 2>&1; then
        jq -e . "$MANIFEST_FILE" > /dev/null 2>&1 || { echo "manifest.json failed jq parse"; return 1; }
    elif command -v python3 > /dev/null 2>&1; then
        python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$MANIFEST_FILE" > /dev/null 2>&1 \
            || { echo "manifest.json failed python parse"; return 1; }
    fi
    grep -q '"go-testing"' "$MANIFEST_FILE" || { echo "manifest missing go-testing"; return 1; }
    grep -q '"judgment-day"' "$MANIFEST_FILE" || { echo "manifest missing judgment-day"; return 1; }
    return 0
}

test_version_flag() {
    local output
    output=$(bash "$INSTALL_SCRIPT" --version 2>&1)
    echo "$output" | grep -q "kurama" || { echo "Version output missing 'kurama'"; return 1; }
    echo "$output" | grep -qE '[0-9]+\.[0-9]+\.[0-9]+' || { echo "Version output missing a semver-like version"; return 1; }
}

test_version_exits_zero() {
    bash "$INSTALL_SCRIPT" --version > /dev/null 2>&1
    return 0
}

test_install_writes_install_manifest() {
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    local manifest="$HOME/.claude/skills/.kurama-install-manifest.json"
    assert_file_exists "$manifest" || return 1
    grep -q '"version"' "$manifest" || { echo "install manifest missing version field"; return 1; }
    grep -q '"files"' "$manifest" || { echo "install manifest missing files array"; return 1; }
    grep -q 'sdd-apply/SKILL.md' "$manifest" || { echo "install manifest missing an installed skill path"; return 1; }
    return 0
}

test_default_install_includes_optional_groups() {
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    assert_dir_exists "$HOME/.claude/skills/go-testing" || return 1
    assert_dir_exists "$HOME/.claude/skills/kanban-github" || return 1   # optional group ships kanban-github too
    assert_dir_exists "$HOME/.claude/skills/judgment-day" || return 1
    return 0
}

test_without_optional_excludes_go_testing() {
    # The optional group now holds two skills — go-testing AND the kanban-github module —
    # so --without optional drops both, landing the remaining 23 default skills.
    bash "$INSTALL_SCRIPT" --agent claude-code --without optional > /dev/null 2>&1
    local base="$HOME/.claude/skills"
    if [ -d "$base/go-testing" ]; then
        echo "go-testing should be excluded by --without optional"
        return 1
    fi
    if [ -d "$base/kanban-github" ]; then
        echo "kanban-github should be excluded by --without optional"
        return 1
    fi
    assert_dir_exists "$base/judgment-day" || return 1   # quality group still on
    assert_dir_exists "$base/sdd-apply" || return 1       # sdd-core always on
    local count
    count=$(find "$base" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "23" "$count" "Expected 23 skills with --without optional (25 default - go-testing - kanban-github)"
}

test_without_quality_excludes_judgment_day() {
    bash "$INSTALL_SCRIPT" --agent claude-code --without quality > /dev/null 2>&1
    local base="$HOME/.claude/skills"
    if [ -d "$base/judgment-day" ]; then
        echo "judgment-day should be excluded by --without quality"
        return 1
    fi
    assert_dir_exists "$base/go-testing" || return 1
    assert_dir_exists "$base/kanban-github" || return 1         # optional group still on
    local count
    count=$(find "$base" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "24" "$count" "Expected 24 skills with --without quality"
}

test_without_both_groups() {
    bash "$INSTALL_SCRIPT" --agent claude-code --without quality --without optional > /dev/null 2>&1
    local base="$HOME/.claude/skills"
    if [ -d "$base/judgment-day" ]; then echo "judgment-day should be excluded"; return 1; fi
    if [ -d "$base/go-testing" ]; then echo "go-testing should be excluded"; return 1; fi
    local count
    count=$(find "$base" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "22" "$count" "Expected 22 skills with both optional groups excluded"
}

test_reject_without_required_group() {
    if bash "$INSTALL_SCRIPT" --agent claude-code --without sdd-core > /dev/null 2>&1; then
        echo "Expected non-zero exit for --without sdd-core, but got 0"
        return 1
    fi
    return 0
}

# ============================================================================
# Tests — TDD module group (default-on; opt out with --without tdd)
# ============================================================================

test_default_install_includes_tdd() {
    # The tdd group is now default-on: a plain install ships skills/tdd as part of
    # the 25-skill default set. Installing the module does NOT activate TDD —
    # activation stays opt-in per project.
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    local base="$HOME/.claude/skills"
    assert_dir_exists "$base/tdd" || return 1
    assert_file_exists "$base/tdd/SKILL.md" || return 1
    assert_file_not_empty "$base/tdd/SKILL.md" || return 1
    local count
    count=$(find "$base" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "Default install must include tdd (25 skills)"
}

test_without_tdd_excludes_tdd() {
    # --without tdd opts the module out: skills/tdd is dropped, landing the
    # remaining 24 default skills. The other default-on groups stay on.
    bash "$INSTALL_SCRIPT" --agent claude-code --without tdd > /dev/null 2>&1
    local base="$HOME/.claude/skills"
    if [ -d "$base/tdd" ]; then
        echo "tdd should be excluded by --without tdd"
        return 1
    fi
    assert_dir_exists "$base/judgment-day" || return 1   # quality group still on
    assert_dir_exists "$base/go-testing" || return 1     # optional group still on
    assert_dir_exists "$base/sdd-apply" || return 1       # sdd-core always on
    local count
    count=$(find "$base" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "24" "$count" "Expected 24 skills with --without tdd"
}

test_with_tdd_includes_tdd() {
    # tdd is default-on, so --with tdd is idempotent: skills/tdd ships and the
    # count stays at the 25-skill default set.
    bash "$INSTALL_SCRIPT" --agent claude-code --with tdd > /dev/null 2>&1
    local base="$HOME/.claude/skills"
    assert_dir_exists "$base/tdd" || return 1
    assert_file_exists "$base/tdd/SKILL.md" || return 1
    assert_file_not_empty "$base/tdd/SKILL.md" || return 1
    # Default-on groups still present.
    assert_dir_exists "$base/judgment-day" || return 1
    assert_dir_exists "$base/go-testing" || return 1
    assert_dir_exists "$base/sdd-apply" || return 1
    local count
    count=$(find "$base" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "Expected 25 skills with --with tdd (default set already includes tdd)"
}

test_with_tdd_uninstall_round_trip() {
    # Installing the tdd module and uninstalling leaves the target clean:
    # skills/tdd and the install manifest are gone, user-created skills survive.
    bash "$INSTALL_SCRIPT" --agent claude-code --with tdd > /dev/null 2>&1
    assert_dir_exists "$HOME/.claude/skills/tdd" || return 1
    mkdir -p "$HOME/.claude/skills/my-custom"
    echo "keep me" > "$HOME/.claude/skills/my-custom/SKILL.md"

    bash "$UNINSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1

    if [ -d "$HOME/.claude/skills/tdd" ]; then
        echo "tdd should have been removed by uninstall"
        return 1
    fi
    if [ -f "$HOME/.claude/skills/.kurama-install-manifest.json" ]; then
        echo "install manifest should have been removed by uninstall"
        return 1
    fi
    assert_file_exists "$HOME/.claude/skills/my-custom/SKILL.md" || return 1
    local content
    content=$(cat "$HOME/.claude/skills/my-custom/SKILL.md")
    assert_eq "keep me" "$content" "User-created skill preserved through tdd uninstall"
}

# ============================================================================
# Tests — Pi agent (P5 installer wiring)
# Pi's global context/skills live under its agent config dir (~/.pi/agent). The
# installers write skills to ~/.pi/agent/skills and merge the orchestrator rule
# into ~/.pi/agent/AGENTS.md (Pi's global context file, loaded natively).
# ============================================================================

test_install_pi() {
    bash "$INSTALL_SCRIPT" --agent pi > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.pi/agent/skills"
}

test_pi_skill_count() {
    bash "$INSTALL_SCRIPT" --agent pi > /dev/null 2>&1
    local count
    count=$(find "$HOME/.pi/agent/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "25" "$count" "Expected exactly 25 skills for Pi"
}

test_pi_writes_install_manifest() {
    # install.sh --agent pi leaves the same receipt as every other target so
    # uninstall.sh works for Pi installs.
    bash "$INSTALL_SCRIPT" --agent pi > /dev/null 2>&1
    local manifest="$HOME/.pi/agent/skills/.kurama-install-manifest.json"
    assert_file_exists "$manifest" || return 1
    grep -q '"files"' "$manifest" || { echo "Pi install manifest missing files array"; return 1; }
    grep -q 'tdd/SKILL.md' "$manifest" || { echo "Pi install manifest missing tdd (default set)"; return 1; }
    return 0
}

test_setup_pi_writes_orchestrator() {
    # setup.sh --agent pi installs the default skill set into ~/.pi/agent/skills
    # and merges the orchestrator rule into the global Pi context file
    # (~/.pi/agent/AGENTS.md) using the standard kurama markers.
    bash "$SETUP_SCRIPT" --agent pi > /dev/null 2>&1
    assert_all_skills_installed "$HOME/.pi/agent/skills" || return 1
    local prompt="$HOME/.pi/agent/AGENTS.md"
    assert_file_exists "$prompt" || return 1
    grep -qF 'BEGIN:kurama' "$prompt" || { echo "Pi orchestrator missing BEGIN:kurama marker"; return 1; }
    grep -qF 'END:kurama' "$prompt" || { echo "Pi orchestrator missing END:kurama marker"; return 1; }
    grep -qF 'Kurama Orchestrator' "$prompt" || { echo "Pi orchestrator body missing"; return 1; }
    return 0
}

# ============================================================================
# Tests — N4: Claude Code native agents (setup.sh installs 17 agents +
# records them in the per-target receipt for receipt-driven removal)
# ============================================================================

# The 17 native agents setup.sh must install for claude-code: 9 SDD phase agents
# plus the 8 review/Judgment-Day agents added in Phase 10a.
EXPECTED_AGENTS=(
    sdd-apply sdd-archive sdd-design sdd-explore sdd-init
    sdd-propose sdd-spec sdd-tasks sdd-verify
    review-risk review-readability review-reliability review-resilience
    review-refuter jd-judge-a jd-judge-b jd-fix-agent
)

test_setup_installs_all_claude_agents() {
    bash "$SETUP_SCRIPT" --agent claude-code > /dev/null 2>&1
    local agents_dir="$HOME/.claude/agents"
    assert_dir_exists "$agents_dir" || return 1
    local agent
    for agent in "${EXPECTED_AGENTS[@]}"; do
        assert_file_exists "$agents_dir/$agent.md" || return 1
        assert_file_not_empty "$agents_dir/$agent.md" || return 1
    done
    local count
    count=$(find "$agents_dir" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
    assert_eq "17" "$count" "setup.sh should install exactly 17 Claude Code agents"
}

test_setup_agents_recorded_in_receipt() {
    # Every installed agent is listed in the SAME per-target receipt (relative to
    # the skills dir as ../agents/NAME.md) so uninstall.sh removes them too.
    bash "$SETUP_SCRIPT" --agent claude-code > /dev/null 2>&1
    local manifest="$HOME/.claude/skills/.kurama-install-manifest.json"
    assert_file_exists "$manifest" || return 1
    grep -q '\.\./agents/review-risk.md' "$manifest" || {
        echo "receipt missing ../agents/review-risk.md"; return 1; }
    grep -q '\.\./agents/jd-fix-agent.md' "$manifest" || {
        echo "receipt missing ../agents/jd-fix-agent.md"; return 1; }
    grep -q '\.\./agents/sdd-apply.md' "$manifest" || {
        echo "receipt missing ../agents/sdd-apply.md"; return 1; }
    return 0
}

test_setup_agents_backs_up_preexisting() {
    # A pre-existing agent file with the same name must be backed up (.bak.*)
    # before it is overwritten — never silently clobbered.
    mkdir -p "$HOME/.claude/agents"
    local victim="$HOME/.claude/agents/review-risk.md"
    printf 'USER CUSTOM AGENT BODY\n' > "$victim"

    bash "$SETUP_SCRIPT" --agent claude-code > /dev/null 2>&1 || {
        echo "setup.sh failed while installing agents"; return 1; }

    local backups
    backups=$(find "$HOME/.claude/agents" -name 'review-risk.md.bak.*' | wc -l | tr -d ' ')
    if [ "$backups" -lt 1 ]; then
        echo "No timestamped backup was created for a pre-existing agent"
        return 1
    fi
    # The backup preserves the user's original content.
    local bak
    bak=$(find "$HOME/.claude/agents" -name 'review-risk.md.bak.*' | head -1)
    grep -qF 'USER CUSTOM AGENT BODY' "$bak" || {
        echo "Backup does not contain the original user content"; return 1; }
    return 0
}

test_non_claude_target_has_no_agents() {
    # Only claude-code ships native agents. A Pi install must not create an
    # agents directory under the Pi tree.
    bash "$SETUP_SCRIPT" --agent pi > /dev/null 2>&1
    if [ -d "$HOME/.pi/agent/agents" ]; then
        echo "Pi target unexpectedly grew a native agents directory"
        return 1
    fi
    return 0
}

# ============================================================================
# Tests — N5: Pi package stack (opt-in, consent-gated). These use FAKE pi/npm
# shims on a temp PATH that only log their argv — no real package manager, no
# network is ever invoked.
# ============================================================================

# Create fake pi + npm executables in $1 that append their invocation to $2.
make_pi_shims() {
    local bindir="$1" logfile="$2"
    mkdir -p "$bindir"
    cat > "$bindir/pi" <<SHIM
#!/usr/bin/env bash
printf 'pi %s\n' "\$*" >> "$logfile"
exit 0
SHIM
    cat > "$bindir/npm" <<SHIM
#!/usr/bin/env bash
printf 'npm %s\n' "\$*" >> "$logfile"
exit 0
SHIM
    chmod +x "$bindir/pi" "$bindir/npm"
}

test_pi_packages_exact_sequence() {
    # With --with-pi-packages and pi on PATH, setup.sh must invoke the approved
    # package stack in the EXACT approved order, with the pinned versions.
    local bindir="$TEST_TMPDIR/shimbin" log="$TEST_TMPDIR/pi-calls.log"
    make_pi_shims "$bindir" "$log"

    PATH="$bindir:$PATH" bash "$SETUP_SCRIPT" --agent pi --with-pi-packages > /dev/null 2>&1 || {
        echo "setup.sh --agent pi --with-pi-packages exited non-zero"; return 1; }

    assert_file_exists "$log" || { echo "no pi/npm calls were logged"; return 1; }

    # gentle-pi (rival harness) must NEVER be installed.
    if grep -q 'gentle-pi' "$log"; then
        echo "gentle-pi appeared in the install sequence — it must be excluded"
        return 1
    fi

    local expected actual
    expected="pi install npm:gentle-engram@0.1.10
pi install npm:pi-mcp-adapter@2.11.0
npm exec --yes --package gentle-engram@0.1.10 -- pi-engram init
pi install npm:pi-subagents-j0k3r@1.4.1
pi install npm:@juicesharp/rpiv-ask-user-question@2.0.0
pi install npm:pi-web-access@0.13.0
pi install npm:@juicesharp/rpiv-todo@2.0.0
pi install npm:pi-btw@0.4.1"
    actual="$(cat "$log")"
    assert_eq "$expected" "$actual" "Pi package install sequence must match the approved order + pins"
}

test_pi_packages_without_flag_skips() {
    # --without-pi-packages must skip the stack entirely: pi/npm are never called.
    local bindir="$TEST_TMPDIR/shimbin" log="$TEST_TMPDIR/pi-calls.log"
    make_pi_shims "$bindir" "$log"

    PATH="$bindir:$PATH" bash "$SETUP_SCRIPT" --agent pi --without-pi-packages > /dev/null 2>&1 || {
        echo "setup.sh --agent pi --without-pi-packages exited non-zero"; return 1; }

    if [ -f "$log" ]; then
        echo "pi/npm were invoked despite --without-pi-packages"
        return 1
    fi
    # The Pi skill install itself must still have happened.
    assert_all_skills_installed "$HOME/.pi/agent/skills" || return 1
    return 0
}

test_pi_packages_failure_is_non_fatal() {
    # A failing `pi install` must warn and CONTINUE — never abort setup — and the
    # remaining packages in the sequence must still be attempted.
    local bindir="$TEST_TMPDIR/shimbin" log="$TEST_TMPDIR/pi-calls.log"
    mkdir -p "$bindir"
    # pi fails ONLY for pi-mcp-adapter (2nd step); everything else succeeds.
    cat > "$bindir/pi" <<SHIM
#!/usr/bin/env bash
printf 'pi %s\n' "\$*" >> "$log"
case "\$*" in
    *pi-mcp-adapter*) exit 7 ;;
esac
exit 0
SHIM
    cat > "$bindir/npm" <<SHIM
#!/usr/bin/env bash
printf 'npm %s\n' "\$*" >> "$log"
exit 0
SHIM
    chmod +x "$bindir/pi" "$bindir/npm"

    if ! PATH="$bindir:$PATH" bash "$SETUP_SCRIPT" --agent pi --with-pi-packages > /dev/null 2>&1; then
        echo "a single failed pi install aborted the whole setup (must be non-fatal)"
        return 1
    fi

    # All 8 steps must still have been attempted despite the 2nd one failing.
    local lines
    lines=$(wc -l < "$log" | tr -d ' ')
    assert_eq "8" "$lines" "all 8 package steps must be attempted even when one fails" || return 1
    grep -q 'pi-btw@' "$log" || { echo "later packages were skipped after a failure"; return 1; }
    return 0
}

test_pi_packages_skipped_when_pi_absent() {
    # When pi is NOT on PATH, the stack is skipped cleanly (no crash), even with
    # --with-pi-packages. Build a restricted PATH (symlink farm) that deliberately
    # omits pi so the absence is deterministic regardless of the host.
    local bindir="$TEST_TMPDIR/nopi-bin"
    mkdir -p "$bindir"
    local tool p
    for tool in bash sh env uname grep egrep dirname basename mkdir cp mv cat date chmod rm ls awk sed tr wc find mktemp sort head printf test jq; do
        p="$(command -v "$tool" 2>/dev/null)" || continue
        ln -sf "$p" "$bindir/$tool"
    done
    # Deliberately DO NOT link pi (or npm) into the farm.

    local output
    if ! output=$(PATH="$bindir" bash "$SETUP_SCRIPT" --agent pi --with-pi-packages 2>&1); then
        echo "setup.sh crashed when pi was absent (must skip gracefully)"
        return 1
    fi
    echo "$output" | grep -qi 'pi not found' || {
        echo "expected a 'pi not found' skip message when pi is absent"; return 1; }
    # Skills must still be installed even though the package stack was skipped.
    assert_all_skills_installed "$HOME/.pi/agent/skills" || return 1
    return 0
}

# ============================================================================
# Tests — Review lens group (4R + refuter, default-on)
# ============================================================================

REVIEW_LENSES=(review-risk review-readability review-reliability review-resilience review-refuter)

test_review_lenses_installed_by_default() {
    # The review group is default-on: a plain install ships all five 4R + refuter
    # lenses alongside the rest of the default set.
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    local base="$HOME/.claude/skills"
    local lens
    for lens in "${REVIEW_LENSES[@]}"; do
        assert_dir_exists "$base/$lens" || return 1
        assert_file_exists "$base/$lens/SKILL.md" || return 1
        assert_file_not_empty "$base/$lens/SKILL.md" || return 1
    done
    return 0
}

test_without_review_excludes_lenses() {
    # The review group opts out like quality/optional: --without review drops all
    # five lenses and lands the remaining 20 default skills.
    bash "$INSTALL_SCRIPT" --agent claude-code --without review > /dev/null 2>&1
    local base="$HOME/.claude/skills"
    local lens
    for lens in "${REVIEW_LENSES[@]}"; do
        if [ -d "$base/$lens" ]; then
            echo "$lens should be excluded by --without review"
            return 1
        fi
    done
    assert_dir_exists "$base/judgment-day" || return 1   # quality group still on
    assert_dir_exists "$base/sdd-apply" || return 1       # sdd-core always on
    local count
    count=$(find "$base" -name "SKILL.md" | wc -l | tr -d ' ')
    assert_eq "20" "$count" "Expected 20 skills with --without review (25 default - 5 lenses)"
}

# ============================================================================
# Tests — Kanban module (Phase 9; optional group, default-on; install ≠ activate)
# The module is pure Markdown protocol — these tests ONLY verify files and counts.
# No live `gh` or network calls are made (activation requires a configured gh and
# only happens during a real SDD cycle, never here).
# ============================================================================

test_kanban_installed_by_default() {
    # The kanban-github module ships in the default set (manifest `optional` group).
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    local base="$HOME/.claude/skills"
    assert_dir_exists "$base/kanban-github" || return 1
    assert_file_exists "$base/kanban-github/SKILL.md" || return 1
    assert_file_not_empty "$base/kanban-github/SKILL.md" || return 1
    return 0
}

test_kanban_listed_in_manifest_optional_group() {
    # Structural check only — kanban-github is declared once in the manifest's optional
    # group. No install, no gh.
    grep -q '"kanban-github"' "$MANIFEST_FILE" || { echo "manifest missing kanban-github skill"; return 1; }
    if command -v jq > /dev/null 2>&1; then
        local group
        group=$(jq -r '.skills[] | select(.name == "kanban-github") | .group' "$MANIFEST_FILE")
        assert_eq "optional" "$group" "kanban-github must be in the optional manifest group" || return 1
    fi
    return 0
}

test_without_optional_excludes_kanban() {
    # --without optional drops the whole optional group, kanban-github included.
    bash "$INSTALL_SCRIPT" --agent claude-code --without optional > /dev/null 2>&1
    if [ -d "$HOME/.claude/skills/kanban-github" ]; then
        echo "kanban-github should be excluded by --without optional"
        return 1
    fi
    return 0
}

# ============================================================================
# Tests — Phase 6 surface (sdd-status.sh + generated Pi harness)
# ============================================================================

test_sdd_status_exists_and_executable() {
    local status_script="$SCRIPT_DIR/sdd-status.sh"
    assert_file_exists "$status_script" || return 1
    [ -x "$status_script" ] || { echo "sdd-status.sh is not executable"; return 1; }
    return 0
}

test_sdd_status_empty_dir_exit_zero() {
    local empty="$TEST_TMPDIR/empty-project"
    mkdir -p "$empty"
    local output
    if ! output=$(bash "$SCRIPT_DIR/sdd-status.sh" "$empty" 2>&1); then
        echo "sdd-status.sh should exit 0 on an empty project"
        return 1
    fi
    echo "$output" | grep -q "No active SDD cycles" || {
        echo "sdd-status.sh empty output should say 'No active SDD cycles'"
        return 1
    }
    return 0
}

test_sdd_status_json_parses_on_empty() {
    local empty="$TEST_TMPDIR/empty-json-project"
    mkdir -p "$empty"
    local output
    output=$(bash "$SCRIPT_DIR/sdd-status.sh" --json "$empty" 2>&1) || {
        echo "sdd-status.sh --json should exit 0 on an empty project"
        return 1
    }
    if command -v jq >/dev/null 2>&1; then
        echo "$output" | jq -e '.changes == []' >/dev/null 2>&1 || {
            echo "sdd-status.sh --json did not emit a valid empty changes array"
            return 1
        }
    elif command -v python3 >/dev/null 2>&1; then
        echo "$output" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get("changes")==[] else 1)' || {
            echo "sdd-status.sh --json did not emit valid JSON with an empty changes array"
            return 1
        }
    else
        echo "$output" | grep -q '"changes"' || {
            echo "sdd-status.sh --json missing changes key (no JSON parser to validate fully)"
            return 1
        }
    fi
    return 0
}

test_pi_example_generated() {
    # G9: Pi is the 8th generated harness; its orchestrator lands at examples/pi/AGENTS.md.
    assert_file_exists "$REPO_DIR/examples/pi/AGENTS.md" || return 1
    assert_file_not_empty "$REPO_DIR/examples/pi/AGENTS.md" 500 || return 1
    return 0
}

# ============================================================================
# Tests — Uninstall round-trip (E10)
# ============================================================================

test_uninstall_round_trip() {
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    # A user-created skill must survive uninstall.
    mkdir -p "$HOME/.claude/skills/my-custom"
    echo "keep me" > "$HOME/.claude/skills/my-custom/SKILL.md"

    bash "$UNINSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1

    if [ -d "$HOME/.claude/skills/sdd-apply" ]; then
        echo "sdd-apply should have been removed by uninstall"
        return 1
    fi
    if [ -f "$HOME/.claude/skills/.kurama-install-manifest.json" ]; then
        echo "install manifest should have been removed by uninstall"
        return 1
    fi
    assert_file_exists "$HOME/.claude/skills/my-custom/SKILL.md" || return 1
    local content
    content=$(cat "$HOME/.claude/skills/my-custom/SKILL.md")
    assert_eq "keep me" "$content" "User-created skill preserved through uninstall"
}

test_uninstall_dry_run_preserves_files() {
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    bash "$UNINSTALL_SCRIPT" --agent claude-code --dry-run > /dev/null 2>&1
    # Nothing should be deleted on a dry run.
    assert_all_skills_installed "$HOME/.claude/skills" || return 1
    assert_file_exists "$HOME/.claude/skills/.kurama-install-manifest.json" || return 1
    return 0
}

test_uninstall_custom_path() {
    local custom="$TEST_TMPDIR/custom-skills"
    bash "$INSTALL_SCRIPT" --agent custom --path "$custom" > /dev/null 2>&1
    assert_file_exists "$custom/.kurama-install-manifest.json" || return 1
    bash "$UNINSTALL_SCRIPT" --path "$custom" > /dev/null 2>&1
    if [ -d "$custom/sdd-apply" ]; then
        echo "sdd-apply should have been removed from custom path"
        return 1
    fi
    return 0
}

# ============================================================================
# Tests — Meta-skill registration (M3): sdd-new / sdd-continue / sdd-ff
# ============================================================================

test_meta_skills_installed_by_default() {
    # The three orchestrator meta-skills live in the sdd-core group, so a plain
    # install must ship them (they are the /sdd-new, /sdd-continue, /sdd-ff
    # entry points).
    bash "$INSTALL_SCRIPT" --agent claude-code > /dev/null 2>&1
    local base="$HOME/.claude/skills"
    for meta in sdd-new sdd-continue sdd-ff; do
        assert_dir_exists "$base/$meta" || return 1
        assert_file_exists "$base/$meta/SKILL.md" || return 1
        assert_file_not_empty "$base/$meta/SKILL.md" || return 1
    done
    return 0
}

# ============================================================================
# Tests — Packaging manifests (M5): plugin.json / marketplace.json /
# gemini-extension.json parse as JSON and plugin.json version == VERSION
# ============================================================================

# Parse a JSON file: jq preferred, python3 fallback, soft-pass if neither exists.
json_file_parses() {
    local f="$1"
    if command -v jq > /dev/null 2>&1; then
        jq -e . "$f" > /dev/null 2>&1
    elif command -v python3 > /dev/null 2>&1; then
        python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" > /dev/null 2>&1
    else
        return 0  # No JSON parser available — soft pass.
    fi
}

test_plugin_json_valid() {
    local f="$REPO_DIR/.claude-plugin/plugin.json"
    assert_file_exists "$f" || return 1
    json_file_parses "$f" || { echo "plugin.json is not valid JSON"; return 1; }
    return 0
}

test_marketplace_json_valid() {
    local f="$REPO_DIR/.claude-plugin/marketplace.json"
    assert_file_exists "$f" || return 1
    json_file_parses "$f" || { echo "marketplace.json is not valid JSON"; return 1; }
    return 0
}

test_gemini_extension_json_valid() {
    local f="$REPO_DIR/gemini-extension.json"
    assert_file_exists "$f" || return 1
    json_file_parses "$f" || { echo "gemini-extension.json is not valid JSON"; return 1; }
    return 0
}

test_plugin_json_version_matches_version_file() {
    local f="$REPO_DIR/.claude-plugin/plugin.json"
    local version_file="$REPO_DIR/VERSION"
    assert_file_exists "$f" || return 1
    assert_file_exists "$version_file" || return 1

    local expected
    IFS= read -r expected < "$version_file"

    local actual
    if command -v jq > /dev/null 2>&1; then
        actual=$(jq -r '.version' "$f")
    elif command -v python3 > /dev/null 2>&1; then
        actual=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$f")
    else
        # No JSON parser — assert the VERSION string appears verbatim in the file.
        if grep -qF "\"$expected\"" "$f"; then
            return 0
        fi
        echo "No JSON parser and plugin.json lacks the VERSION string '$expected'"
        return 1
    fi
    assert_eq "$expected" "$actual" "plugin.json version must equal the VERSION file"
}

# ============================================================================
# Run all tests
# ============================================================================

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║    Kurama — Install Tests      ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BOLD}Help & Error Handling${NC}"
run_test "--help flag shows usage info" test_help_flag
run_test "--help exits with code 0" test_help_exits_zero
run_test "Invalid agent exits non-zero" test_invalid_agent
run_test "Unknown option exits non-zero" test_invalid_option
echo ""

echo -e "${BOLD}Claude Code${NC}"
run_test "Installs all 25 skills to ~/.claude/skills" test_install_claude_code
run_test "Exactly 25 SKILL.md files" test_claude_code_skill_count
echo ""

echo -e "${BOLD}OpenCode${NC}"
run_test "Installs all 25 skills to ~/.config/opencode/skills" test_install_opencode
run_test "Exactly 25 SKILL.md files" test_opencode_skill_count
run_test "Installs 8 command files" test_opencode_commands
echo ""

echo -e "${BOLD}Gemini CLI${NC}"
run_test "Installs all 25 skills to ~/.gemini/skills" test_install_gemini_cli
run_test "Exactly 25 SKILL.md files" test_gemini_cli_skill_count
echo ""

echo -e "${BOLD}Codex${NC}"
run_test "Installs all 25 skills to ~/.codex/skills" test_install_codex
run_test "Exactly 25 SKILL.md files" test_codex_skill_count
echo ""

echo -e "${BOLD}VS Code (Copilot)${NC}"
run_test "Installs all 25 skills to ~/.copilot/skills" test_install_vscode
run_test "Exactly 25 SKILL.md files" test_vscode_skill_count
echo ""

echo -e "${BOLD}Antigravity${NC}"
run_test "Installs all 25 skills to ~/.gemini/antigravity/skills/" test_install_antigravity
run_test "Exactly 25 SKILL.md files" test_antigravity_skill_count
echo ""

echo -e "${BOLD}Cursor${NC}"
run_test "Installs all 25 skills to ~/.cursor/skills" test_install_cursor
run_test "Exactly 25 SKILL.md files" test_cursor_skill_count
echo ""

echo -e "${BOLD}Project-local${NC}"
run_test "Installs all 25 skills to ./skills/" test_install_project_local
run_test "Exactly 25 SKILL.md files" test_project_local_skill_count
echo ""

echo -e "${BOLD}Custom path${NC}"
run_test "Installs to arbitrary custom path" test_custom_path
run_test "Exactly 25 SKILL.md files" test_custom_path_skill_count
run_test "Handles deeply nested custom path" test_nested_custom_path
echo ""

echo -e "${BOLD}All-global${NC}"
run_test "Installs to all 5 global targets" test_all_global
run_test "125 total SKILL.md files (5x25)" test_all_global_total_skill_count
run_test "Also installs OpenCode commands" test_all_global_opencode_commands
echo ""

echo -e "${BOLD}Idempotency${NC}"
run_test "Claude Code: double install is safe" test_idempotent_claude_code
run_test "OpenCode: double install is safe" test_idempotent_opencode
run_test "All-global: double install is safe" test_idempotent_all_global
echo ""

echo -e "${BOLD}Content integrity${NC}"
run_test "Skills match source files exactly" test_skill_content_matches_source
run_test "Commands match source files exactly" test_opencode_command_content_matches_source
echo ""

echo -e "${BOLD}Output verification${NC}"
run_test "Output lists all skill names" test_output_shows_skill_names
run_test "Output shows Done! message" test_output_shows_done_message
run_test "Output shows install count" test_output_shows_install_count
run_test "Output shows next-step guidance" test_output_shows_next_step
run_test "Output recommends Engram" test_output_shows_engram_note
echo ""

echo -e "${BOLD}OS detection${NC}"
run_test "--help runs without error" test_os_detection_runs
run_test "Header shows detected OS" test_header_shows_detected_os
echo ""

echo -e "${BOLD}Edge cases${NC}"
run_test "Pre-existing custom skill not clobbered" test_pre_existing_dir_not_clobbered
run_test "Stale SKILL.md is overwritten" test_overwrite_stale_skill
echo ""

echo -e "${BOLD}setup.sh orchestrator safety${NC}"
run_test "Unbalanced marker (BEGIN w/o END) aborts, file intact" test_setup_unbalanced_marker_aborts
run_test "Balanced marker updates in place + writes backup" test_setup_balanced_marker_updates_and_backs_up
echo ""

echo -e "${BOLD}setup.sh manifest-driven install + receipt${NC}"
run_test "setup.sh installs the 25 default skills" test_setup_installs_default_skill_set
run_test "setup.sh includes the default tdd module" test_setup_includes_tdd
run_test "setup.sh writes an install manifest (receipt)" test_setup_writes_install_manifest
run_test "uninstall.sh cleans a setup.sh install" test_setup_uninstall_round_trip
run_test "setup.sh tree equals install.sh default tree" test_setup_matches_manifest_default_set
echo ""

echo -e "${BOLD}OpenCode template references${NC}"
run_test "No reference to nonexistent examples/opencode/opencode.json" test_no_broken_opencode_json_reference
run_test "Installers reference opencode.single.json" test_opencode_json_reference_fixed
run_test "opencode.single/multi.json templates exist" test_opencode_template_files_exist
echo ""

echo -e "${BOLD}Manifest & versioning${NC}"
run_test "manifest.json exists and parses" test_manifest_exists_and_parses
run_test "--version prints the version" test_version_flag
run_test "--version exits with code 0" test_version_exits_zero
run_test "Install writes an install manifest" test_install_writes_install_manifest
run_test "Default install includes optional groups" test_default_install_includes_optional_groups
run_test "--without optional excludes go-testing + kanban-github (23 skills)" test_without_optional_excludes_go_testing
run_test "--without quality excludes judgment-day (24 skills)" test_without_quality_excludes_judgment_day
run_test "--without quality --without optional (22 skills)" test_without_both_groups
run_test "--without sdd-core is rejected" test_reject_without_required_group
echo ""

echo -e "${BOLD}TDD module (default-on group)${NC}"
run_test "Default install includes tdd (25 skills)" test_default_install_includes_tdd
run_test "--without tdd excludes tdd (24 skills)" test_without_tdd_excludes_tdd
run_test "--with tdd is idempotent (25 skills)" test_with_tdd_includes_tdd
run_test "--with tdd uninstall round-trip is clean" test_with_tdd_uninstall_round_trip
echo ""

echo -e "${BOLD}Pi agent (P5 installer wiring)${NC}"
run_test "install.sh --agent pi installs 25 skills" test_install_pi
run_test "Exactly 25 SKILL.md files for Pi" test_pi_skill_count
run_test "Pi install writes an install manifest" test_pi_writes_install_manifest
run_test "setup.sh --agent pi writes orchestrator to ~/.pi/agent/AGENTS.md" test_setup_pi_writes_orchestrator
echo ""

echo -e "${BOLD}N4 — Claude Code native agents (setup.sh)${NC}"
run_test "setup.sh installs all 17 native agents to ~/.claude/agents" test_setup_installs_all_claude_agents
run_test "installed agents are recorded in the receipt" test_setup_agents_recorded_in_receipt
run_test "pre-existing agent is backed up before overwrite" test_setup_agents_backs_up_preexisting
run_test "non-claude target grows no agents dir" test_non_claude_target_has_no_agents
echo ""

echo -e "${BOLD}N5 — Pi package stack (opt-in, fake pi/npm shims)${NC}"
run_test "exact install sequence + pins, gentle-pi excluded" test_pi_packages_exact_sequence
run_test "--without-pi-packages skips the stack" test_pi_packages_without_flag_skips
run_test "a failed pi install is non-fatal (continues)" test_pi_packages_failure_is_non_fatal
run_test "stack skipped cleanly when pi is absent" test_pi_packages_skipped_when_pi_absent
echo ""

echo -e "${BOLD}Review lens group (G1, default-on)${NC}"
run_test "review lenses install by default" test_review_lenses_installed_by_default
run_test "--without review excludes the 5 lenses (20 skills)" test_without_review_excludes_lenses
echo ""

echo -e "${BOLD}Kanban module (Phase 9, optional group, default-on)${NC}"
run_test "kanban-github installs by default" test_kanban_installed_by_default
run_test "kanban-github is listed in the optional manifest group" test_kanban_listed_in_manifest_optional_group
run_test "--without optional excludes kanban-github" test_without_optional_excludes_kanban
echo ""

echo -e "${BOLD}Phase 6 surface (G9 Pi + sdd-status.sh)${NC}"
run_test "sdd-status.sh exists and is executable" test_sdd_status_exists_and_executable
run_test "sdd-status.sh exits 0 on an empty project" test_sdd_status_empty_dir_exit_zero
run_test "sdd-status.sh --json parses on an empty project" test_sdd_status_json_parses_on_empty
run_test "examples/pi/AGENTS.md is generated" test_pi_example_generated
echo ""

echo -e "${BOLD}Uninstall${NC}"
run_test "Uninstall round-trip removes only recorded files" test_uninstall_round_trip
run_test "Uninstall --dry-run preserves files" test_uninstall_dry_run_preserves_files
run_test "Uninstall works on a custom path" test_uninstall_custom_path
echo ""

echo -e "${BOLD}Meta-skill registration (M3)${NC}"
run_test "sdd-new/continue/ff install by default" test_meta_skills_installed_by_default
echo ""

echo -e "${BOLD}Packaging manifests (M5)${NC}"
run_test "plugin.json is valid JSON" test_plugin_json_valid
run_test "marketplace.json is valid JSON" test_marketplace_json_valid
run_test "gemini-extension.json is valid JSON" test_gemini_extension_json_valid
run_test "plugin.json version equals VERSION file" test_plugin_json_version_matches_version_file
echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${BOLD}════════════════════════════════════════════${NC}"
echo -e "${BOLD}Results: $TESTS_PASSED/$TESTS_RUN passed${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}${BOLD}$TESTS_FAILED test(s) failed:${NC}${FAILURES}"
    exit 1
fi
echo -e "${GREEN}${BOLD}All tests passed!${NC}"
echo ""
