#!/usr/bin/env bash
set -e

# macOS system defaults

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock minimize-to-application -bool true

# Finder
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Appearance
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"

# Key repeat
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Power (plugged in)
if [ "$(id -u)" -eq 0 ]; then
  pmset -c sleep 0 displaysleep 0 lessbright 0 halfdim 0
else
  sudo pmset -c sleep 0 displaysleep 0 lessbright 0 halfdim 0
fi

# Apply
killall Dock
killall Finder

echo "macOS defaults applied."
