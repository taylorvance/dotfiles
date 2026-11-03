#!/usr/bin/env bats

# Integration tests for the deployed zsh config
# @covers src/dotfiles/.zshrc
# @covers src/dotfiles/.zsh/*
# @covers vendor/zsh/*
# @covers src/symlink-manager.sh
# @covers tests/helpers/dotfiles-home.bash

bats_require_minimum_version 1.5.0

load ../helpers/dotfiles-home

setup_file() {
    install_dotfiles_home
}

@test "zsh: .zshrc sources without errors" {
    skip_if_not_installed zsh

    # No output, not status: a clean .zshrc exits 1 on its ~/.zshrc.local test
    run zsh -c "source $TEST_HOME/.zshrc"
    [ -z "$output" ]
}

@test "zsh: .zshrc sources completely without errors" {
    skip_if_not_installed zsh

    run zsh -i -c true < /dev/null
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "zsh: basic aliases are defined" {
    skip_if_not_installed zsh

    # Check if common aliases work
    run zsh -c "source $TEST_HOME/.zshrc 2>/dev/null; alias l"

    # Should define l alias (even if tools not installed)
    [ "$status" -eq 0 ] || [[ "$output" =~ "l" ]]
}

@test "zsh: editor is set" {
    skip_if_not_installed zsh

    run zsh -c "source $TEST_HOME/.zshrc 2>/dev/null; echo \$EDITOR"

    [[ "$output" == *vim* ]]
}

@test "zsh: .local/bin is in PATH" {
    skip_if_not_installed zsh

    run zsh -c "source $TEST_HOME/.zshrc 2>/dev/null; echo \$PATH"

    [[ "$output" == *".local/bin"* ]]
}

@test "zsh: deployed scripts are callable" {
    skip_if_not_installed zsh

    # whence -p, not command -v: tmp is also a shell function
    local script
    for script in e tmp sysinfo proj; do
        run zsh -c "source $TEST_HOME/.zshrc 2>/dev/null; whence -p $script"
        [ "$output" = "$TEST_HOME/.local/bin/$script" ]
    done
}

@test "zsh: custom functions are defined" {
    skip_if_not_installed zsh

    local fn
    for fn in mkcd tmp ytaudio; do
        run zsh -c "source $TEST_HOME/.zshrc 2>/dev/null; declare -f $fn"
        [ "$status" -eq 0 ]
    done
}

@test "zsh: vendored plugins are sourced" {
    skip_if_not_installed zsh
    if [ ! -f "$TEST_HOME/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
        skip "plugin submodules not synced (run: git submodule update --init)"
    fi

    # wd and autosuggestions define functions; syntax-highlighting sets a version
    run zsh -c "source $TEST_HOME/.zshrc 2>/dev/null
        typeset -f wd >/dev/null && echo wd-ok
        typeset -f _zsh_autosuggest_start >/dev/null && echo autosuggest-ok
        [ -n \"\$ZSH_HIGHLIGHT_VERSION\" ] && echo highlight-ok"

    [[ "$output" == *"wd-ok"* ]]
    [[ "$output" == *"autosuggest-ok"* ]]
    [[ "$output" == *"highlight-ok"* ]]
}

@test "zsh: mise is activated when present" {
    skip_if_not_installed zsh

    # Mock mise: .zshrc should eval the output of `mise activate zsh`
    mkdir -p "$BATS_TEST_TMPDIR/mockbin"
    cat > "$BATS_TEST_TMPDIR/mockbin/mise" <<'EOF'
#!/bin/sh
if [ "$1" = "activate" ]; then
    echo 'export MISE_TEST_ACTIVATED=yes'
fi
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/mockbin/mise"

    run zsh -c "export PATH=$BATS_TEST_TMPDIR/mockbin:\$PATH; source $TEST_HOME/.zshrc 2>/dev/null; echo activated=\$MISE_TEST_ACTIVATED"
    [[ "$output" =~ "activated=yes" ]]
}

@test "zsh: nvm fallback is sourced when mise is absent" {
    skip_if_not_installed zsh
    if command -v mise >/dev/null 2>&1; then
        skip "mise installed on host (run inside the test container)"
    fi

    # A fake ~/.nvm in the shared home would leak into every later test
    private_home
    mkdir -p "$HOME/.nvm"
    echo 'export NVM_TEST_SOURCED=yes' > "$HOME/.nvm/nvm.sh"

    run zsh -c "source $HOME/.zshrc 2>/dev/null; echo sourced=\$NVM_TEST_SOURCED"
    [[ "$output" =~ "sourced=yes" ]]
}

@test "zsh: media commands explain missing dependencies" {
    skip_if_not_installed zsh

    mkdir -p "$BATS_TEST_TMPDIR/empty-path"

    run -127 zsh -c "source $TEST_HOME/.zshrc 2>/dev/null; PATH=$BATS_TEST_TMPDIR/empty-path; ytaudio https://example.com/video"
    [[ "$output" == *"ytaudio requires yt-dlp and ffmpeg"* ]]
}
