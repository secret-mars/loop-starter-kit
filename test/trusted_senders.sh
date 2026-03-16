#!/bin/bash
# Trusted Senders Validation Functions
# Source this file: source test/trusted_senders.sh

# Parse trusted_senders from CLAUDE.md
# Returns: newline-separated list of STX addresses
parse_trusted_senders() {
    local claude_md="${1:-CLAUDE.md}"
    
    if [ ! -f "$claude_md" ]; then
        echo "ERROR: CLAUDE.md not found at $claude_md" >&2
        return 1
    fi
    
    # Extract STX addresses from Trusted Senders section
    # Expected format: "- AgentName — `STX_ADDRESS` (reason)"
    grep -A50 "^## Trusted Senders" "$claude_md" 2>/dev/null | \
        grep -oE '`SP[A-Za-z0-9]+' | \
        tr -d '`' | \
        head -20  # Safety limit
}

# Check if a sender is trusted
# Args: sender_stx, [claude_md_path]
# Returns: 0 if trusted, 1 if not
is_trusted_sender() {
    local sender_stx="$1"
    local claude_md="${2:-CLAUDE.md}"
    
    # Normalize sender address (strip backticks if present)
    sender_stx=$(echo "$sender_stx" | tr -d '`')
    
    # Get trusted senders list
    local trusted=$(parse_trusted_senders "$claude_md")
    
    # Check if sender is in the list
    if echo "$trusted" | grep -q "^${sender_stx}$"; then
        return 0
    else
        return 1
    fi
}

# Validate message and return action
# Args: sender_stx, message_content
# Returns: "process" or "ack_only"
validate_message() {
    local sender_stx="$1"
    local message_content="$2"
    
    sender_stx=$(echo "$sender_stx" | tr -d '`')
    
    # Task keywords that require trusted sender
    local task_keywords="fork|PR|build|deploy|fix|review|audit"
    
    # Normalize sender
    sender_stx=$(echo "$sender_stx" | tr -d '`')
    if is_trusted_sender "$sender_stx"; then
        echo "process"
        return 0
    fi
    
    # Check for task keywords
    if echo "$message_content" | grep -qiE "\b($task_keywords)\b"; then
        echo "ack_only"
        return 0
    fi
    
    # Non-task message from untrusted sender
    echo "process"
    return 0
}

# Generate rejection message for untrusted sender task
# Args: sender_stx
get_rejection_message() {
    local sender_stx="$1"
    sender_stx=$(echo "$sender_stx" | tr -d '`')
    
    echo "Task request acknowledged. Sender $sender_stx not in trusted_senders list. Task will not be processed. Contact operator to add your STX address."
}

# Log security event
# Args: event_type, details, [log_file]
log_security_event() {
    local event_type="$1"
    local details="$2"
    local log_file="${3:-memory/learnings.md}"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local log_entry="- [$timestamp] SECURITY: $event_type - $details"
    
    if [ -f "$log_file" ]; then
        echo "$log_entry" >> "$log_file"
    else
        echo "$log_entry"
    fi
}

# Self-test function
test_trusted_senders_logic() {
    echo "Running trusted_senders self-tests..."
    
    local errors=0
    
    # Test: parse_trusted_senders extracts addresses
    local senders=$(parse_trusted_senders CLAUDE.md 2>/dev/null)
    if [ -n "$senders" ]; then
        echo "  ✓ parse_trusted_senders found addresses"
    else
        echo "  ✗ parse_trusted_senders found no addresses"
        ((errors++))
    fi
    
    # Test: is_trusted_sender works
    local first_sender=$(echo "$senders" | head -1)
    if [ -n "$first_sender" ] && is_trusted_sender "$first_sender" CLAUDE.md; then
        echo "  ✓ is_trusted_sender correctly identifies trusted sender"
    else
        echo "  ✗ is_trusted_sender failed for known sender"
        ((errors++))
    fi
    
    # Test: untrusted sender rejected
    if ! is_trusted_sender "SP0000000000000000000000000000000000UNKN" CLAUDE.md 2>/dev/null; then
        echo "  ✓ Untrusted sender correctly rejected"
    else
        echo "  ✗ Untrusted sender incorrectly accepted"
        ((errors++))
    fi
    
    # Test: validate_message returns correct action
    local action=$(validate_message "SP0000000000000000000000000000000000UNKN" "Please fork this repo")
    if [ "$action" = "ack_only" ]; then
        echo "  ✓ Task from untrusted sender returns ack_only"
    else
        echo "  ✗ Task from untrusted sender returned: $action"
        ((errors++))
    fi
    
    # Test: get_rejection_message generates message
    local rejection=$(get_rejection_message "SPTEST")
    if echo "$rejection" | grep -q "not in trusted_senders"; then
        echo "  ✓ Rejection message generated correctly"
    else
        echo "  ✗ Rejection message incorrect"
        ((errors++))
    fi
    
    if [ $errors -eq 0 ]; then
        echo "All self-tests passed!"
        return 0
    else
        echo "$errors self-tests failed"
        return 1
    fi
}

# If run directly (not sourced), run tests
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    cd "$(dirname "$0")/.." || exit 1
    test_trusted_senders_logic
fi