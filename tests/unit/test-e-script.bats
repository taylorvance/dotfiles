#!/usr/bin/env bats

# Unit tests for the `e` script (editor wrapper)

setup() {
    # Create temporary test directory
    export TEST_DIR=$(mktemp -d)
    export TEST_REPO="$TEST_DIR/repo"

    # Create a git repo for testing
    mkdir -p "$TEST_REPO"
    cd "$TEST_REPO"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Copy the e script to test location
    cp "$BATS_TEST_DIRNAME/../../src/dotfiles/.local/bin/e" "$TEST_DIR/e"
    chmod +x "$TEST_DIR/e"

    # Mock editor to capture what files would be opened
    export EDITOR="$TEST_DIR/mock-editor"
    cat > "$EDITOR" <<'EOF'
#!/bin/bash
# Mock editor that just prints the files it would open
for arg in "$@"; do
    echo "$arg"
done
EOF
    chmod +x "$EDITOR"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Helper to run e script and capture output
run_e() {
    cd "$TEST_REPO"
    run "$TEST_DIR/e" "$@"
}

# ============================================================================
# BASIC FILE SET TESTS
# ============================================================================

@test "e -m: opens modified files" {
    # Setup: create and modify files
    echo "content" > file1.txt
    echo "content" > file2.txt
    git add .
    git commit -q -m "initial"
    echo "modified" > file1.txt

    # Run
    run_e -m

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" != *"file2.txt"* ]]
}

@test "e -u: opens untracked files" {
    # Setup: create tracked and untracked files
    echo "tracked" > mytracked.txt
    git add mytracked.txt
    git commit -q -m "initial"
    echo "untracked" > newfile.txt

    # Run
    run_e -u

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"newfile.txt"* ]]
    [[ "$output" != *"mytracked.txt"* ]]
}

@test "e -mu: opens modified and untracked files" {
    # Setup
    echo "tracked" > tracked.txt
    git add tracked.txt
    git commit -q -m "initial"
    echo "modified" > tracked.txt
    echo "untracked" > untracked.txt

    # Run
    run_e -mu

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"tracked.txt"* ]]
    [[ "$output" == *"untracked.txt"* ]]
}

@test "e -a: opens all tracked files" {
    # Setup
    echo "file1" > file1.txt
    echo "file2" > file2.txt
    echo "untracked" > untracked.txt
    git add file1.txt file2.txt
    git commit -q -m "initial"

    # Run
    run_e -a

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" == *"file2.txt"* ]]
    [[ "$output" != *"untracked.txt"* ]]
}

# ============================================================================
# COMPOSITION TESTS - COMBINING FILTERS
# ============================================================================

@test "e -m -g PATTERN: modified files containing pattern" {
    # Setup
    echo "has TODO" > file1.txt
    echo "no pattern" > file2.txt
    git add .
    git commit -q -m "initial"
    echo "modified TODO" > file1.txt
    echo "modified" > file2.txt

    # Run
    run_e -m -g TODO

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" != *"file2.txt"* ]]
}

@test "e -g PATTERN -n NAMEPATTERN: content and name filters combined" {
    # Setup
    echo "has TODO" > test1.py
    echo "no pattern" > test2.py
    echo "has TODO" > other.txt
    git add .
    git commit -q -m "initial"

    # Run: files with TODO and .py in name
    run_e -g TODO -n '\.py'

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"test1.py"* ]]
    [[ "$output" != *"test2.py"* ]]
    [[ "$output" != *"other.txt"* ]]
}

@test "e -u -n PATTERN: untracked files with name pattern" {
    # Setup
    echo "tracked" > tracked.txt
    git add tracked.txt
    git commit -q -m "initial"
    echo "untracked" > test.py
    echo "untracked" > other.txt

    # Run
    run_e -u -n '\.py'

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"test.py"* ]]
    [[ "$output" != *"other.txt"* ]]
}

@test "e -u -n PATTERN: finds files inside untracked directories" {
    # Setup: create tracked file and untracked directory with files
    echo "tracked" > tracked.txt
    git add tracked.txt
    git commit -q -m "initial"
    mkdir -p newdir
    echo "untracked" > newdir/temp.txt
    echo "untracked" > newdir/other.txt

    # Run: should find temp.txt inside untracked directory
    run_e -u -n temp

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"newdir/temp.txt"* ]]
    [[ "$output" != *"other.txt"* ]]
}

# ============================================================================
# POSITIONAL FILTER TESTS
# ============================================================================

@test "e -m FILTER: modified files with positional filter" {
    # Setup
    echo "content" > component.js
    echo "content" > other.js
    git add .
    git commit -q -m "initial"
    echo "modified" > component.js
    echo "modified" > other.js

    # Run
    run_e -m component

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"component.js"* ]]
    [[ "$output" != *"other.js"* ]]
}

@test "e -g PATTERN FILTER: content search with filename filter" {
    # Setup
    echo "has TODO" > test.py
    echo "has TODO" > component.py
    echo "no pattern" > other.py
    git add .
    git commit -q -m "initial"

    # Run: files with TODO and "component" in filename
    run_e -g TODO component

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"component.py"* ]]
    [[ "$output" != *"test.py"* ]]
    [[ "$output" != *"other.py"* ]]
}

@test "e -a FILTER: all tracked files with positional filter" {
    # Setup
    echo "content" > test1.txt
    echo "content" > test2.txt
    echo "content" > other.txt
    git add .
    git commit -q -m "initial"

    # Run
    run_e -a test

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"test1.txt"* ]]
    [[ "$output" == *"test2.txt"* ]]
    [[ "$output" != *"other.txt"* ]]
}

# ============================================================================
# COMBINED SHORT FLAGS
# ============================================================================

@test "e -mui: combined short flags work" {
    skip "Interactive mode requires fzf"
    # This would test -m -u -i combined, but requires fzf
}

@test "e -ai: combined short flags for all files interactive" {
    skip "Interactive mode requires fzf"
    # This would test -a -i combined, but requires fzf
}

@test "e -i: implies -a (all tracked files)" {
    # Setup: mock fzf to just pass through
    cat > "$TEST_DIR/fzf" <<'EOF'
#!/bin/bash
cat
EOF
    chmod +x "$TEST_DIR/fzf"
    export PATH="$TEST_DIR:$PATH"

    # Create tracked files
    echo "file1" > file1.txt
    echo "file2" > file2.txt
    echo "untracked" > untracked.txt
    git add file1.txt file2.txt
    git commit -q -m "initial"

    # Run
    run_e -i

    # Assert: should get all tracked files (not untracked)
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" == *"file2.txt"* ]]
    [[ "$output" != *"untracked.txt"* ]]
}

@test "e -i FILTER: filters all tracked files with positional arg" {
    # Setup: mock fzf to just pass through
    cat > "$TEST_DIR/fzf" <<'EOF'
#!/bin/bash
cat
EOF
    chmod +x "$TEST_DIR/fzf"
    export PATH="$TEST_DIR:$PATH"

    # Create tracked files
    echo "content" > component.js
    echo "content" > helper.js
    echo "content" > test.js
    git add .
    git commit -q -m "initial"

    # Run: -i with positional filter
    run_e -i component

    # Assert: should only get files matching "component"
    [ "$status" -eq 0 ]
    [[ "$output" == *"component.js"* ]]
    [[ "$output" != *"helper.js"* ]]
    [[ "$output" != *"test.js"* ]]
}

# ============================================================================
# ERROR CASES
# ============================================================================

@test "e -a test component: only one positional filter allowed" {
    # Setup
    echo "test" > test.txt
    git add test.txt
    git commit -q -m "initial"

    # Run: multiple positional args with filters should error
    run_e -a test component

    # Assert
    [ "$status" -ne 0 ]
    [[ "$output" == *"Only one positional filter allowed"* ]]
}

@test "e -ma: -a is superset of -m, opens all tracked files" {
    # Setup
    echo "file1" > file1.txt
    echo "file2" > file2.txt
    git add .
    git commit -q -m "initial"
    echo "modified" > file1.txt

    # Run: -ma should behave like -a
    run_e -ma

    # Assert: should get all tracked files
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" == *"file2.txt"* ]]
}

@test "e -a -d: cannot combine -a with -d" {
    # Run
    run_e -a -d

    # Assert
    [ "$status" -ne 0 ]
    [[ "$output" == *"Cannot combine"* ]]
}

@test "e -au: all tracked plus untracked (everything)" {
    # Setup
    echo "tracked1" > tracked1.txt
    echo "tracked2" > tracked2.txt
    git add .
    git commit -q -m "initial"
    echo "untracked" > untracked.txt

    # Run
    run_e -au

    # Assert: should get all tracked AND untracked
    [ "$status" -eq 0 ]
    [[ "$output" == *"tracked1.txt"* ]]
    [[ "$output" == *"tracked2.txt"* ]]
    [[ "$output" == *"untracked.txt"* ]]
}

@test "e -amu: same as -au (everything)" {
    # Setup
    echo "tracked" > tracked.txt
    git add .
    git commit -q -m "initial"
    echo "modified" > tracked.txt
    echo "untracked" > untracked.txt

    # Run
    run_e -amu

    # Assert: should get everything
    [ "$status" -eq 0 ]
    [[ "$output" == *"tracked.txt"* ]]
    [[ "$output" == *"untracked.txt"* ]]
}

@test "e -g: requires pattern argument" {
    # Run
    run_e -g

    # Assert
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires a pattern"* ]]
}

@test "e -n: requires pattern argument" {
    # Run
    run_e -n

    # Assert
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires a pattern"* ]]
}

# ============================================================================
# BASIC USAGE TESTS
# ============================================================================

@test "e file.txt: opens specified file" {
    # Run
    run_e file.txt

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"file.txt"* ]]
}

@test "e file1.txt file2.txt: opens multiple files" {
    # Run
    run_e file1.txt file2.txt

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" == *"file2.txt"* ]]
}

@test "e: opens editor with no files" {
    # Run
    run_e

    # Assert
    [ "$status" -eq 0 ]
    # Empty output is fine - just opens editor
}

# ============================================================================
# HELP TEXT
# ============================================================================

@test "e -h: shows help message" {
    # Run
    run_e -h

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"COMPOSITION"* ]]
    [[ "$output" == *"FILE SET OPTIONS"* ]]
    [[ "$output" == *"FILTER OPTIONS"* ]]
}

@test "e --help: shows help message" {
    # Run
    run_e --help

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"COMPOSITION"* ]]
}

# ============================================================================
# SUBDIRECTORY TESTS - Running from within repo subdirectories
# ============================================================================

# Helper to run e script from a subdirectory
run_e_from_subdir() {
    local subdir="$1"
    shift
    cd "$TEST_REPO/$subdir"
    run "$TEST_DIR/e" "$@"
}

@test "e -u from subdirectory: paths are correct" {
    # Setup: create subdirectory structure
    mkdir -p "$TEST_REPO/apps/overlay/src"
    echo "tracked" > "$TEST_REPO/apps/overlay/tracked.txt"
    git -C "$TEST_REPO" add apps/overlay/tracked.txt
    git -C "$TEST_REPO" commit -q -m "initial"
    echo "untracked" > "$TEST_REPO/apps/overlay/src/newfile.txt"

    # Run from subdirectory
    run_e_from_subdir "apps/overlay" -u

    # Assert: path should be absolute and correct
    [ "$status" -eq 0 ]
    [[ "$output" == *"apps/overlay/src/newfile.txt"* ]]
    # Should NOT have wrong path like just "src/newfile.txt" prepended to git root
    [[ "$output" != *"$TEST_REPO/src/newfile.txt" ]]
}

@test "e -u FILTER from subdirectory: finds files with correct paths" {
    # Setup: this is the exact scenario from the bug report
    mkdir -p "$TEST_REPO/apps/overlay/src/test"
    echo "tracked" > "$TEST_REPO/apps/overlay/tracked.txt"
    git -C "$TEST_REPO" add apps/overlay/tracked.txt
    git -C "$TEST_REPO" commit -q -m "initial"
    echo "mock data" > "$TEST_REPO/apps/overlay/src/test/mockData.ts"

    # Run from subdirectory with filter
    run_e_from_subdir "apps/overlay" -u mock

    # Assert: should find the file with correct full path
    [ "$status" -eq 0 ]
    [[ "$output" == *"apps/overlay/src/test/mockData.ts"* ]]
}

@test "e -m from subdirectory: paths are correct" {
    # Setup
    mkdir -p "$TEST_REPO/src/components"
    echo "content" > "$TEST_REPO/src/components/Button.tsx"
    git -C "$TEST_REPO" add .
    git -C "$TEST_REPO" commit -q -m "initial"
    echo "modified" > "$TEST_REPO/src/components/Button.tsx"

    # Run from subdirectory
    run_e_from_subdir "src" -m

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"src/components/Button.tsx"* ]]
}

@test "e -a from subdirectory: paths are correct" {
    # Setup
    mkdir -p "$TEST_REPO/lib/utils"
    echo "util1" > "$TEST_REPO/lib/utils/helper.js"
    echo "util2" > "$TEST_REPO/lib/utils/format.js"
    git -C "$TEST_REPO" add .
    git -C "$TEST_REPO" commit -q -m "initial"

    # Run from subdirectory
    run_e_from_subdir "lib/utils" -a

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"lib/utils/helper.js"* ]]
    [[ "$output" == *"lib/utils/format.js"* ]]
}

@test "e -a FILTER from subdirectory: filters work with correct paths" {
    # Setup
    mkdir -p "$TEST_REPO/packages/core/src"
    echo "test1" > "$TEST_REPO/packages/core/src/test.spec.ts"
    echo "main" > "$TEST_REPO/packages/core/src/index.ts"
    git -C "$TEST_REPO" add .
    git -C "$TEST_REPO" commit -q -m "initial"

    # Run from deep subdirectory with filter
    run_e_from_subdir "packages/core/src" -a spec

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"packages/core/src/test.spec.ts"* ]]
    [[ "$output" != *"index.ts"* ]]
}

@test "e -g PATTERN from subdirectory: content search with correct paths" {
    # Setup
    mkdir -p "$TEST_REPO/modules/auth"
    echo "// TODO: implement" > "$TEST_REPO/modules/auth/login.ts"
    echo "done" > "$TEST_REPO/modules/auth/logout.ts"
    git -C "$TEST_REPO" add .
    git -C "$TEST_REPO" commit -q -m "initial"

    # Run from subdirectory
    run_e_from_subdir "modules" -g TODO

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"modules/auth/login.ts"* ]]
    [[ "$output" != *"logout.ts"* ]]
}
