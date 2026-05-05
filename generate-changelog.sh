#!/bin/bash
# ───────────────────────────────────────────────
#  CHANGELOG Generator
#  Generates a structured CHANGELOG.md from git history
#
#  Usage:
#    bash generate-changelog.sh              # generates CHANGELOG.md
#    bash generate-changelog.sh --output CUSTOM.md
#
#  Requirements: git, bash 3+
# ───────────────────────────────────────────────

set -e

OUTPUT="${2:-CHANGELOG.md}"
REPO_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "project")
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

# Determine date (macOS/Linux compatible)
DATE=$(date -u +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)

# Set the header and commit range
if [ -z "$LAST_TAG" ]; then
    SINCE=""
    HEADER="# Changelog\n\n## [Unreleased] - $DATE"
    echo "[!] No tags found. Generating from all commits..." >&2
else
    SINCE="$LAST_TAG"
    HEADER="# Changelog\n\n## [$LAST_TAG] - $DATE"
    echo "[*] Tags found: $LAST_TAG" >&2
fi

# Temporary files for categories
TMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'changelog')
trap "rm -rf '$TMPDIR'" EXIT

ADDED_FILE="$TMPDIR/added"
FIXED_FILE="$TMPDIR/fixed"
CHANGED_FILE="$TMPDIR/changed"
REMOVED_FILE="$TMPDIR/removed"
touch "$ADDED_FILE" "$FIXED_FILE" "$CHANGED_FILE" "$REMOVED_FILE"

# Helper: get commit message (strip leading type prefix)
get_msg() {
    local msg="$1"
    # Remove common prefixes: "feat:", "fix:", "feat(s cope):", etc.
    echo "$msg" | sed -E 's/^[a-z]+(\([^)]*\))?:\s*//i'
}

# Process commits
git log ${SINCE:+$SINCE..HEAD} --oneline --no-merges --format="%s" 2>/dev/null | while read -r line; do
    [ -z "$line" ] && continue
    
    type=$(echo "$line" | sed -E 's/^([a-z]+).*/\1/' | tr '[:upper:]' '[:lower:]')
    msg=$(get_msg "$line")
    [ -z "$msg" ] && msg="$line"
    
    case "$type" in
        feat|feature|add|new)
            echo "- $msg" >> "$ADDED_FILE"
            ;;
        fix|bugfix|hotfix|patch|bug)
            echo "- $msg" >> "$FIXED_FILE"
            ;;
        refactor|update|change|perf|improve)
            echo "- $msg" >> "$CHANGED_FILE"
            ;;
        remove|delete|deprecate|drop)
            echo "- $msg" >> "$REMOVED_FILE"
            ;;
        docs|doc|documentation)
            echo "- (docs) $msg" >> "$ADDED_FILE"
            ;;
        style|chore|test|ci|build)
            echo "- $msg" >> "$CHANGED_FILE"
            ;;
        *)
            echo "- $msg" >> "$CHANGED_FILE"
            ;;
    esac
done

# Build final CHANGELOG
{
    echo "# Changelog"
    echo ""
    echo "## [Unreleased] - $DATE"
    echo ""
    
    [ -s "$ADDED_FILE" ] && echo "### Added" && echo "" && cat "$ADDED_FILE" && echo ""
    [ -s "$FIXED_FILE" ] && echo "### Fixed" && echo "" && cat "$FIXED_FILE" && echo ""
    [ -s "$CHANGED_FILE" ] && echo "### Changed" && echo "" && cat "$CHANGED_FILE" && echo ""
    [ -s "$REMOVED_FILE" ] && echo "### Removed" && echo "" && cat "$REMOVED_FILE" && echo ""

    # Sample output
    echo "### Sample Entry"
    echo "- Initial release with core features"
} > "$OUTPUT"

echo "" >&2
echo "========================================" >&2
echo "  CHANGELOG Generated: $OUTPUT" >&2
echo "========================================" >&2
echo "  Added:    $(wc -l < "$ADDED_FILE" | tr -d ' ')" >&2
echo "  Fixed:    $(wc -l < "$FIXED_FILE" | tr -d ' ')" >&2
echo "  Changed:  $(wc -l < "$CHANGED_FILE" | tr -d ' ')" >&2
echo "  Removed:  $(wc -l < "$REMOVED_FILE" | tr -d ' ')" >&2
echo "========================================" >&2
