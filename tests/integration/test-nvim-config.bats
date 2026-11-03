#!/usr/bin/env bats

# Integration tests for the deployed neovim config
# @covers src/dotfiles/.config/nvim/*
# @covers src/symlink-manager.sh
# @covers tests/helpers/dotfiles-home.bash

bats_require_minimum_version 1.5.0

load ../helpers/dotfiles-home

setup_file() {
    install_dotfiles_home
}

@test "nvim: config directory exists" {
    [ -d "$TEST_HOME/.config/nvim" ] || [ -L "$TEST_HOME/.config/nvim" ]
}

@test "nvim: init.vim exists" {
    [ -f "$TEST_HOME/.config/nvim/init.vim" ] || [ -L "$TEST_HOME/.config/nvim/init.vim" ]
}

@test "nvim: can parse init.vim" {
    skip_if_not_installed nvim

    # Offline: a real lazy.nvim would clone every plugin from GitHub on each
    # run (hundreds of MB). This stub stands in at the path the bootstrap in
    # config/lazy.lua checks, and its setup() only requires the spec modules,
    # so Lua syntax errors in them still fail. The empty colorscheme stands in
    # for the tokyonight plugin that init.vim selects.
    local data="$BATS_TEST_TMPDIR/share"
    local stub="$data/nvim/lazy/lazy.nvim"
    mkdir -p "$stub/lua/lazy" "$stub/colors"
    cat > "$stub/lua/lazy/init.lua" <<'EOF'
return {
	setup = function(opts)
		for _, spec in ipairs(opts.spec) do
			if spec.import then require(spec.import) end
		end
	end,
}
EOF
    touch "$stub/colors/tokyonight.vim"

    # nvim exits 0 even when init.vim errors, so the output is the signal
    run env XDG_DATA_HOME="$data" \
        nvim --headless -u "$TEST_HOME/.config/nvim/init.vim" +qall 2>&1

    [ "$status" -eq 0 ]
    [[ "$output" != *"Error"* ]]
}

@test "nvim: lua config directory exists if referenced" {
    if [ -f "$TEST_HOME/.config/nvim/init.vim" ]; then
        # Check if init.vim references lua configs
        if grep -q "lua" "$TEST_HOME/.config/nvim/init.vim" 2>/dev/null; then
            [ -d "$TEST_HOME/.config/nvim/lua" ] || [ -L "$TEST_HOME/.config/nvim/lua" ]
        else
            skip "No lua configs referenced"
        fi
    else
        skip "init.vim not found"
    fi
}

@test "nvim: lazy.nvim bootstrap exists" {
    if [ -f "$TEST_HOME/.config/nvim/lua/config/lazy.lua" ]; then
        run grep -q "lazy.nvim" "$TEST_HOME/.config/nvim/lua/config/lazy.lua"
        [ "$status" -eq 0 ]
    else
        skip "lazy.lua not found"
    fi
}
