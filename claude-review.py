#!/usr/bin/env python3
"""
claude-review — Claude Code PR Review Agent
Usage: claude-review --pr https://github.com/owner/repo/pull/123
"""

import argparse, json, os, subprocess, sys, urllib.request, urllib.error

GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "")

def fetch_pr_diff(pr_url: str) -> str:
    """Fetch PR diff from GitHub API"""
    parts = pr_url.replace("https://github.com/", "").split("/pull/")
    if len(parts) != 2:
        raise ValueError("Invalid PR URL. Use: https://github.com/owner/repo/pull/NUMBER")
    repo_path, pr_num = parts
    pr_num = pr_num.split("/")[0]
    
    url = f"https://api.github.com/repos/{repo_path}/pulls/{pr_num}"
    headers = {
        "Accept": "application/vnd.github.v3.diff",
        "User-Agent": "claude-review-agent"
    }
    if GITHUB_TOKEN:
        headers["Authorization"] = f"Bearer {GITHUB_TOKEN}"
    
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        return f"Error fetching PR: {e.code} - {e.reason}"

def analyze_diff(diff: str) -> dict:
    """Basic static analysis of the diff"""
    lines = diff.split("\n")
    files_changed = set()
    additions = 0
    deletions = 0
    current_file = ""
    
    for line in lines:
        if line.startswith("+++ b/"):
            current_file = line[6:]
            files_changed.add(current_file)
        elif line.startswith("+") and not line.startswith("+++"):
            additions += 1
        elif line.startswith("-") and not line.startswith("---"):
            deletions += 1
    
    return {
        "files_changed": sorted(files_changed),
        "additions": additions,
        "deletions": deletions,
        "total_changes": additions + deletions,
    }

def run_claude_review(diff: str, stats: dict) -> str:
    """Use Claude Code to analyze the diff"""
    prompt = f"""You are a senior code reviewer. Review this PR diff:

## Stats
- Files changed: {len(stats['files_changed'])}
- Additions: {stats['additions']}
- Deletions: {stats['deletions']}

## Diff
```
{diff[:8000]}
```

## Review Structure
1. **Summary** - What does this PR do? (2-3 sentences)
2. **Code Quality** - Issues with style, readability, maintainability
3. **Security** - Any security concerns?
4. **Suggestions** - Specific improvements with code examples

Format as clean Markdown."""

    result = subprocess.run(
        ["claude", "-p", prompt],
        capture_output=True, text=True, timeout=120
    )
    return result.stdout if result.returncode == 0 else f"Claude error: {result.stderr}"

def main():
    parser = argparse.ArgumentParser(description="Claude Code PR Review Agent")
    parser.add_argument("--pr", required=True, help="PR URL (e.g., https://github.com/owner/repo/pull/123)")
    parser.add_argument("--output", "-o", help="Save review to file")
    args = parser.parse_args()
    
    print(f"🔍 Fetching PR: {args.pr}")
    diff = fetch_pr_diff(args.pr)
    if diff.startswith("Error"):
        print(diff)
        sys.exit(1)
    
    stats = analyze_diff(diff)
    print(f"📊 Files: {len(stats['files_changed'])}, +{stats['additions']}/-{stats['deletions']}")
    
    print("🤖 Running Claude review...")
    review = run_claude_review(diff, stats)
    
    print("\n" + "=" * 60)
    print(review)
    print("=" * 60)
    
    if args.output:
        with open(args.output, "w") as f:
            f.write(review)
        print(f"💾 Review saved to: {args.output}")

if __name__ == "__main__":
    main()
