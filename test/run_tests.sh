#!/bin/bash
# Security Validation Tests for loop-starter-kit
# Run from project root: ./test/run_tests.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

test_pass() {
    echo "  OK $1"
    PASS=$((PASS + 1))
}

test_fail() {
    echo "  FAIL $1"
    FAIL=$((FAIL + 1))
}

echo "=== loop-starter-kit Security Validation Tests ==="
echo ""

cd "$PROJECT_ROOT"

echo "--- Trusted Senders Configuration Tests ---"

# Test 1: CLAUDE.md has Trusted Senders section
test_trusted_senders_section_exists() {
    if grep -q "## Trusted Senders" CLAUDE.md 2>/dev/null; then
        test_pass "CLAUDE.md contains Trusted Senders section"
    else
        test_fail "CLAUDE.md missing Trusted Senders section"
    fi
}
test_trusted_senders_section_exists

# Test 2: Trusted Senders section has proper format
test_trusted_senders_format() {
    if grep -A5 "## Trusted Senders" CLAUDE.md | grep -qE 'SP[A-Z0-9]+' 2>/dev/null; then
        test_pass "Trusted Senders has valid format"
    else
        test_fail "Trusted Senders format invalid or empty"
    fi
}
test_trusted_senders_format

# Test 3: Stacks address format validation
test_stx_address_format() {
    local stx_addresses
    stx_addresses=$(grep -A20 "## Trusted Senders" CLAUDE.md | grep -oE 'SP[A-Za-z0-9]+' | head -5)
    for addr in $stx_addresses; do
        if [[ "$addr" =~ ^SP[A-Za-z0-9]{28,}$ ]]; then
            test_pass "Valid STX address format: $addr"
        else
            test_fail "Invalid STX address format: $addr"
        fi
    done
}
test_stx_address_format

echo ""
echo "--- Placeholder Validation Tests ---"

# Test 4: No placeholder STX addresses
test_no_placeholder_stx() {
    if grep -q '\[YOUR_STX_ADDRESS\]' CLAUDE.md 2>/dev/null; then
        test_fail "CLAUDE.md contains placeholder [YOUR_STX_ADDRESS]"
    else
        test_pass "No placeholder STX addresses in CLAUDE.md"
    fi
}
test_no_placeholder_stx

# Test 5: No placeholder BTC addresses
test_no_placeholder_btc() {
    if grep -q '\[YOUR_BTC_ADDRESS\]' CLAUDE.md 2>/dev/null; then
        test_fail "CLAUDE.md contains placeholder [YOUR_BTC_ADDRESS]"
    else
        test_pass "No placeholder BTC addresses in CLAUDE.md"
    fi
}
test_no_placeholder_btc

echo ""
echo "--- daemon/loop.md Security Tests ---"

# Test 6: Protected sections exist
test_protected_sections() {
    if grep -q "## Evolution Guardrails" daemon/loop.md 2>/dev/null; then
        test_pass "Evolution Guardrails section exists"
    else
        test_fail "Evolution Guardrails section missing"
    fi
}
test_protected_sections

# Test 7: Sender validation in Phase 2
test_sender_validation() {
    if grep -q "Sender Validation" daemon/loop.md 2>/dev/null; then
        test_pass "Sender validation logic exists in Phase 2"
    else
        test_fail "Sender validation logic missing from Phase 2"
    fi
}
test_sender_validation

# Test 8: Trusted sender check
test_trusted_sender_check() {
    if grep -q "trusted_senders" daemon/loop.md 2>/dev/null; then
        test_pass "Trusted sender reference in loop.md"
    else
        test_fail "Trusted sender check missing from loop.md"
    fi
}
test_trusted_sender_check

# Test 9: Backup mechanism for loop.md
test_backup_mechanism() {
    if grep -q "loop.md.bak" daemon/loop.md 2>/dev/null; then
        test_pass "Backup mechanism exists for loop.md"
    else
        test_fail "Backup mechanism missing for loop.md"
    fi
}
test_backup_mechanism

# Test 10: Rollback on failure
test_rollback() {
    if grep -q "cp daemon/loop.md.bak daemon/loop.md" daemon/loop.md 2>/dev/null; then
        test_pass "Rollback mechanism exists"
    else
        test_fail "Rollback mechanism missing"
    fi
}
test_rollback

echo ""
echo "--- SKILL.md Security Tests ---"

# Test 11: Skill security section exists
test_skill_security() {
    if grep -q "Skill Installation Security" SKILL.md 2>/dev/null; then
        test_pass "Skill installation security section exists"
    else
        test_fail "Skill installation security section missing"
    fi
}
test_skill_security

# Test 12: Protected files check
test_protected_files() {
    if grep -q "CLAUDE.md" SKILL.md 2>/dev/null && grep -q "Protected files" SKILL.md 2>/dev/null; then
        test_pass "Protected files documented in SKILL.md"
    else
        test_fail "Protected files not documented in SKILL.md"
    fi
}
test_protected_files

echo ""
echo "--- README Security Documentation Tests ---"

# Test 13: Security warnings exist
test_security_warnings() {
    if grep -q "Security Warning" README.md 2>/dev; then
        test_pass "Security warning section in README"
    else
        test_fail "No security warning in README"
    fi
}
test_security_warnings

# Test 14: SHA256 verification documented
test_sha256_docs() {
    if grep -q "sha256sum" README.md 2>/dev/null; then
        test_pass "SHA256 verification documented in README"
    else
        test_fail "SHA256 verification not documented"
    fi
}
test_sha256_docs

# Test 15: Headless security recommendations
test_headless_security() {
    if grep -q "isolated" README.md 2>/dev/null; then
        test_pass "Headless security recommendations present"
    else
        test_fail "Headless security recommendations missing"
    fi
}
test_headless_security

echo ""
echo "--- Protected Patterns Tests ---"

# Test 16: Protected patterns section exists
test_protected_patterns() {
    if grep -q "## Protected Patterns" daemon/loop.md 2>/dev/null; then
        test_pass "Protected Patterns section exists in loop.md"
    else
        test_fail "Protected Patterns section missing from loop.md"
    fi
}
test_protected_patterns

# Test 17: Trusted sender pattern in protected list
test_sender_pattern_protected() {
    if grep -q "Trusted Sender Validation" daemon/loop.md 2>/dev/null; then
        test_pass "Trusted sender pattern in protected list"
    else
        test_fail "Trusted sender pattern not in protected list"
    fi
}
test_sender_pattern_protected

echo ""
echo "=== Test Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "All security tests passed!"
    exit 0
else
    echo "Some tests failed. Review security configuration."
    exit 1
fi
