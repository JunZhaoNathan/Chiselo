# GitHub Update Workflow

This file records the normal update-and-push process for Chiselo.

Use it after future software changes when the repository already exists on GitHub.

Default GitHub repository:

```text
https://github.com/JunZhaoNathan/Chiselo.git
```

## One-Command Update Push

After making changes and testing them, run:

```bash
scripts/push-github-update.sh "Describe this update"
```

Example:

```bash
scripts/push-github-update.sh "Polish HTML editing performance"
```

The script will:

1. regenerate design tokens;
2. run quick checks;
3. stage changed files;
4. create a git commit;
5. add the GitHub remote if missing;
6. push the current branch to GitHub.

The script stores GitHub CLI configuration in:

```text
~/.gh
```

This avoids local machines where `~/.config` has incorrect permissions.

## Full Release Push

Before a bigger public release, run the full preflight:

```bash
FULL_PREFLIGHT=1 scripts/push-github-update.sh "Prepare 0.1.2 preview"
```

This runs `scripts/release-preflight.sh` before committing.

## If The GitHub URL Changes

Use:

```bash
GITHUB_REPO_URL=https://github.com/YOUR_ACCOUNT/YOUR_REPO.git scripts/push-github-update.sh "Update"
```

Or permanently update the remote:

```bash
git remote set-url origin https://github.com/YOUR_ACCOUNT/YOUR_REPO.git
```

## Manual Version

If the script is not used:

```bash
node scripts/generate-design-tokens.mjs
swift build
node --check scripts/generate-design-tokens.mjs
node --check Chiselo/Resources/Editor/editor.js
git status --short
git add .
git commit -m "Describe this update"
git remote add origin https://github.com/JunZhaoNathan/Chiselo.git
git branch -M main
git push -u origin main
```

If `origin` already exists:

```bash
git remote set-url origin https://github.com/JunZhaoNathan/Chiselo.git
git push -u origin main
```

## Important Rules

- Do not commit `outputs/`, `.build/`, `.app`, or `.dmg` files.
- Upload DMG files through GitHub Releases, not normal git commits.
- Keep the license language clear: source-available non-commercial; commercial use is forbidden.
- Do not call the project OSI open source, because the license restricts commercial use.
- If Git asks for credentials, use GitHub browser login, GitHub Desktop, or a Personal Access Token. Do not paste a GitHub password into random prompts.
