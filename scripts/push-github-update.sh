#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REMOTE_URL="${GITHUB_REPO_URL:-https://github.com/JunZhaoNathan/Chiselo.git}"
COMMIT_MESSAGE="${1:-Update Chiselo}"

echo "==> Repository"
echo "$REMOTE_URL"

echo "==> Preparing generated files"
node scripts/generate-design-tokens.mjs

if [[ "${FULL_PREFLIGHT:-0}" == "1" ]]; then
  echo "==> Running full release preflight"
  scripts/release-preflight.sh
else
  echo "==> Running quick checks"
  swift build
  node --check scripts/generate-design-tokens.mjs
  node --check Sources/Chiselo/Resources/Editor/editor.js
fi

echo "==> Git status before staging"
git status --short

git add .

if git diff --cached --quiet; then
  echo "==> No staged changes; pushing existing commits"
else
  echo "==> Committing"
  git commit -m "$COMMIT_MESSAGE"
fi

if git remote get-url origin >/dev/null 2>&1; then
  echo "==> Existing origin"
  git remote get-url origin
else
  echo "==> Adding origin"
  git remote add origin "$REMOTE_URL"
fi

BRANCH="$(git branch --show-current)"
if [[ -z "$BRANCH" ]]; then
  BRANCH="main"
  git branch -M "$BRANCH"
fi

echo "==> Pushing $BRANCH"
git push -u origin "$BRANCH"

echo "GitHub update push complete."
