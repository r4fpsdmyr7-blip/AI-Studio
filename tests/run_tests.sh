#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_STUDIO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0

# 断言函数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$expected" == "$actual" ]]; then
        ((TESTS_PASSED++))
        echo "  ✅ PASS: $message"
    else
        ((TESTS_FAILED++))
        echo "  ❌ FAIL: $message"
        echo "     Expected: $expected"
        echo "     Actual:   $actual"
    fi
}

assert_command_exists() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        ((TESTS_PASSED++))
        echo "  ✅ PASS: Command '$cmd' exists"
    else
        ((TESTS_FAILED++))
        echo "  ❌ FAIL: Command '$cmd' not found"
    fi
}

# 测试用例
test_common_functions() {
    echo "Testing common.sh functions..."
    source "$AI_STUDIO_ROOT/lib/common.sh"
    
    # 测试 command_exists
    assert_command_exists "bash"
    
    # 测试 is_valid_component（需要 registry.sh）
    # ...
}

# 运行所有测试
echo "========================================="
echo "AI Studio Test Suite"
echo "========================================="

test_common_functions
# test_registry_functions
# test_process_functions

echo ""
echo "========================================="
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "========================================="

[[ $TESTS_FAILED -eq 0 ]]
