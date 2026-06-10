# GitHub Publishing Guide

This guide is written for publishing Chiselo as a public preview without needing the GitHub CLI.

本指南适合第一次发布：不用安装 `gh`，主要使用 GitHub 网页 + 普通 `git` 命令。不要把 GitHub 密码粘进终端。GitHub 现在一般使用浏览器登录、GitHub Desktop，或 Personal Access Token。

Official references:

- [Creating a new repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository)
- [Managing remote repositories](https://docs.github.com/en/get-started/git-basics/managing-remote-repositories)
- [Managing releases in a repository](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)

## What To Publish

Publish these to the GitHub repository:

- source code;
- README, license, docs, examples, scripts;
- GitHub issue templates and workflow files.

Do not commit these to the repository:

- `.build/`;
- `outputs/`;
- `Chiselo.app`;
- `Chiselo-0.1.1.dmg`;
- logs, temp files, local caches, and unreferenced temporary screenshots.

The DMG should be uploaded later as a GitHub Release asset.

## License Position

Chiselo is source-available for personal, educational, research, evaluation, and non-commercial hobby use only.

Commercial use is forbidden. Do not describe the project as "open source" in release text or marketing copy. Use "source-available non-commercial" instead.

This is not legal advice. If the project later becomes commercially important, ask a lawyer to review the custom license.

## Recommended Repository Setup

Repository name:

```text
Chiselo
```

Short description:

```text
Chisel your HTML: HTML as the primary asset, Office-like visual editing, multi-format output.
```

Alternative shorter description:

```text
A macOS visual editor for polishing AI-generated HTML and exporting clean HTML, PDF, and PPTX.
```

Search-optimized description:

```text
Visual HTML editor for AI-generated HTML: edit real HTML like Office/PPT, export clean HTML, PDF, PPTX/html2pptx. macOS.
```

About text:

```text
Chiselo helps you polish existing or AI-generated HTML with an Office-like visual editing layer. Built through vibe coding by a humanities-background creator, with thanks to Codex and GPT.
```

Topics:

```text
macos swiftui wkwebview html-editor ai-generated-html ai-html-editor visual-editor wysiwyg layout-editor html-layout-editor office-like ppt-like editable-html html-to-pdf html-to-pptx html2ppt html2pptx pdf-export pptx-export vibe-coding non-commercial source-available
```

Star reminder for README or pinned issue:

```text
If Chiselo helps you or you are interested in AI-native software creation, please star the repository so more people can find it.
```

## Step 1: Create The GitHub Repository

1. Open GitHub in the browser.
2. Click `+` -> `New repository`.
3. Use the name `Chiselo`.
4. Set visibility to `Public` if this is the public preview.
5. Do not add GitHub's default README, license, or `.gitignore`; this repository already has them locally.
6. Click `Create repository`.

After creation, GitHub will show a URL like:

```text
https://github.com/YOUR_ACCOUNT/Chiselo.git
```

Keep that page open.

## Step 2: Commit The Local Repository

From the Chiselo project folder:

```bash
git status --short
git add .
git status --short
git commit -m "Initial public preview"
```

Before committing, check that `outputs/`, `.build/`, `.dmg`, and `.app` files are not listed. They should be ignored by `.gitignore`.

## Step 3: Connect Local Git To GitHub

Replace `YOUR_ACCOUNT` with your GitHub username:

```bash
git remote add origin https://github.com/YOUR_ACCOUNT/Chiselo.git
git branch -M main
git push -u origin main
```

If Git says `remote origin already exists`, use:

```bash
git remote set-url origin https://github.com/YOUR_ACCOUNT/Chiselo.git
git push -u origin main
```

If Git asks for credentials, GitHub passwords usually do not work in the terminal. Use one of these:

- GitHub Desktop;
- browser-based sign-in prompted by your system Git credential helper;
- a GitHub Personal Access Token with repository permissions.

## Step 4: Build Or Choose The DMG

To rebuild the default package:

```bash
scripts/release-preflight.sh
scripts/package-dmg.sh
hdiutil verify outputs/Chiselo-0.1.1.dmg
```

Default release asset:

```text
outputs/Chiselo-0.1.1.dmg
```

If using a custom package output from the Codex build folder, upload:

```text
outputs/codex-build/Chiselo-0.1.1.dmg
```

Only upload one DMG to GitHub Releases unless you intentionally built multiple variants.

## Step 5: Create The GitHub Release

1. Open the GitHub repository page.
2. Click `Releases`.
3. Click `Draft a new release`.
4. Create a new tag:

```text
v0.1.1-preview.1
```

5. Release title:

```text
Chiselo 0.1.1 Preview
```

6. Check `Set as a pre-release`.
7. Paste the text from:

```text
docs/RELEASE_NOTES_0.1.1_PREVIEW.md
```

8. Upload the DMG file.
9. Click `Publish release`.

## Step 6: First Public Smoke Check

After publishing:

1. Open the repository page in a private/incognito browser window.
2. Confirm the README explains what Chiselo does.
3. Open the Release page.
4. Download the DMG.
5. Open the DMG and drag `Chiselo.app` to `Applications`.
6. Launch with Finder right-click -> Open if macOS blocks it.
7. Open an HTML file, edit text, export clean HTML/PDF/PPTX.

## Future Updates

After the first publish, use:

```bash
scripts/push-github-update.sh "Describe this update"
```

The saved workflow is in [GITHUB_UPDATE_WORKFLOW.md](GITHUB_UPDATE_WORKFLOW.md).

On this machine, GitHub CLI configuration is stored in `~/.gh` because `~/.config` may not be writable.

## Common Problems

`fatal: remote origin already exists`

Use `git remote set-url origin ...` instead of `git remote add origin ...`.

`Authentication failed`

Use GitHub Desktop or a Personal Access Token. Do not paste your GitHub password into random prompts.

macOS says the app cannot be opened

The preview build is ad-hoc signed and not notarized. Use Finder right-click -> Open for the first launch.

DMG accidentally appears in `git status`

Stop and check `.gitignore`. The DMG should be uploaded as a Release asset, not committed.
