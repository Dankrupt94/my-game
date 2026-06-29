#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_NAME="origin"
REMOTE_URL="https://github.com/Dankrupt94/my-game.git"
BRANCH_NAME="main"

pause() {
  if [ -t 0 ]; then
    echo
    read -r -p "Press Enter to close this window..." _ || true
  fi
}

trap pause EXIT

cd "$REPO_DIR"

echo "Frostbound Prototype - GitHub Push"
echo "Project folder: $REPO_DIR"
echo

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This folder is not a Git project yet."
  exit 1
fi

if git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  current_url="$(git remote get-url "$REMOTE_NAME")"
  if [ "$current_url" != "$REMOTE_URL" ]; then
    echo "Updating GitHub remote:"
    echo "  Old: $current_url"
    echo "  New: $REMOTE_URL"
    git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
  fi
else
  echo "Adding GitHub remote:"
  echo "  $REMOTE_URL"
  git remote add "$REMOTE_NAME" "$REMOTE_URL"
fi

current_branch="$(git branch --show-current)"
if [ -z "$current_branch" ]; then
  echo "Git is not currently on a normal branch."
  exit 1
fi

if [ "$current_branch" != "$BRANCH_NAME" ]; then
  echo "Switching from $current_branch to $BRANCH_NAME before pushing."
  git switch "$BRANCH_NAME"
fi

echo
echo "Checking GitHub for the latest saved state..."
git fetch "$REMOTE_NAME" "$BRANCH_NAME" || true

if git rev-parse --verify "$REMOTE_NAME/$BRANCH_NAME" >/dev/null 2>&1; then
  behind_count="$(git rev-list --count "HEAD..$REMOTE_NAME/$BRANCH_NAME")"
  ahead_count="$(git rev-list --count "$REMOTE_NAME/$BRANCH_NAME..HEAD")"

  if [ "$behind_count" -gt 0 ]; then
    echo
    echo "GitHub has $behind_count commit(s) that are not on this computer."
    echo "I am not auto-merging them from the desktop shortcut."
    echo "Open Codex and ask me to sync the repo safely."
    exit 1
  fi
else
  ahead_count="$(git rev-list --count HEAD)"
fi

echo
if [ "${ahead_count:-0}" -eq 0 ]; then
  echo "Nothing to push. GitHub is already up to date."
  exit 0
fi

echo "Pushing $ahead_count local commit(s) to GitHub..."
git push -u "$REMOTE_NAME" "$BRANCH_NAME"

echo
echo "Done. Your local commits are now pushed to GitHub."
