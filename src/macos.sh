#!/usr/bin/env bash
# macOS system preferences, applied via `make macos`.
# Only encodes deviations from stock macOS — if a setting is at its default,
# it doesn't belong here. Check a current value with:
#   defaults read <domain> <key>
# Settings marked (re-login) need a logout/login (or at least an app relaunch)
# to take effect everywhere; the killall at the end covers Dock and Finder.

set -e

if [[ "$OSTYPE" != darwin* ]]; then
	echo "macos.sh only applies to macOS; skipping."
	exit 0
fi

echo "Applying macOS defaults..."

# --- Keyboard ---
# Fast key repeat — faster than System Settings' fastest slider position (re-login)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
# Holding a key repeats it instead of opening the accent picker (hold j/k in vim) (re-login)
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# --- Text input: no autocorrect-style meddling ---
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# --- Appearance ---
# Dark mode (re-login; the System Settings toggle may not reflect it until then)
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"

# --- Dock ---
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 55

# --- Finder ---
# Show all filename extensions (also unmasks "evil.pdf.exe"-style spoofing)
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Clickable breadcrumb path at the bottom of Finder windows
defaults write com.apple.finder ShowPathbar -bool true
# Skip the "are you sure you want to change the extension?" nag on rename
#defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Restart affected apps so settings that can apply now, do
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true

echo "✓ macOS defaults applied (some settings finish applying after re-login)"
