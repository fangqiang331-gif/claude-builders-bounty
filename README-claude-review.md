# Claude PR Review Agent 🤖

A CLI tool + GitHub Action that automatically reviews pull requests using Claude Code.

## Quick Start

```bash
# Review a PR
python claude-review.py --pr https://github.com/owner/repo/pull/123

# Save output
python claude-review.py --pr https://github.com/owner/repo/pull/123 -o review.md
```

## Features

- Fetches PR diff via GitHub API
- Static analysis (files changed, additions/deletions)
- AI-powered code review via Claude Code
- Structured output: Summary → Code Quality → Security → Suggestions
- GitHub Action for automatic PR review

## Requirements

- Python 3.8+
- `claude` CLI installed
- `GITHUB_TOKEN` env var (for private repos)

## GitHub Action

Add `.github/workflows/claude-review.yml` to your repo. The action auto-reviews every PR.
