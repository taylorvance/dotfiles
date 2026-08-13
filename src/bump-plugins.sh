#!/usr/bin/env bash
# Interactively update the vendored plugin submodules.
#
# Fetches upstream commits, shows them for audit, and checks them out only
# after confirmation. The checkout is the moment updates go live: the plugin
# directories are symlinked into ~/.zsh/plugins and ~/.tmux/plugins, so new
# shells and tmux servers execute whatever is checked out.

set -e

confirm() {
	local response
	printf '%s [y/N] ' "$1"
	read -r response || { echo; return 1; }  # EOF aborts safely
	[[ "$response" =~ ^[yY]$ ]]
}

confirm "Fetch latest upstream commits? (network read; nothing is applied)" || exit 0

git submodule foreach --quiet 'git fetch -q origin'

# List commits between each pinned checkout and its upstream default branch.
# shellcheck disable=SC2016  # $log/$name expand in foreach's shell, not here
incoming=$(git submodule foreach --quiet '
	log=$(git log --oneline HEAD..origin/HEAD)
	if [ -n "$log" ]; then
		echo "== $name"
		echo "$log"
		echo
	fi
')

if [ -z "$incoming" ]; then
	echo "All plugins are up to date with upstream."
	exit 0
fi

echo
echo "$incoming"

if ! confirm "Check out these commits? They go live immediately via the plugin symlinks."; then
	echo "Aborted. Fetched commits are kept locally; rerun to see them again."
	exit 0
fi

git submodule update --remote
echo
echo "Done. Run 'make test', then commit the submodule bump."
