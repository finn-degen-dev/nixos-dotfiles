#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Update System
# @raycast.mode silent

# Optional parameters:
# @raycast.packageName System
# @raycast.icon 󰚰

# Documentation:
# @raycast.description Offload package builds and flake updates to GitHub Actions and Cachix, then apply locally
# @raycast.author BoredVoidAter

set -e
export PATH="/run/wrappers/bin:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$PATH"

FROM_LAUNCHER=0
if [ "${1:-}" = "--from-launcher" ]; then
  FROM_LAUNCHER=1
  shift
fi

if [ ! -t 0 ] && command -v alacritty >/dev/null 2>&1; then
  exec alacritty --title "System Update" -e bash "$0" --from-launcher "$@"
fi

if [ "$FROM_LAUNCHER" -eq 1 ]; then
  trap 'rc=$?; echo ""; read -rp "Finished (exit $rc). Press [Enter] to close..." _' EXIT
fi

DOTFILES_DIR="$HOME/nixos-dotfiles"
cd "$DOTFILES_DIR" || exit 1

notify() {
  local urgency="$1"
  local title="$2"
  local msg="$3"
  notify-send -u "$urgency" -i system-software-update "$title" "$msg"
}

notify "normal" "System Update" "Checking for updates..."

# 1. Update flake inputs
echo "==> Updating flake inputs..."
nix flake update

# 2. Inspect update requirements (dry-run)
echo "==> Inspecting update requirements..."
DRY_RUN=$(nix build .#nixosConfigurations.nixos-btw.config.system.build.toplevel --dry-run 2>&1 || true)

BUILD_COUNT=$(echo "$DRY_RUN" | awk '/derivations will be built:/ {print $2}' || echo "0")
BUILD_COUNT=${BUILD_COUNT:-0}

# Only offload to GitHub Actions when heavy custom packages need rebuilding
CUSTOM_BUILDS=$(echo "$DRY_RUN" | grep -E '\.drv$' | grep -E '/[a-z0-9]{32}-(nchat-[0-9]|concord-tui-|aseprite-)' || true)

if [ -n "$CUSTOM_BUILDS" ]; then
  if ! gh auth status >/dev/null 2>&1; then
    notify "critical" "Update Failed" "GitHub CLI ('gh') is not logged in. Run 'gh auth login' in a terminal."
    exit 1
  fi

  if ! git diff --quiet -- ':!flake.lock' || ! git diff --cached --quiet -- ':!flake.lock'; then
    notify "critical" "Update Aborted" "Uncommitted local changes detected. Commit or stash before cloud build."
    echo "Error: Uncommitted changes outside flake.lock would desync the cloud build and rebase." >&2
    exit 1
  fi

  notify "normal" "System Update" "Heavy compilation needed ($BUILD_COUNT packages). Offloading to GitHub..."

  git add flake.lock
  git commit -m "chore(flake): lockfile update" || true
  git push origin HEAD || true

  if ! gh workflow run maintenance.yml; then
    notify "critical" "Update Failed" "Could not trigger maintenance.yml on GitHub."
    exit 1
  fi

  sleep 5
  RUN_ID=$(gh run list --workflow=maintenance.yml --limit 1 --json databaseId -q '.[0].databaseId')

  notify "normal" "System Update" "Cloud build running on GitHub"

  if ! gh run watch "$RUN_ID" --exit-status; then
    notify "critical" "Update Failed" "Cloud build failed! Check 'gh run view' for details."
    exit 1
  fi

  notify "normal" "System Update" "Cloud build passed! Pulling lockfile..."
  git pull --rebase
else
  echo "==> All heavy packages have pre-built binaries available. Skipping cloud build!"
fi

# 3. Fast parallel background download (pre-stage all closures into /nix/store)
notify "normal" "System Update" "Downloading pre-built binaries..."
nix build .#nixosConfigurations.nixos-btw.config.system.build.toplevel --no-link

# 4. Instant activation switch (packages are already downloaded on SSD)
notify "normal" "System Update" "Applying update..."
if ! sudo nixos-rebuild switch --flake "$DOTFILES_DIR#nixos-btw"; then
  notify "critical" "Update Failed" "Local switch failed. Run 'nrs' to inspect errors."
  exit 1
fi

# 5. Clean old store garbage while retaining recent generations for rollback
sudo nix-collect-garbage --delete-older-than 7d >/dev/null 2>&1
sudo nix-store --optimise >/dev/null 2>&1

notify "normal" "System Update Complete" "System upgraded successfully! ✨"
