# shellcheck shell=bash
# Shared setup for the config integration tests: installs the real dotfiles
# into an isolated $HOME once per test file. Call from setup_file; tests share
# that install and keep per-test scratch work in $BATS_TEST_TMPDIR (bats
# creates and removes both temp dirs).

install_dotfiles_home() {
    export TEST_DOTFILES="$BATS_FILE_TMPDIR/dotfiles"
    export TEST_HOME="$BATS_FILE_TMPDIR/home"
    mkdir -p "$TEST_DOTFILES" "$TEST_HOME"

    # Only what the install reads; the rest of the checkout is dead weight.
    # -R, not -r: BSD cp -r dereferences symlinks and fails on the dangling
    # ones under vendor/tmux/tmux-resurrect (uninitialized nested submodule)
    local repo="$BATS_TEST_DIRNAME/../.."
    cp -R "$repo/config" "$repo/src" "$repo/vendor" "$TEST_DOTFILES/"

    export HOME="$TEST_HOME"
    bash "$TEST_DOTFILES/src/symlink-manager.sh" install
}

# A writable copy of the shared $HOME for a test that must add files to it
# (the deployed links are absolute, so they still resolve)
private_home() {
    cp -R "$TEST_HOME" "$BATS_TEST_TMPDIR/home"
    export HOME="$BATS_TEST_TMPDIR/home"
}

skip_if_not_installed() {
    if ! command -v "$1" >/dev/null 2>&1; then
        skip "$1 not installed"
    fi
}
