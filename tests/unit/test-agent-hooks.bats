#!/usr/bin/env bats

# Unit tests for the shared PreToolUse / PostToolUse agent hook
# @covers src/dotfiles/.agents/hooks/bin/agent-hook
# @covers src/dotfiles/.agents/hooks/hooks.json

setup() {
    export TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    export HOOK="$TEST_DIR/agent-hook"
    cp "$BATS_TEST_DIRNAME/../../src/dotfiles/.agents/hooks/bin/agent-hook" "$HOOK"
    chmod +x "$HOOK"

    # No work config unless a test writes one
    export AGENT_HOOKS_CONF="$TEST_DIR/hooks.conf"

    # Log lands in the sandbox, never in the real state dir
    export AGENT_HOOKS_LOG="$TEST_DIR/state/agent-hooks/log"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Run the hook against a Bash tool call; $1 command, $2 optional cwd
run_bash() {
    local cwd="${2:-$TEST_DIR}"
    run bash -c "jq -cn --arg c \"\$1\" --arg d \"\$2\" '{tool_name:\"Bash\",cwd:\$d,tool_input:{command:\$c}}' | \"$HOOK\"" _ "$1" "$cwd"
}

assert_denied() {
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision":"deny"'* ]] || [[ "$output" == *'"permissionDecision": "deny"'* ]]
    [[ "$output" == *"$1"* ]]
}

assert_allowed() {
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

make_work_repo() {
    local repo="$TEST_DIR/work"
    mkdir -p "$repo"
    git -C "$repo" init -q
    git -C "$repo" remote add origin "git@github.com:MyOrg/service.git"
    cat > "$AGENT_HOOKS_CONF" <<'EOF'
WORK_REMOTE_RE='github.com[:/]MyOrg/'
WORK_BRANCH_RE='^tv/[A-Z][A-Z0-9]+-[0-9]+-[a-z0-9-]+$'
WORK_PR_TITLE_RE='[A-Z][A-Z0-9]+-[0-9]+'
WORK_PR_ASSIGNEE='@me'
EOF
    echo "$repo"
}

# ============================================================================
# HELP / FAIL OPEN
# ============================================================================

@test "agent-hook -h: shows usage" {
    run "$HOOK" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: agent-hook"* ]]
    [[ "$output" == *"WORK_REMOTE_RE"* ]]
}

@test "agent-hook: unparsable input is allowed" {
    run bash -c "echo 'not json' | '$HOOK'"
    assert_allowed
}

@test "agent-hook: unknown tool is allowed" {
    run bash -c "jq -cn '{tool_name:\"Read\",tool_input:{file_path:\"x\"}}' | '$HOOK'"
    assert_allowed
}

@test "agent-hook: missing jq allows the call" {
    local bin="$TEST_DIR/bin"
    mkdir -p "$bin"
    ln -s "$(command -v bash)" "$bin/bash"
    ln -s "$(command -v cat)" "$bin/cat"
    run env PATH="$bin" bash -c "echo '{}' | '$HOOK'"
    assert_allowed
}

# ============================================================================
# GIT COMMAND SHAPE
# ============================================================================

@test "git checkout is denied with a switch/restore hint" {
    run_bash 'git checkout main'
    assert_denied "git switch"
}

@test "git switch and plain git are allowed" {
    run_bash 'git switch main && git status'
    assert_allowed
}

@test "git -C is denied" {
    run_bash 'git -C ~/dev/x status'
    assert_denied "git -C"
}

@test "cd chained into git is denied" {
    run_bash 'cd ~/dev/x && git status'
    assert_denied "inline cd"
    run_bash 'cd ~/dev/x; git log'
    assert_denied "inline cd"
}

@test "cd chained into a non-git command is allowed" {
    run_bash 'cd ~/dev/x && npm test'
    assert_allowed
}

@test "mentions of checkout inside other commands are still denied as a word" {
    # Documented false positive: the rule keys on the word after git
    run_bash 'echo git checkout'
    assert_denied "git checkout"
}

# ============================================================================
# WORKTREES
# ============================================================================

@test "worktree under ~/dev/worktrees/<repo>/<slug> is allowed" {
    run_bash 'git worktree add ~/dev/worktrees/service/pr-123 origin/feature'
    assert_allowed
    run_bash "git worktree add -b feat \$HOME/dev/worktrees/service/feat"
    assert_allowed
}

@test "worktree slug with + is denied" {
    run_bash 'git worktree add ~/dev/worktrees/service/pr+123'
    assert_denied "worktree slug"
}

@test "worktree under a .claude path is denied" {
    run_bash 'git worktree add .claude/worktrees/x'
    assert_denied ".claude/"
    run_bash "git worktree add $HOME/dev/worktrees/.claude/x"
    assert_denied ".claude/"
}

@test "worktree outside ~/dev/worktrees is denied" {
    run_bash 'git worktree add ../wt/x'
    assert_denied "not under ~/dev/worktrees"
    run_bash 'git worktree add /tmp/wt'
    assert_denied "not under ~/dev/worktrees"
}

@test "worktree missing the slug level is denied" {
    run_bash 'git worktree add ~/dev/worktrees/service'
    assert_denied "exactly ~/dev/worktrees/<repo>/<slug>"
    run_bash 'git worktree add ~/dev/worktrees/service/a/b'
    assert_denied "exactly ~/dev/worktrees/<repo>/<slug>"
}

@test "other worktree subcommands are allowed" {
    run_bash 'git worktree list && git worktree remove ../x'
    assert_allowed
}

@test "EnterWorktree with name is denied, with path is allowed" {
    run bash -c "jq -cn '{tool_name:\"EnterWorktree\",tool_input:{name:\"x\"}}' | '$HOOK'"
    assert_denied "EnterWorktree name"
    run bash -c "jq -cn '{tool_name:\"EnterWorktree\",tool_input:{path:\"/x\"}}' | '$HOOK'"
    assert_allowed
}

# ============================================================================
# ATTRIBUTION
# ============================================================================

@test "attribution footer in git commit is denied" {
    run_bash 'git commit -m "fix" -m "Co-Authored-By: Claude <noreply@anthropic.com>"'
    assert_denied "attribution"
    run_bash 'git commit -F msg && echo "Claude-Session: https://claude.ai/code/session_x"'
    assert_denied "attribution"
}

@test "attribution footer in gh pr create is denied" {
    run_bash 'gh pr create --title t --body "Generated with [Claude Code]"'
    assert_denied "attribution"
}

@test "attribution strings outside git/gh commands are allowed" {
    run_bash 'git log --grep Co-Authored-By'
    assert_allowed
}

# ============================================================================
# GH PR
# ============================================================================

@test "gh pr comment is denied" {
    run_bash 'gh pr comment 12 --body "done"'
    assert_denied "gh pr review"
}

@test "#N in gh pr review body is denied" {
    run_bash 'gh pr review 12 --approve --body "1. good #2 fine"'
    assert_denied "#N"
}

@test "numbered items without # are allowed" {
    run_bash 'gh pr review 12 --approve --body "1. good 2. fine"'
    assert_allowed
}

@test "HTML entities are not treated as #N" {
    run_bash 'gh pr review 12 --approve --body "it&#39;s fine"'
    assert_allowed
}

# ============================================================================
# WORK-REPO RULES (config + origin match)
# ============================================================================

@test "work rules are inert without a config file" {
    run_bash 'git switch -c feature-x'
    assert_allowed
    run_bash 'gh pr create --title "fix" --body x'
    assert_allowed
}

@test "work rules are inert when origin does not match" {
    local repo
    repo=$(make_work_repo)
    git -C "$repo" remote set-url origin git@github.com:someone/personal.git
    run_bash 'git switch -c feature-x' "$repo"
    assert_allowed
}

@test "work branch name is enforced for switch -c, branch, and worktree -b" {
    local repo
    repo=$(make_work_repo)
    run_bash 'git switch -c feature-x' "$repo"
    assert_denied "branch name"
    run_bash 'git branch feature-x' "$repo"
    assert_denied "branch name"
    run_bash 'git worktree add -b feature-x ~/dev/worktrees/service/feature-x' "$repo"
    assert_denied "branch name"
    run_bash 'git switch -c tv/EPT-123-fix-thing' "$repo"
    assert_allowed
}

@test "work branch rule ignores non-creating branch commands" {
    local repo
    repo=$(make_work_repo)
    run_bash 'git branch -d feature-x && git branch --list && git switch main' "$repo"
    assert_allowed
}

@test "work PR title must carry a ticket key" {
    local repo
    repo=$(make_work_repo)
    run_bash 'gh pr create --title "fix thing" --assignee @me' "$repo"
    assert_denied "PR title"
    run_bash "gh pr create -t 'EPT-12 fix' -a @me --body x" "$repo"
    assert_allowed
}

@test "work PR must be assigned" {
    local repo
    repo=$(make_work_repo)
    run_bash 'gh pr create --title "EPT-12 fix" --body x' "$repo"
    assert_denied "PR assignee"
    run_bash 'gh pr create --title "EPT-12 fix" --assignee=@me' "$repo"
    assert_allowed
}

# ============================================================================
# REGISTRATION FILE
# ============================================================================

@test "hooks.json registers PreToolUse and points at the script" {
    local json="$BATS_TEST_DIRNAME/../../src/dotfiles/.agents/hooks/hooks.json"
    run jq -r '.hooks.PreToolUse[0].hooks[0].command' "$json"
    [ "$status" -eq 0 ]
    [ "$output" = "~/.agents/hooks/bin/agent-hook" ]
    run jq -r '.hooks.PreToolUse[0].matcher' "$json"
    [[ "$output" == *"Bash"* ]]
    [[ "$output" == *"EnterWorktree"* ]]
}

@test "client adapters resolve to the canonical hooks.json" {
    local src="$BATS_TEST_DIRNAME/../../src/dotfiles"
    [ -L "$src/.codex/hooks.json" ]
    [ "$(readlink "$src/.codex/hooks.json")" = "../.agents/hooks/hooks.json" ]
    [ -L "$src/.claude/skills/agent-hooks/hooks/hooks.json" ]
    [ "$(readlink "$src/.claude/skills/agent-hooks/hooks/hooks.json")" = "../../../../.agents/hooks/hooks.json" ]
    [ -f "$src/.claude/skills/agent-hooks/.claude-plugin/plugin.json" ]
}

# ============================================================================
# PR FEEDBACK ENTRY POINT
# ============================================================================

@test "ad hoc PR feedback fetches are denied" {
    run_bash 'gh api graphql -f query="{ repository { pullRequest(number: 1) { reviewThreads { nodes { id } } } } }"'
    assert_denied "pr-feedback.mjs"
    run_bash 'gh api repos/o/r/pulls/12/reviews'
    assert_denied "pr-feedback.mjs"
    run_bash 'gh api repos/o/r/pulls/12/comments --paginate'
    assert_denied "pr-feedback.mjs"
    run_bash 'gh pr view 12 --comments'
    assert_denied "pr-feedback.mjs"
}

@test "the script itself and the bot comments endpoint are allowed" {
    run_bash 'node ~/.claude/scripts/pr-feedback.mjs 12'
    assert_allowed
    run_bash 'gh api repos/o/r/issues/12/comments --jq ".[] | select(.user.type == \"Bot\")"'
    assert_allowed
    run_bash 'gh pr view 12 --json title,state'
    assert_allowed
}

# ============================================================================
# DECLOG SHAPE (PostToolUse)
# ============================================================================

run_edit() {
    run bash -c "jq -cn --arg f \"\$1\" '{hook_event_name:\"PostToolUse\",tool_name:\"Edit\",tool_input:{file_path:\$f}}' | \"$HOOK\"" _ "$1"
}

assert_blocked() {
    [ "$status" -eq 0 ]
    [[ "$output" == *'"decision":"block"'* ]] || [[ "$output" == *'"decision": "block"'* ]]
    [[ "$output" == *"$1"* ]]
}

# Write stdin to the test declog and echo its path
write_declog() {
    cat > "$TEST_DIR/.declog.md"
    echo "$TEST_DIR/.declog.md"
}

@test "declog: a well-formed newest entry passes silently" {
    local f
    f=$(write_declog <<'EOF'
# Decision log

Intro text.

## 2026-09-21 Newer

- Status: accepted
- Decision: Do the thing with `path/to.file` and v1.2.3. Keep it simple.
- Rationale: One reason, e.g. this one.

## 2026-09-18 Older

- Status: rejected
- Decision: Old.
EOF
)
    run_edit "$f"
    assert_allowed
}

@test "declog: non-declog files are ignored" {
    echo "- Bogus: field. Two. Three." > "$TEST_DIR/notes.md"
    run_edit "$TEST_DIR/notes.md"
    assert_allowed
}

@test "declog: an unknown field is blocked" {
    local f
    f=$(write_declog <<'EOF'
# Decision log

## 2026-09-21 Entry

- Status: accepted
- Outcome: not a real field.
EOF
)
    run_edit "$f"
    assert_blocked "'Outcome' is not in the entry vocabulary"
}

@test "declog: an entry appended below a newer one is blocked" {
    local f
    f=$(write_declog <<'EOF'
# Decision log

## 2026-09-18 Older first

- Status: accepted
- Decision: Old.

## 2026-09-21 Newer appended

- Status: accepted
- Decision: New.
EOF
)
    run_edit "$f"
    assert_blocked "newest-first"
}

@test "declog: a field over two sentences is nudged, not blocked" {
    local f
    f=$(write_declog <<'EOF'
# Decision log

## 2026-09-21 Entry

- Status: accepted
- Consequences: First sentence. Second sentence. Third sentence that
  wraps onto a new line. Fourth!
- Decision: Short.
EOF
)
    run_edit "$f"
    [ "$status" -eq 0 ]
    [[ "$output" == *'additionalContext'* ]]
    [[ "$output" == *'Consequences'* ]]
    [[ "$output" != *'Decision'* ]]
    [[ "$output" != *'"decision"'* ]]
}

@test "declog: a two-sentence field over three lines is nudged" {
    local f
    f=$(write_declog <<'EOF'
# Decision log

## 2026-09-21 Entry

- Status: accepted
- Rationale: One long sentence that keeps going with clause after clause and never
  quite lands anywhere because it is trying to say everything the deliberation
  covered instead of the one reason that matters; a second sentence follows the
  semicolon and wraps yet again.
EOF
)
    run_edit "$f"
    [ "$status" -eq 0 ]
    [[ "$output" == *'additionalContext'* ]]
    [[ "$output" == *'Rationale'* ]]
}

@test "declog: vocabulary check blocks even when a length nudge is pending" {
    local f
    f=$(write_declog <<'EOF'
# Decision log

## 2026-09-21 Entry

- Status: accepted
- Decision: One. Two. Three.
- Bogus: x
EOF
)
    run_edit "$f"
    assert_blocked "vocabulary"
}

@test "hooks.json registers PostToolUse for edit tools" {
    local json="$BATS_TEST_DIRNAME/../../src/dotfiles/.agents/hooks/hooks.json"
    run jq -r '.hooks.PostToolUse[0].matcher' "$json"
    [[ "$output" == *"Edit"* ]]
    [[ "$output" == *"apply_patch"* ]]
    run jq -r '.hooks.PostToolUse[0].hooks[0].command' "$json"
    [ "$output" = "~/.agents/hooks/bin/agent-hook" ]
}

# ============================================================================
# LOG - every deny/block/nudge leaves one line; allowed calls leave nothing
# ============================================================================

@test "log: a deny appends timestamp, decision, rule, tool, repo" {
    git init -q "$TEST_DIR/myrepo"
    run_bash "git checkout main" "$TEST_DIR/myrepo"
    assert_denied "git checkout"

    [ -f "$AGENT_HOOKS_LOG" ]
    [ "$(wc -l < "$AGENT_HOOKS_LOG" | tr -d ' ')" -eq 1 ]
    local line tab
    tab=$(printf '\t')
    line=$(cat "$AGENT_HOOKS_LOG")
    [[ "$line" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z${tab}deny${tab}git\ checkout${tab}Bash${tab}myrepo$ ]]
}

@test "log: outside a repo the repo column is a dash" {
    run_bash "git -C /tmp status"
    assert_denied "git -C"
    [ "$(cut -f5 "$AGENT_HOOKS_LOG")" = "-" ]
}

@test "log: an allowed call writes nothing" {
    run_bash "git status"
    assert_allowed
    [ ! -e "$AGENT_HOOKS_LOG" ]
}

@test "log: a declog nudge is logged with its label" {
    local f
    f=$(write_declog <<'EOF'
# Decision log

## 2026-09-21 Entry

- Status: accepted
- Consequences: First sentence. Second sentence. Third sentence that
  wraps onto a new line. Fourth!
EOF
)
    run_edit "$f"
    [[ "$output" == *'additionalContext'* ]]
    [ "$(cut -f2,3 "$AGENT_HOOKS_LOG")" = "$(printf 'nudge\tdeclog length')" ]
}

@test "log: an unwritable log does not change the decision" {
    export AGENT_HOOKS_LOG="$TEST_DIR/readonly/log"
    mkdir -p "$TEST_DIR/readonly"
    chmod 500 "$TEST_DIR/readonly"
    run_bash "git checkout main"
    chmod 700 "$TEST_DIR/readonly"
    assert_denied "git checkout"
    [ ! -e "$AGENT_HOOKS_LOG" ]
}

@test "-s: empty log says so" {
    run "$HOOK" -s
    [ "$status" -eq 0 ]
    [[ "$output" == *"No log at"* ]]
}

@test "-s: counts by decision and rule, most frequent first" {
    run_bash "git checkout main"
    run_bash "git checkout dev"
    run_bash "git -C /tmp status"
    run "$HOOK" --stats
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "Since "*", 3 lines" ]]
    [[ "${lines[1]}" =~ ^\ *2\ \ deny\ +git\ checkout$ ]]
    [[ "${lines[2]}" =~ ^\ *1\ \ deny\ +git\ -C$ ]]
}
