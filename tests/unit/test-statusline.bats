#!/usr/bin/env bats

# Unit tests for the Claude Code statusline script
# @covers src/dotfiles/.claude/statusline-command.sh
#
# The script reads the session JSON on stdin and prints one ANSI-colored line.
# Tests strip the color codes and assert on the text; the pace and time-left
# math is integer arithmetic on epoch seconds, so fixtures use `now` offsets.

setup() {
    export TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    export SL="$TEST_DIR/statusline"
    cp "$BATS_TEST_DIRNAME/../../src/dotfiles/.claude/statusline-command.sh" "$SL"
    chmod +x "$SL"

    # A plain directory with no git repo, so the branch segment stays out
    # unless a test builds a repo
    export PLAIN="$TEST_DIR/plain"
    mkdir -p "$PLAIN"

    NOW=$(date +%s)
    export NOW
}

teardown() {
    rm -rf "$TEST_DIR"
}

strip_ansi() {
    sed "s/$(printf '\033')\\[[0-9;]*m//g"
}

# Run the statusline against a JSON document; $output has ANSI codes stripped
run_sl() {
    run bash -c "printf '%s' \"\$1\" | \"$SL\"" _ "$1"
    output=$(printf '%s' "$output" | strip_ansi)
}

json() {
    # $1 dir; the rest is extra JSON members (no leading comma)
    local dir="$1" extra="${2:-}"
    if [ -n "$extra" ]; then
        printf '{"workspace":{"current_dir":"%s"},%s}' "$dir" "$extra"
    else
        printf '{"workspace":{"current_dir":"%s"}}' "$dir"
    fi
}

# "rate_limits" member from triples: window pct seconds-from-now, e.g.
# `rate_limits five_hour 4 9240 seven_day 20 259230`. Built here rather than
# inline because bash 3.2 brace-expands `{\"a\":1,\"b\":2}` nested inside
# "$( )", which turns the fixture into invalid JSON on macOS.
rate_limits() {
    local out="" member
    while [ $# -ge 3 ]; do
        member=$(printf '"%s":{"used_percentage":%s,"resets_at":%s}' "$1" "$2" "$((NOW + $3))")
        out="${out:+$out,}$member"
        shift 3
    done
    printf '"rate_limits":{%s}' "$out"
}

# ============================================================================
# PATH SQUEEZE
# ============================================================================

@test "path: HOME becomes ~ and middle components shrink to one letter" {
    mkdir -p "$HOME/dev/worktrees/nxt-reels"
    run_sl "$(json "$HOME/dev/worktrees/nxt-reels")"
    [ "$status" -eq 0 ]
    [ "$output" = "~/d/worktrees/nxt-reels" ]
}

@test "path: dot-dirs keep two letters, last two components stay whole" {
    mkdir -p "$HOME/.config/nvim/lua/plugins"
    run_sl "$(json "$HOME/.config/nvim/lua/plugins")"
    [ "$output" = "~/.c/n/lua/plugins" ]
}

@test "path: a kept component with a ticket-key prefix drops its description" {
    mkdir -p "$HOME/dev/worktrees/nxt-reels/RLS-752-long-description"
    run_sl "$(json "$HOME/dev/worktrees/nxt-reels/RLS-752-long-description")"
    [ "$output" = "~/d/w/nxt-reels/RLS-752…" ]
}

@test "path: HOME itself is ~" {
    run_sl "$(json "$HOME")"
    [ "$output" = "~" ]
}

@test "path: missing current_dir falls back to cwd" {
    cd "$PLAIN"
    run bash -c "printf '{}' | \"$SL\""
    output=$(printf '%s' "$output" | strip_ansi)
    [[ "$output" == *"plain" ]]
}

# ============================================================================
# GIT SEGMENT
# ============================================================================

make_repo() {
    export REPO="$TEST_DIR/repo"
    git init -q "$REPO"
    git -C "$REPO" config user.email t@example.com
    git -C "$REPO" config user.name T
    printf 'one\ntwo\nthree\n' > "$REPO/f.txt"
    git -C "$REPO" add f.txt
    git -C "$REPO" commit -q -m init
}

@test "git: clean repo shows the branch with no marker or counts" {
    make_repo
    git -C "$REPO" switch -q -c feature
    run_sl "$(json "$REPO")"
    [[ "$output" == *" · feature" ]]
    [[ "$output" != *"*"* ]]
}

@test "git: dirty repo gets a * and +added -removed line counts" {
    make_repo
    git -C "$REPO" switch -q -c feature
    printf 'one\nchanged\nthree\nfour\nfive\n' > "$REPO/f.txt"
    run_sl "$(json "$REPO")"
    [[ "$output" == *"feature* +3 -1"* ]]
}

@test "git: ticket-key branch is squeezed to prefix and key" {
    make_repo
    git -C "$REPO" switch -q -c tv/RLS-752-long-description
    run_sl "$(json "$REPO")"
    [[ "$output" == *" · tv/RLS-752…" ]]
}

@test "git: a branch that is exactly a ticket key gets no marker" {
    make_repo
    git -C "$REPO" switch -q -c RLS-752
    run_sl "$(json "$REPO")"
    [[ "$output" == *" · RLS-752" ]]
}

@test "git: long plain branch is capped at 24 chars plus …" {
    make_repo
    git -C "$REPO" switch -q -c abcdefghijklmnopqrstuvwxyz0123
    run_sl "$(json "$REPO")"
    [[ "$output" == *" · abcdefghijklmnopqrstuvwx…" ]]
}

@test "git: ahead/behind upstream shows arrows" {
    make_repo
    git -C "$REPO" switch -q -c feature
    git clone -q "$REPO" "$TEST_DIR/clone"
    git -C "$TEST_DIR/clone" config user.email t@example.com
    git -C "$TEST_DIR/clone" config user.name T
    echo x > "$TEST_DIR/clone/new.txt"
    git -C "$TEST_DIR/clone" add new.txt
    git -C "$TEST_DIR/clone" commit -q -m ahead
    run_sl "$(json "$TEST_DIR/clone")"
    [[ "$output" == *"feature ↑1"* ]]
}

# ============================================================================
# MODEL, EFFORT, CONTEXT
# ============================================================================

@test "model: model and effort render as Name (effort)" {
    run_sl "$(json "$PLAIN" '"model":{"display_name":"Fable 5"},"effort":{"level":"high"}')"
    [[ "$output" == *" · Fable 5 (high)" ]]
}

@test "model: effort alone renders without parens" {
    run_sl "$(json "$PLAIN" '"effort":{"level":"high"}')"
    [[ "$output" == *" · high" ]]
}

@test "ctx: hidden below 60 percent" {
    run_sl "$(json "$PLAIN" '"context_window":{"used_percentage":59}')"
    [[ "$output" != *"ctx"* ]]
}

@test "ctx: shown at 60 percent and above" {
    run_sl "$(json "$PLAIN" '"context_window":{"used_percentage":60.4}')"
    [[ "$output" == *" · ctx 60%" ]]
}

# ============================================================================
# USAGE SEGMENTS - percent, time left, pace
# ============================================================================

@test "usage: 5h segment shows percent and hours left, floored to tenths" {
    # 2h34m left = 9240s -> 25.6 tenths of an hour -> "2.5h"
    run_sl "$(json "$PLAIN" "$(rate_limits five_hour 4 9240)")"
    [[ "$output" == *" · 5h 4% (2.5h)" ]]
}

@test "usage: under an hour shows minutes; over a day shows days" {
    # Fixtures sit ~30s past each boundary: the script reads the clock a
    # second or two after setup did, and tenths are floored
    run_sl "$(json "$PLAIN" "$(rate_limits five_hour 10 2630 seven_day 20 259230)")"
    [[ "$output" == *" · 5h 10% (43m) · 7d 20% (3d)" ]]
}

@test "usage: whole hours print without a decimal" {
    run_sl "$(json "$PLAIN" "$(rate_limits five_hour 10 7230)")"
    [[ "$output" == *"(2h)"* ]]
}

@test "usage: past or missing reset drops the time-left part" {
    run_sl "$(json "$PLAIN" "$(rate_limits five_hour 10 -5)")"
    [[ "$output" == *" · 5h 10%" ]]
    [[ "$output" != *"("* ]]
}

@test "pace: burn ratio appears when over 1.2x the window pace" {
    # 60% used with 14990s of the 18000s window left: elapsed ~3010,
    # ratio = 60*18000/(3010*10) = 35 tenths -> "3.5x", past the 1.6x red line
    run_sl "$(json "$PLAIN" "$(rate_limits five_hour 60 14990)")"
    [[ "$output" == *"5h 60% (4.1h 3.5x)"* ]]
}

@test "pace: on-pace usage under 50 percent shows no ratio" {
    # 30% used, 70% of the window left: ratio 1.0x, and pct < 50 -> dim, no ratio
    run_sl "$(json "$PLAIN" "$(rate_limits five_hour 30 12630)")"
    [[ "$output" == *"5h 30% (3.5h)"* ]]
    [[ "$output" != *"x)"* ]]
}

@test "pace: on-pace usage at 50 percent or more shows the ratio as reassurance" {
    # 50% used, half the window left: ratio 1.0x, pct >= 50 -> green with ratio
    run_sl "$(json "$PLAIN" "$(rate_limits five_hour 50 9030)")"
    [[ "$output" == *"5h 50% (2.5h 1.0x)"* ]]
}

@test "pace: below 25 percent used the ratio is never shown" {
    # 20% used with almost no time left would be a huge ratio; suppressed
    run_sl "$(json "$PLAIN" "$(rate_limits five_hour 20 100)")"
    [[ "$output" == *"5h 20% (1m)"* ]]
}

# ============================================================================
# WEEKLY FALLBACK - plans without rate_limits.seven_day use the /usage cache
# ============================================================================

@test "weekly: absent seven_day falls back to the cached weekly limit" {
    cat > "$HOME/.claude.json" <<EOF
{"cachedUsageUtilization":{"utilization":{"limits":[
  {"group":"weekly","percent":61.2,"resets_at":"$(date -u -r $((NOW + 259230)) +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -d @$((NOW + 259230)) +%Y-%m-%dT%H:%M:%S).123456+00:00"},
  {"group":"weekly","percent":12,"resets_at":"2030-01-01T00:00:00+00:00"},
  {"group":"five_hour","percent":99}
]}}}
EOF
    run_sl "$(json "$PLAIN")"
    # 61% used with 3 of 7 days left is 1.0x pace; at >= 50% the ratio shows
    [[ "$output" == *" · 7d 61% (3d 1.0x)" ]]
}

@test "weekly: stdin seven_day wins over the cache" {
    printf '{"cachedUsageUtilization":{"utilization":{"limits":[{"group":"weekly","percent":90}]}}}' > "$HOME/.claude.json"
    run_sl "$(json "$PLAIN" "$(rate_limits seven_day 20 90000)")"
    [[ "$output" == *" · 7d 20% (1d)" ]]
    [[ "$output" != *"90"* ]]
}

@test "weekly: no cache and no seven_day shows no 7d segment" {
    run_sl "$(json "$PLAIN")"
    [[ "$output" != *"7d"* ]]
}
