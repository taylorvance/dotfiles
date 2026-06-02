#!/usr/bin/env bats

# Unit tests for the envsync script

setup() {
    export TEST_DIR=$(mktemp -d)
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME"

    cp "$BATS_TEST_DIRNAME/../../src/dotfiles/.local/bin/envsync" "$TEST_DIR/envsync"
    chmod +x "$TEST_DIR/envsync"

    export PROJ="$TEST_DIR/project"
    mkdir -p "$PROJ"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ============================================================================
# HELP
# ============================================================================

@test "envsync -h: shows usage" {
    run "$TEST_DIR/envsync" -h

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: envsync"* ]]
    [[ "$output" == *"-d"* ]]
    [[ "$output" == *"-n"* ]]
}

@test "envsync --help: works" {
    run "$TEST_DIR/envsync" --help

    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: envsync"* ]]
}

# ============================================================================
# ARGUMENT ERRORS
# ============================================================================

@test "envsync: unknown option fails" {
    run "$TEST_DIR/envsync" --invalid

    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "envsync: invalid directory fails" {
    run "$TEST_DIR/envsync" /nonexistent/path

    [ "$status" -ne 0 ]
    [[ "$output" == *"not a directory"* ]]
}

# ============================================================================
# DISCOVERY - SAMPLE FILE PATTERNS
# ============================================================================

@test "envsync: finds .env.sample" {
    printf 'KEY=value\n' > "$PROJ/.env.sample"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *".env.sample"* ]]
}

@test "envsync: finds .env.example" {
    printf 'KEY=value\n' > "$PROJ/.env.example"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *".env.example"* ]]
}

@test "envsync: finds .env.template" {
    printf 'KEY=value\n' > "$PROJ/.env.template"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *".env.template"* ]]
}

@test "envsync: finds .env.dist" {
    printf 'KEY=value\n' > "$PROJ/.env.dist"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *".env.dist"* ]]
}

@test "envsync: finds example.env" {
    printf 'KEY=value\n' > "$PROJ/example.env"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"example.env"* ]]
}

@test "envsync: finds sample.env" {
    printf 'KEY=value\n' > "$PROJ/sample.env"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"sample.env"* ]]
}

@test "envsync: finds *.env.sample and maps to correct actual" {
    printf 'KEY=value\n' > "$PROJ/production.env.sample"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"production.env.sample"* ]]
    [[ "$output" == *"production.env"* ]]
}

@test "envsync: no sample files shows message" {
    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"No sample env files found"* ]]
}

# ============================================================================
# DISCOVERY - SKIPPED DIRECTORIES
# ============================================================================

@test "envsync: skips node_modules" {
    mkdir -p "$PROJ/node_modules/pkg"
    printf 'SKIP=yes\n' > "$PROJ/node_modules/pkg/.env.sample"
    printf 'REAL=value\n' > "$PROJ/.env.sample"
    printf 'REAL=value\n' > "$PROJ/.env"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" != *"node_modules"* ]]
}

@test "envsync: skips .git" {
    mkdir -p "$PROJ/.git"
    printf 'SKIP=yes\n' > "$PROJ/.git/.env.sample"
    printf 'REAL=value\n' > "$PROJ/.env.sample"
    printf 'REAL=value\n' > "$PROJ/.env"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" != *".git/.env"* ]]
}

@test "envsync: skips .venv" {
    mkdir -p "$PROJ/.venv/lib"
    printf 'SKIP=yes\n' > "$PROJ/.venv/lib/.env.sample"
    printf 'REAL=value\n' > "$PROJ/.env.sample"
    printf 'REAL=value\n' > "$PROJ/.env"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" != *".venv"* ]]
}

# ============================================================================
# MISSING VAR DETECTION
# ============================================================================

@test "envsync: reports missing variable with sample value" {
    printf 'DB_HOST=localhost\n' > "$PROJ/.env.sample"
    touch "$PROJ/.env"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DB_HOST=localhost"* ]]
}

@test "envsync: reports [no actual file] when .env is absent" {
    printf 'DB_HOST=localhost\n' > "$PROJ/.env.sample"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"no actual file"* ]]
    [[ "$output" == *"DB_HOST=localhost"* ]]
}

@test "envsync: reports all in sync when all vars present" {
    printf 'DB_HOST=localhost\nDB_PORT=5432\n' > "$PROJ/.env.sample"
    printf 'DB_HOST=prod.db\nDB_PORT=5432\n' > "$PROJ/.env"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"All env files are in sync"* ]]
}

@test "envsync: reports count of missing vars" {
    printf 'DB_HOST=localhost\nDB_PORT=5432\nSECRET=changeme\n' > "$PROJ/.env.sample"
    printf 'DB_HOST=prod.db\n' > "$PROJ/.env"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"DB_PORT"* ]]
    [[ "$output" == *"SECRET"* ]]
    [[ "$output" == *"2 missing"* ]]
}

@test "envsync: ignores comment lines and blank lines in sample" {
    printf '# comment\n\nDB_HOST=localhost\n' > "$PROJ/.env.sample"
    printf 'DB_HOST=prod.db\n' > "$PROJ/.env"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"All env files are in sync"* ]]
}

@test "envsync: empty sample file produces no findings" {
    touch "$PROJ/.env.sample"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"All env files are in sync"* ]]
}

# ============================================================================
# DIFF MODE
# ============================================================================

@test "envsync -d: shows [different] when values differ" {
    printf 'DB_HOST=localhost\n' > "$PROJ/.env.sample"
    printf 'DB_HOST=prod.db\n' > "$PROJ/.env"

    run "$TEST_DIR/envsync" -d -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"[different]"* ]]
    [[ "$output" == *"DB_HOST"* ]]
}

@test "envsync: does not show [different] without -d flag" {
    printf 'DB_HOST=localhost\n' > "$PROJ/.env.sample"
    printf 'DB_HOST=prod.db\n' > "$PROJ/.env"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"All env files are in sync"* ]]
    [[ "$output" != *"[different]"* ]]
}

@test "envsync -d: shows sample and actual values" {
    printf 'APP_ENV=development\n' > "$PROJ/.env.sample"
    printf 'APP_ENV=production\n' > "$PROJ/.env"

    run "$TEST_DIR/envsync" -d -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"development"* ]]
    [[ "$output" == *"production"* ]]
}

@test "envsync -d: shows <empty> for empty actual value" {
    printf 'API_KEY=default\n' > "$PROJ/.env.sample"
    printf 'API_KEY=\n' > "$PROJ/.env"

    run "$TEST_DIR/envsync" -d -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"[different]"* ]]
    [[ "$output" == *"<empty>"* ]]
}

# ============================================================================
# DRY RUN
# ============================================================================

@test "envsync -n: shows findings without prompting" {
    printf 'KEY=value\n' > "$PROJ/.env.sample"
    touch "$PROJ/.env"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"KEY=value"* ]]
    [[ "$output" != *"Copy"* ]]
}

@test "envsync -n: does not modify actual file" {
    printf 'KEY=value\n' > "$PROJ/.env.sample"
    printf 'EXISTING=yes\n' > "$PROJ/.env"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    [ "$content" = "EXISTING=yes" ]
}

# ============================================================================
# COPY MISSING
# ============================================================================

@test "envsync: y appends missing var to actual file" {
    printf 'DB_HOST=localhost\n' > "$PROJ/.env.sample"
    printf 'EXISTING=yes\n' > "$PROJ/.env"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" "$PROJ"'

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    [[ "$content" == *"DB_HOST=localhost"* ]]
}

@test "envsync: y creates actual file when absent" {
    printf 'DB_HOST=localhost\n' > "$PROJ/.env.sample"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" "$PROJ"'

    [ "$status" -eq 0 ]
    [ -f "$PROJ/.env" ]
    content=$(cat "$PROJ/.env")
    [[ "$content" == *"DB_HOST=localhost"* ]]
}

@test "envsync: y preserves existing content" {
    printf 'NEW_KEY=value\n' > "$PROJ/.env.sample"
    printf 'EXISTING=keep_me\n' > "$PROJ/.env"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" "$PROJ"'

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    [[ "$content" == *"EXISTING=keep_me"* ]]
    [[ "$content" == *"NEW_KEY=value"* ]]
}

@test "envsync: y adds envsync marker comment" {
    printf 'KEY=value\n' > "$PROJ/.env.sample"
    touch "$PROJ/.env"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" "$PROJ"'

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    [[ "$content" == *"# envsync added"* ]]
}

@test "envsync: y copies single preceding comment line" {
    printf '# The database host\nDB_HOST=localhost\n' > "$PROJ/.env.sample"
    touch "$PROJ/.env"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" "$PROJ"'

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    [[ "$content" == *"# The database host"* ]]
    [[ "$content" == *"DB_HOST=localhost"* ]]
}

@test "envsync: y copies multi-line preceding comment block" {
    printf '# The database host\n# See infra docs\nDB_HOST=localhost\n' > "$PROJ/.env.sample"
    touch "$PROJ/.env"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" "$PROJ"'

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    [[ "$content" == *"# The database host"* ]]
    [[ "$content" == *"# See infra docs"* ]]
    [[ "$content" == *"DB_HOST=localhost"* ]]
}

@test "envsync: y does not re-add already-present vars" {
    printf 'DB_HOST=localhost\nDB_PORT=5432\n' > "$PROJ/.env.sample"
    printf 'DB_HOST=prod.db\n' > "$PROJ/.env"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" "$PROJ"'

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    # Missing var was added
    [[ "$content" == *"DB_PORT=5432"* ]]
    # Existing var was preserved as-is, sample value was not copied
    [[ "$content" == *"DB_HOST=prod.db"* ]]
    [[ "$content" != *"DB_HOST=localhost"* ]]
}

@test "envsync: N does not modify actual file" {
    printf 'KEY=value\n' > "$PROJ/.env.sample"
    printf 'EXISTING=yes\n' > "$PROJ/.env"

    run bash -c 'printf "N\n" | "$TEST_DIR/envsync" "$PROJ"'

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    [ "$content" = "EXISTING=yes" ]
}

@test "envsync: default (enter) does not modify actual file" {
    printf 'KEY=value\n' > "$PROJ/.env.sample"
    printf 'EXISTING=yes\n' > "$PROJ/.env"

    run bash -c 'printf "\n" | "$TEST_DIR/envsync" "$PROJ"'

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    [ "$content" = "EXISTING=yes" ]
}

# ============================================================================
# OVERWRITE DIFFERENT (--diff mode)
# ============================================================================

@test "envsync -d: y updates value in actual file" {
    printf 'DB_HOST=localhost\n' > "$PROJ/.env.sample"
    printf 'DB_HOST=prod.db\n' > "$PROJ/.env"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" -d "$PROJ"'

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    [[ "$content" == *"DB_HOST=localhost"* ]]
}

@test "envsync -d: y creates .envsync-bak before overwriting" {
    printf 'DB_HOST=localhost\n' > "$PROJ/.env.sample"
    printf 'DB_HOST=prod.db\n' > "$PROJ/.env"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" -d "$PROJ"'

    [ "$status" -eq 0 ]
    [ -f "$PROJ/.env.envsync-bak" ]
    bak=$(cat "$PROJ/.env.envsync-bak")
    [[ "$bak" == *"DB_HOST=prod.db"* ]]
}

@test "envsync -d: y preserves other vars in actual file" {
    printf 'DB_HOST=localhost\n' > "$PROJ/.env.sample"
    printf 'DB_HOST=prod.db\nDB_PORT=5432\n' > "$PROJ/.env"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" -d "$PROJ"'

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    [[ "$content" == *"DB_PORT=5432"* ]]
}

@test "envsync -d: N does not modify actual file" {
    printf 'DB_HOST=localhost\n' > "$PROJ/.env.sample"
    printf 'DB_HOST=prod.db\n' > "$PROJ/.env"

    run bash -c 'printf "N\n" | "$TEST_DIR/envsync" -d "$PROJ"'

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    [[ "$content" == *"DB_HOST=prod.db"* ]]
}

# ============================================================================
# SYMLINK HANDLING
# ============================================================================

@test "envsync -d: writes through symlinks without replacing them" {
    printf 'DB_HOST=localhost\n' > "$PROJ/.env.sample"
    printf 'DB_HOST=prod.db\n' > "$TEST_DIR/real.env"
    ln -s "$TEST_DIR/real.env" "$PROJ/.env"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" -d "$PROJ"'

    [ "$status" -eq 0 ]
    [ -L "$PROJ/.env" ]
    content=$(cat "$PROJ/.env")
    [[ "$content" == *"DB_HOST=localhost"* ]]
}

# ============================================================================
# VALUES WITH SPECIAL CHARACTERS
# ============================================================================

@test "envsync: handles value containing = sign" {
    printf 'ENCODED=abc=def==\n' > "$PROJ/.env.sample"
    touch "$PROJ/.env"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" "$PROJ"'

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    [[ "$content" == *"ENCODED=abc=def=="* ]]
}

@test "envsync: handles empty value" {
    printf 'API_KEY=\n' > "$PROJ/.env.sample"
    touch "$PROJ/.env"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" "$PROJ"'

    [ "$status" -eq 0 ]
    content=$(cat "$PROJ/.env")
    [[ "$content" == *"API_KEY="* ]]
}

# ============================================================================
# MULTIPLE SAMPLE FILES
# ============================================================================

@test "envsync: handles multiple sample files in subdirectories" {
    mkdir -p "$PROJ/app" "$PROJ/worker"
    printf 'APP_KEY=value\n' > "$PROJ/app/.env.sample"
    printf 'WORKER_KEY=value\n' > "$PROJ/worker/.env.sample"
    touch "$PROJ/app/.env"
    touch "$PROJ/worker/.env"

    run "$TEST_DIR/envsync" -n "$PROJ"

    [ "$status" -eq 0 ]
    [[ "$output" == *"APP_KEY"* ]]
    [[ "$output" == *"WORKER_KEY"* ]]
}

@test "envsync: copies missing vars to correct file in each subdirectory" {
    mkdir -p "$PROJ/app" "$PROJ/worker"
    printf 'APP_KEY=avalue\n' > "$PROJ/app/.env.sample"
    printf 'WORKER_KEY=wvalue\n' > "$PROJ/worker/.env.sample"
    touch "$PROJ/app/.env"
    touch "$PROJ/worker/.env"

    run bash -c 'printf "y\n" | "$TEST_DIR/envsync" "$PROJ"'

    [ "$status" -eq 0 ]
    [[ "$(cat "$PROJ/app/.env")" == *"APP_KEY=avalue"* ]]
    [[ "$(cat "$PROJ/worker/.env")" == *"WORKER_KEY=wvalue"* ]]
}

# ============================================================================
# INTERACTIVE MODE
# ============================================================================

@test "envsync: script checks for fzf in interactive mode" {
    grep -q 'command -v fzf' "$TEST_DIR/envsync"
    grep -q 'fzf required for interactive mode' "$TEST_DIR/envsync"
}
