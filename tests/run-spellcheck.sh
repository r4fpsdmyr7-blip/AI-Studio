#!/bin/bash

# ============================================================================
# AI Studio - Local Test Runner
# File: tests/run-shellcheck.sh
# 
# Runs ShellCheck against all .sh files in the project to ensure code quality
# before pushing to the repository.
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================="
echo "  Running ShellCheck on AI Studio scripts"
echo "=========================================="
echo ""

# Find all .sh files, excluding the tests directory itself to avoid infinite loops if needed
# and excluding .venv directories
FAILED=0

while IFS= read -r -d '' file; do
    # Run shellcheck. It will automatically read .shellcheckrc in the project root
    if ! shellcheck "$file"; then
        FAILED=1
    fi
done < <(find "$PROJECT_ROOT" -name "*.sh" -type f -not -path "*/.venv/*" -print0)

echo ""
echo "=========================================="
if [[ $FAILED -eq 0 ]]; then
    echo "✅ All scripts passed ShellCheck!"
    exit 0
else
    echo "❌ Some scripts failed ShellCheck. Please fix the issues above."
    exit 1
fi
