#!/bin/sh
# Install the hook.
#   ./install.sh            this repo only  (copies to .githooks/, sets core.hooksPath)
#   ./install.sh --global   every repo on this machine (~/.git-hooks)
set -e
src="$(cd "$(dirname "$0")" && pwd)/hooks/commit-msg"
if [ "$1" = "--global" ]; then
  dest="$HOME/.git-hooks"
  mkdir -p "$dest"
  [ -e "$dest/commit-msg" ] && cp "$dest/commit-msg" "$dest/commit-msg.bak" && echo "existing hook saved as commit-msg.bak"
  cp "$src" "$dest/commit-msg"; chmod +x "$dest/commit-msg"
  git config --global core.hooksPath "$dest"
  echo "installed globally -> $dest"
else
  root=$(git rev-parse --show-toplevel)
  mkdir -p "$root/.githooks"
  cp "$src" "$root/.githooks/commit-msg"; chmod +x "$root/.githooks/commit-msg"
  git -C "$root" config core.hooksPath .githooks
  echo "installed for $root (commit .githooks/ so teammates get it, then they run: git config core.hooksPath .githooks)"
fi
