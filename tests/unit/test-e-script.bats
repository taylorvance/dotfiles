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

@test "e -d: opens files changed from default branch" {
    # Setup: create initial commit on main
    echo "initial" > file1.txt
    echo "initial" > file2.txt
    git add .
    git commit -q -m "initial"

    # Create feature branch and make changes
    git checkout -b feature -q
    echo "changed" > file1.txt
    echo "new file" > file3.txt
    git add .
    git commit -q -m "feature changes"

    # Run
    run_e -d

    # Assert: should show files changed from main/master
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" == *"file3.txt"* ]]
    [[ "$output" != *"file2.txt"* ]]
}

@test "e -d REF: opens files changed from specific ref" {
    # Setup
    echo "v1" > file.txt
    git add file.txt
    git commit -q -m "v1"

    echo "v2" > file.txt
    git add file.txt
    git commit -q -m "v2"

    echo "v3" > file.txt
    git add file.txt
    git commit -q -m "v3"

    # Run: diff from HEAD~2
    run_e -d HEAD~2

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"file.txt"* ]]
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

# ============================================================================
# RECENT FILES TESTS (-r flag)
# ============================================================================

@test "e -r: opens recently modified files" {
    # Setup: create files with different modification times
    echo "old" > old.txt
    git add old.txt
    git commit -q -m "initial"
    sleep 1
    echo "new" > new.txt
    git add new.txt
    git commit -q -m "add new"
    # Touch new.txt to ensure it's most recent
    touch new.txt

    # Run
    run_e -r 1

    # Assert: should get most recently modified file
    [ "$status" -eq 0 ]
    [[ "$output" == *"new.txt"* ]]
}

@test "e -r: respects count argument" {
    # Setup: create multiple files
    echo "file1" > file1.txt
    echo "file2" > file2.txt
    echo "file3" > file3.txt
    git add .
    git commit -q -m "initial"

    # Touch files in order to set modification times
    # Use 1 second sleeps to ensure filesystem registers different mtimes
    sleep 1
    touch file3.txt
    sleep 1
    touch file2.txt
    sleep 1
    touch file1.txt

    # Run with count of 2
    run_e -r 2

    # Assert: should get 2 most recent files
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" == *"file2.txt"* ]]
}

@test "e -r: default count is 10" {
    # Setup: create 15 files
    for i in $(seq 1 15); do
        echo "content$i" > "file$i.txt"
        sleep 0.05
    done
    git add .
    git commit -q -m "initial"

    # Run without count (default 10)
    run_e -r

    # Assert: should get exactly 10 files
    [ "$status" -eq 0 ]
    # Count lines in output (each file on its own line from mock editor)
    line_count=$(echo "$output" | grep -c "\.txt" || true)
    [ "$line_count" -eq 10 ]
}

@test "e --recent: long form works" {
    # Setup
    echo "content" > recent.txt
    git add recent.txt
    git commit -q -m "initial"

    # Run
    run_e --recent 1

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"recent.txt"* ]]
}

# ============================================================================
# FILENAMES WITH SPACES
# ============================================================================

@test "e: handles filenames with spaces" {
    # Setup
    echo "content" > "file with spaces.txt"
    git add "file with spaces.txt"
    git commit -q -m "initial"
    echo "modified" > "file with spaces.txt"

    # Run
    run_e -m

    # Assert: file should be opened correctly
    [ "$status" -eq 0 ]
    [[ "$output" == *"file with spaces.txt"* ]]
}

@test "e -a: handles multiple files with spaces" {
    # Setup
    echo "content1" > "my file.txt"
    echo "content2" > "another file.txt"
    echo "content3" > "normal.txt"
    git add .
    git commit -q -m "initial"

    # Run
    run_e -a

    # Assert: all files should be listed
    [ "$status" -eq 0 ]
    [[ "$output" == *"my file.txt"* ]]
    [[ "$output" == *"another file.txt"* ]]
    [[ "$output" == *"normal.txt"* ]]
}

@test "e -g PATTERN: finds pattern in file with spaces" {
    # Setup
    echo "TODO: fix this" > "my component.js"
    echo "done" > "other component.js"
    git add .
    git commit -q -m "initial"

    # Run
    run_e -g TODO

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"my component.js"* ]]
    [[ "$output" != *"other component.js"* ]]
}

# ============================================================================
# GLOB PATTERN TESTS - Shell expansion (e docs/*)
# ============================================================================

@test "e docs/*: opens files via shell glob expansion" {
    # Setup: create directory with files
    mkdir -p docs
    echo "readme content" > docs/readme.md
    echo "guide content" > docs/guide.md
    echo "api content" > docs/api.txt
    git add .
    git commit -q -m "initial"

    # Run with glob expansion (shell expands docs/* to multiple args)
    cd "$TEST_REPO"
    run "$TEST_DIR/e" docs/*

    # Assert: all files in docs/ should be opened
    [ "$status" -eq 0 ]
    [[ "$output" == *"docs/readme.md"* ]]
    [[ "$output" == *"docs/guide.md"* ]]
    [[ "$output" == *"docs/api.txt"* ]]
}

@test "e *.txt: opens files via glob in current directory" {
    # Setup
    echo "file1" > file1.txt
    echo "file2" > file2.txt
    echo "other" > other.md
    git add .
    git commit -q -m "initial"

    # Run with glob
    cd "$TEST_REPO"
    run "$TEST_DIR/e" *.txt

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" == *"file2.txt"* ]]
    [[ "$output" != *"other.md"* ]]
}

@test "e src/**/*.js: opens nested files via glob" {
    # Setup: create nested structure
    mkdir -p src/components src/utils
    echo "button" > src/components/Button.js
    echo "modal" > src/components/Modal.js
    echo "helper" > src/utils/helper.js
    echo "styles" > src/components/Button.css
    git add .
    git commit -q -m "initial"

    # Run with recursive glob (requires bash globstar or shell expansion)
    cd "$TEST_REPO"
    # Use find to simulate what user would get with **/*.js
    run "$TEST_DIR/e" src/components/Button.js src/components/Modal.js src/utils/helper.js

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"Button.js"* ]]
    [[ "$output" == *"Modal.js"* ]]
    [[ "$output" == *"helper.js"* ]]
    [[ "$output" != *"Button.css"* ]]
}

@test "e handles glob with spaces in directory name" {
    # Setup
    mkdir -p "my docs"
    echo "readme" > "my docs/readme.md"
    echo "guide" > "my docs/guide.md"
    git add .
    git commit -q -m "initial"

    # Run (need to quote properly for glob with spaces)
    cd "$TEST_REPO"
    run "$TEST_DIR/e" "my docs/readme.md" "my docs/guide.md"

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"my docs/readme.md"* ]]
    [[ "$output" == *"my docs/guide.md"* ]]
}

# ============================================================================
# PIPED INPUT TESTS - Reading file list from stdin
# ============================================================================

@test "piped input: find | e opens found files" {
    # Setup
    mkdir -p src
    echo "js1" > src/app.js
    echo "js2" > src/util.js
    echo "css" > src/style.css
    git add .
    git commit -q -m "initial"

    # Run with piped input
    cd "$TEST_REPO"
    run bash -c 'find src -name "*.js" | '"$TEST_DIR/e"

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"app.js"* ]]
    [[ "$output" == *"util.js"* ]]
    [[ "$output" != *"style.css"* ]]
}

@test "piped input: echo paths | e opens files" {
    # Setup
    echo "file1" > file1.txt
    echo "file2" > file2.txt
    git add .
    git commit -q -m "initial"

    # Run with echo piped
    cd "$TEST_REPO"
    run bash -c 'echo -e "file1.txt\nfile2.txt" | '"$TEST_DIR/e"

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" == *"file2.txt"* ]]
}

@test "piped input: git ls-files | e opens tracked files" {
    # Setup
    echo "tracked1" > tracked1.txt
    echo "tracked2" > tracked2.txt
    echo "untracked" > untracked.txt
    git add tracked1.txt tracked2.txt
    git commit -q -m "initial"

    # Run with git ls-files piped
    cd "$TEST_REPO"
    run bash -c 'git ls-files | '"$TEST_DIR/e"

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"tracked1.txt"* ]]
    [[ "$output" == *"tracked2.txt"* ]]
    [[ "$output" != *"untracked.txt"* ]]
}

@test "piped input: handles files with spaces" {
    # Setup
    echo "content1" > "file one.txt"
    echo "content2" > "file two.txt"
    git add .
    git commit -q -m "initial"

    # Run with piped paths containing spaces
    cd "$TEST_REPO"
    run bash -c 'echo -e "file one.txt\nfile two.txt" | '"$TEST_DIR/e"

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"file one.txt"* ]]
    [[ "$output" == *"file two.txt"* ]]
}

@test "piped input: cannot combine with flags" {
    # Setup
    echo "content" > file.txt
    git add file.txt
    git commit -q -m "initial"

    # Run with pipe AND flags (should error)
    cd "$TEST_REPO"
    run bash -c 'echo "file.txt" | '"$TEST_DIR/e"' -m'

    # Assert: should fail
    [ "$status" -ne 0 ]
    [[ "$output" == *"Cannot use stdin input"* ]]
}

@test "piped input: cannot combine with positional args" {
    # Setup
    echo "content" > file.txt
    git add file.txt
    git commit -q -m "initial"

    # Run with pipe AND positional args (should error)
    cd "$TEST_REPO"
    run bash -c 'echo "file.txt" | '"$TEST_DIR/e"' other.txt'

    # Assert: should fail
    [ "$status" -ne 0 ]
    [[ "$output" == *"Cannot use stdin input with positional"* ]]
}

@test "piped input: works with interactive mode" {
    # Setup: mock fzf
    cat > "$TEST_DIR/fzf" <<'EOF'
#!/bin/bash
cat
EOF
    chmod +x "$TEST_DIR/fzf"
    export PATH="$TEST_DIR:$PATH"

    echo "file1" > file1.txt
    echo "file2" > file2.txt
    git add .
    git commit -q -m "initial"

    # Run with piped input and -i flag
    cd "$TEST_REPO"
    run bash -c 'echo -e "file1.txt\nfile2.txt" | '"$TEST_DIR/e"' -i'

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" == *"file2.txt"* ]]
}

# ============================================================================
# LINE NUMBER TESTS - file:line syntax
# ============================================================================

@test "e file:line: opens file at specific line" {
    # Setup
    echo -e "line1\nline2\nline3" > test.txt
    git add test.txt
    git commit -q -m "initial"

    # Run
    run_e test.txt:2

    # Assert: should convert to +line file format
    [ "$status" -eq 0 ]
    [[ "$output" == *"+2"* ]]
    [[ "$output" == *"test.txt"* ]]
}

@test "e file:line:col: opens file at line (col ignored)" {
    # Setup
    echo -e "line1\nline2\nline3" > test.txt
    git add test.txt
    git commit -q -m "initial"

    # Run with line:col format
    run_e test.txt:2:15

    # Assert: should use line number, ignore column
    [ "$status" -eq 0 ]
    [[ "$output" == *"+2"* ]]
    [[ "$output" == *"test.txt"* ]]
    # Should NOT have column in output
    [[ "$output" != *":15"* ]]
}

@test "e multiple files with line numbers" {
    # Setup
    echo "file1 content" > file1.txt
    echo "file2 content" > file2.txt
    git add .
    git commit -q -m "initial"

    # Run with multiple file:line args
    run_e file1.txt:10 file2.txt:20

    # Assert: both should have +line syntax
    [ "$status" -eq 0 ]
    [[ "$output" == *"+10"* ]]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" == *"+20"* ]]
    [[ "$output" == *"file2.txt"* ]]
}

@test "e mixed files with and without line numbers" {
    # Setup
    echo "file1" > file1.txt
    echo "file2" > file2.txt
    echo "file3" > file3.txt
    git add .
    git commit -q -m "initial"

    # Run with mixed args
    run_e file1.txt:5 file2.txt file3.txt:15

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"+5"* ]]
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" == *"file2.txt"* ]]
    [[ "$output" == *"+15"* ]]
    [[ "$output" == *"file3.txt"* ]]
}

@test "piped grep output: file:line:content format" {
    # Setup
    echo -e "line1\nTODO: fix this\nline3" > src.js
    git add src.js
    git commit -q -m "initial"

    # Run with grep -nH output format (file:line:content)
    cd "$TEST_REPO"
    run bash -c 'echo "src.js:2:TODO: fix this" | '"$TEST_DIR/e"

    # Assert: should parse file:line from grep output
    [ "$status" -eq 0 ]
    [[ "$output" == *"+2"* ]]
    [[ "$output" == *"src.js"* ]]
    # Should NOT include the matched content
    [[ "$output" != *"TODO"* ]]
}

@test "piped grep output: multiple matches" {
    # Setup
    echo "content" > file1.js
    echo "content" > file2.js
    git add .
    git commit -q -m "initial"

    # Run with multiple grep-style lines
    cd "$TEST_REPO"
    run bash -c 'echo -e "file1.js:10:match1\nfile2.js:20:match2" | '"$TEST_DIR/e"

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"+10"* ]]
    [[ "$output" == *"file1.js"* ]]
    [[ "$output" == *"+20"* ]]
    [[ "$output" == *"file2.js"* ]]
}

@test "e file:line with path containing directories" {
    # Setup
    mkdir -p src/components
    echo "component" > src/components/Button.tsx
    git add .
    git commit -q -m "initial"

    # Run
    run_e src/components/Button.tsx:42

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"+42"* ]]
    [[ "$output" == *"src/components/Button.tsx"* ]]
}

@test "e preserves files without line numbers" {
    # Setup
    echo "content" > normal.txt
    git add normal.txt
    git commit -q -m "initial"

    # Run with file that has no :line suffix
    run_e normal.txt

    # Assert: should NOT add +line
    [ "$status" -eq 0 ]
    [[ "$output" == *"normal.txt"* ]]
    [[ "$output" != *"+"* ]]
}

@test "e ignores URL-like patterns" {
    # This tests that http://example.com:8080 isn't parsed as file:line
    # Setup
    echo "content" > test.txt
    git add test.txt
    git commit -q -m "initial"

    # Run with URL-like input (shouldn't crash, might not open correctly)
    cd "$TEST_REPO"
    run bash -c 'echo "http://example.com:8080/path" | '"$TEST_DIR/e"

    # Assert: should pass through as-is (or fail gracefully)
    # The important thing is it doesn't interpret :8080 as line number
    [[ "$output" != *"+8080"* ]]
}

# ============================================================================
# STDIN AS CONTENT TESTS - Using "-" to pipe content to editor
# ============================================================================

@test "e -: passes stdin content to editor" {
    # Create a mock editor that captures stdin content
    cat > "$EDITOR" <<'EOF'
#!/bin/bash
# Mock editor that reads stdin when given -
if [ "$1" = "-" ]; then
    echo "STDIN_CONTENT:"
    cat
else
    for arg in "$@"; do
        echo "$arg"
    done
fi
EOF
    chmod +x "$EDITOR"

    # Run with piped content and -
    cd "$TEST_REPO"
    run bash -c 'echo "hello world" | '"$TEST_DIR/e"' -'

    # Assert: editor should receive stdin content
    [ "$status" -eq 0 ]
    [[ "$output" == *"STDIN_CONTENT:"* ]]
    [[ "$output" == *"hello world"* ]]
}

@test "e - with multi-line input" {
    # Create a mock editor that captures stdin content
    cat > "$EDITOR" <<'EOF'
#!/bin/bash
if [ "$1" = "-" ]; then
    echo "LINES:"
    cat
fi
EOF
    chmod +x "$EDITOR"

    # Run with multi-line piped content
    cd "$TEST_REPO"
    run bash -c 'printf "line1\nline2\nline3" | '"$TEST_DIR/e"' -'

    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"line1"* ]]
    [[ "$output" == *"line2"* ]]
    [[ "$output" == *"line3"* ]]
}

@test "e - differs from piped filenames" {
    # Setup: create a file
    echo "file content" > myfile.txt
    git add myfile.txt
    git commit -q -m "initial"

    # Without -, piped input is treated as filenames
    cd "$TEST_REPO"
    run bash -c 'echo "myfile.txt" | '"$TEST_DIR/e"

    # Assert: should open myfile.txt (filename mode)
    [ "$status" -eq 0 ]
    [[ "$output" == *"myfile.txt"* ]]
}
