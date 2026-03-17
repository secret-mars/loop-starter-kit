#!/bin/bash
# Skill Installation Validator
# Validates skill URLs and paths before installation
# Usage: ./scripts/skill-validator.sh <url|path> [--install]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMP_DIR=""
SKILL_FILE=""FAILURES=0
WARNINGS=0

# Colors for output
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

log_error() {echo -e "${RED}ERROR: $1${NC}" >&2
    ((FAILURES++))
}

log_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
    ((WARNINGS++))
}

log_success() {
    echo -e "${GREEN}OK: $1${NC}"
}

cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

# ============================================================================
# INPUT VALIDATION
# ============================================================================

validate_input() {
    local input="$1"
    
    if [ -z "$input" ]; then
        log_error "No skill URL or path provided"
        echo "Usage: $0 <url|path> [--install]" >&2
        exit 1
    fi
    
    # Check for suspicious characters
    case "$input" in
        *"'"*|*'"'*|*'$('*|*'`'*|*';'*|*'|'*|*'&'*|*'<'*|*'>'*|*'\n'*|*'\0'*)
            log_error "Suspicious characters detected in input"
            log_error "Potential injection attempt rejected"
            exit 1
            ;;
    esac
    
    # Check for null bytes
    if echo "$input" | grep -q $'\x00'; then
        log_error "Null byte detected in input"
        exit 1
    fi
    
    # Validate URL format if URL
    case "$input" in
        http://*|https://*)
            validate_url "$input"
            ;;
        file://*)
            local path="${input#file://}"
            validate_local_path "$path"
            ;;
        *)
            # Assume local path
            validate_local_path "$input"
            ;;
    esac
}

validate_url() {
    local url="$1"
    
    log_success "Validating URL: $url"
    
    # Extract domain
    local domain
    domain=$(echo "$url" | sed -n 's|^[^/]*//\([^/]*\).*|\1|p')
    
    # Check for suspicious domains
    case "$domain" in
        localhost|127.0.0.1|0.0.0.0|*[local]*)
            log_error "Local/internal URLs not allowed"
            exit 1            ;;
    esac
    
    # Check for suspicious TLDs
    case "$domain" in
        *.local|*.internal|*.localdomain)
            log_error "Internal/local domains not allowed"
            exit 1
            ;;
    esac
    
    # Validate HTTPS (allow HTTP with warning)
    case "$url" in
        https://*)
            log_success "Using HTTPS"
            ;;
        http://*)
            log_warning "Using HTTP - connection not encrypted"
            ;;
        *)
            log_error "Invalid URL scheme (must be http or https)"
            exit 1
            ;;
    esac
    
    # Check for directory traversal in URL path
    local url_path
    url_path=$(echo "$url" | sed 's|^[^/]*//[^/]*/||')
    case "$url_path" in
        *".."*)
            log_error "Directory traversal detected in URL path"
            exit 1
            ;;
    esac
    
    log_success "URL format validated"
}

validate_local_path() {
    local path="$1"
    
    # Resolve to absolute path
    local abs_path
    if [ -d "$path" ]; then
        abs_path=$(cd "$path" && pwd)
    elif [ -f "$path" ]; then
        abs_path=$(cd "$(dirname "$path")" && pwd)/$(basename "$path")
    else
        log_error "Path does not exist: $path"
        exit 1
    fi
    
    # Check for directory traversal
    case "$abs_path" in
        *".."*)log_warning "Path contains '..' segments"; ;;
    esac
    
    # Check if path is within allowed directories
    local allowed=false
    
    # Standard skill directories
    forallowed_dir in "$PROJECT_ROOT/.claude/skills" "$PROJECT_ROOT/.agents/skills" "$HOME/.claude/skills"; do
        if [ -d "$allowed_dir" ] && [[ "$abs_path" == "$allowed_dir"* ]]; then
            allowed=true
            break
        fi
    done
    
    if [ "$allowed" = false ]; then
        log_warning "Path outside standard skill directories"
        log_warning "Recommended: .claude/skills/ or .agents/skills/"
    fi
    
    log_success "Local path validated: $abs_path"
}

# ============================================================================
# DOWNLOAD & HASH VALIDATION
# ============================================================================

download_skill() {
    local url="$1"
    
    TEMP_DIR=$(mktemp -d)
    SKILL_FILE="$TEMP_DIR/SKILL.md"
    
    log_success "Downloading skill file..."
    
    if ! curl -fsSL "$url" -o "$SKILL_FILE" 2>/dev/null; then
        log_error "Failed to download skill file"
        exit 1
    fi
    
    if [ ! -s "$SKILL_FILE" ]; then
        log_error "Downloaded file is empty"
        exit 1
    fi
    
    log_success "Downloaded $(wc -c < "$SKILL_FILE") bytes"
}

compute_hash() {
    local file="$1"
    
    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum &>/dev/null; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        log_error "No SHA256 tool available"
        exit 1
    fi
}

# ============================================================================
# MALICIOUS PATTERN DETECTION
# ============================================================================

check_malicious_patterns() {
    local file="$1"
    
    echo ""
    echo "=== Malicious Pattern Detection ==="local patterns_found=0
    
    # Critical patterns - ALWAYS reject
    local critical_patterns=(
        "exec\s*\("                          # Code execution
        "eval\s*\("                          # Eval execution
        "base64\s*-\d\s*\|.*sh"              # Base64 pipe to shell
        "curl.*\|\s*sh"                      # Curl pipe to shell
        "wget.*\|\s*sh"                       # Wget pipe to shell
        "/dev/tcp/"                          # Network device access
        "nc\s+-[elp]"                        # Netcat reverse shell
        "bash\s+-[ci]\s*['\"]"               # Bash command injection
        "\$\("                              # Command substitution (nested)
        "keyword_list\s*:"                  # Claude-specific tool poisoning
        "tools\s*=\s*\["                     # Tool array manipulation
        "mcp__.*__"                          # MCP tool name injection
        "wallet.*private.*key"               # Key extraction attempts
        "mnemonic"                           # Mnemonic extraction
        "seed.*phrase"                       # Seed phrase extraction
        "export\s+.*=.*\$\("                 # Environment injection
        "unset\s+PATH"                       # PATH manipulation
        "\\\\x[0-9a-fA-F]"                   # Hex escape sequences
    )
    
    # High-risk patterns - Reject with warning
    local high_risk_patterns=(
        "wallet_unlock"                      # Wallet unlock
        "wallet_create"                      # Wallet creation
        "\.env"                              # Environment files
        "private.?key"                       # Private key references
        "\.ssh/"                             # SSH directory
        "id_rsa"                             # SSH key
        "known_hosts"                         # SSH known hosts
        "\.git/config"                       # Git config (tokens)
        "credentials"                        # Credential files
        "api[_-]?key"                        # API keys
        "secret"                             # Secrets
        "password\s*="                       # Password assignment
    )
    
    # Suspicious patterns - Warning only
    local suspicious_patterns=(
        "curl\s+.*\|"                        # Curl with pipe
        "wget\s+.*\|"                        # Wget with pipe
        "rm\s+-rf"                           # Recursive delete
        "\|\s*sh"                            # Pipe to shell
        "\|\s*bash"                          # Pipe to bash
        "chmod\s+[0-7]{3,4}\s+/.*/"          # Suspicious chmod
        "CLAUDE\.md"                         # CLAUDE.md modification
        "daemon/loop\.md"                    # loop.md modification
        "\.claude/settings"                  # Settings modification
    )
    
    # Check critical patterns
    for pattern in "${critical_patterns[@]}"; do
        if grep -qE "$pattern" "$file" 2>/dev/null; then
            log_error "CRITICAL: Malicious pattern detected: $pattern"
            grep -nE "$pattern" "$file" | head -3
            ((patterns_found++)) || true
        fi
    done
    
    if [ $patterns_found -gt 0 ]; then
        log_error "CRITICAL patterns found - INSTALLATION REJECTED"
        log_error "This skill contains potentially malicious code"
        exit 1
    fi
    
    # Check high-risk patterns
    for pattern in "${high_risk_patterns[@]}"; do
        if grep -qiE "$pattern" "$file" 2>/dev/null; then
            log_warning "HIGH RISK: Pattern detected: $pattern"
            grep -niE "$pattern" "$file" | head -3
            ((patterns_found++)) || true
        fi
    done
    
    # Check suspicious patterns
    for pattern in "${suspicious_patterns[@]}"; do
        if grep -qE "$pattern" "$file" 2>/dev/null; then
            log_warning "SUSPICIOUS: Pattern detected: $pattern"
            grep -nE "$pattern" "$file" | head -3
            ((patterns_found++)) || true
        fi
    done
    
    if [ $patterns_found -gt 0 ]; then
        echo ""
        log_warning "Found $patterns_found suspicious/high-risk patterns"
        log_warning "Review skill content carefully before installing"
        return 1
    fi
    
    log_success "No malicious patterns detected"
    return 0
}

# ============================================================================
# PROTECTED FILES CHECK
# ============================================================================

check_protected_files() {
    local file="$1"
    
    echo ""
    echo "=== Protected Files Check ==="
    
    local protected_files=(
        "CLAUDE\.md"
        "daemon/loop\.md"
        "\.env"
        "\.mcp\.json"
        "\.claude/settings"
        "memory/learnings\.md"
    )
    
    local modifies_protected=false
    
    for protected in "${protected_files[@]}"; do
        if grep -qE "(write|edit|create|update).*${protected}" "$file" 2>/dev/null; then
            log_warning "May modify protected file: $protected"
            modifies_protected=true
        fi
        if grep -qE "${protected}.*write|${protected}.*edit|${protected}.*create" "$file" 2>/dev/null; then
            log_warning "May modify protected file: $protected"
            modifies_protected=true
        fi
    done
    
    if [ "$modifies_protected" = true ]; then
        log_warning "Skill attempts to modify protected files"
        log_warning "Ensure operator consent before installation"
        return 1
    fi
    
    log_success "No protected file modifications detected"
    return 0
}

# ============================================================================
# NETWORK ENDPOINT CHECK
# ============================================================================

check_network_endpoints() {
    local file="$1"
    
    echo ""
    echo "=== Network Endpoints Check ==="
    
    # Extract URLs/domains from file
    local urls
    urls=$(grep -oE 'https?://[^[:space:]"'"'"']+' "$file" 2>/dev/null | sort -u)
    
    if [ -z "$urls" ]; then
        log_success "No external URLs detected"
        return 0
    fi
    
    local known_safe_domains=(
        "aibtc.com"
        "github.com"
        "githubusercontent.com"
        "drx4.xyz"
        "stacks.co"
        "blockstack.org"
        "hiro.so"
    )
    
    local unknown_domains=0
    
    while IFS= read -r url; do
        local domain
        domain=$(echo "$url" | sed -n 's|^[^/]*//\([^/]*\).*|\1|p')
        
        local is_known=false
        for known in "${known_safe_domains[@]}"; do
            if [[ "$domain" == *"$known"* ]]; then
                is_known=true
                break
            fi
        done
        
        if [ "$is_known" = false ]; then
            log_warning "Unknown domain: $domain"
            ((unknown_domains++)) || true
        fi
    done <<< "$urls"
    
    if [ $unknown_domains -gt 0 ]; then
        log_warning "Found $unknown_domains unknown domains"
        log_warning "Review network endpoints before installation"
        return 1
    fi
    
    log_success "All endpoints use known safe domains"
    return 0
}

# ============================================================================
# YAML FRONTMATTER VALIDATION
# ============================================================================

check_skill_format() {
    local file="$1"
    
    echo ""
    echo "=== Skill Format Validation ==="
    
    # Check for YAML frontmatter
    if ! head -1 "$file" | grep -q "^---$"; then
        log_error "Skill missing YAML frontmatter"
        exit 1
    fi
    
    # Extract frontmatter
    local frontmatter_end
    frontmatter_end=$(grep -n "^---$" "$file" | head -2 | tail -1 | cut -d: -f1)
    
    if [ -z "$frontmatter_end" ] || [ "$frontmatter_end" -le 1 ]; then
        log_error "Invalid YAML frontmatter format"
        exit 1
    fi
    
    # Check required fields
    local frontmatter
    frontmatter=$(head -"$frontmatter_end" "$file")
    
    if ! echo "$frontmatter" | grep -q "^name:"; then
        log_error "Skill missing 'name' field in frontmatter"
        exit 1
    fi
    
    if ! echo "$frontmatter" | grep -q "^description:"; then
        log_warning "Skill missing 'description' field"
    fi
    
    # Check for dangerous fields
    if echo "$frontmatter" | grep -qiE "dangerous|unsafe|insecure"; then
        log_warning "Skill frontmatter contains safety warnings"
    fi
    
    local skill_name
    skill_name=$(echo "$frontmatter" | grep "^name:" | head -1 | sed 's/name:[[:space:]]*//')
    
    log_success "Skill format valid: $skill_name"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local input="$1"
    local install_mode="${2:-}"
    
    echo "=== Skill Installation Validator ==="
    echo "Validating: $input"
    echo ""
    
    # Step 1: Input validation
    validate_input "$input"
    
    # Step 2: Get skill content
    case "$input" in
        http://*|https://*)
            download_skill "$input"
            ;;
        *)
            if [ -f "$input" ]; then
                SKILL_FILE="$input"
            elif [ -d "$input" ]; then
                SKILL_FILE="$input/SKILL.md"
                if [ ! -f "$SKILL_FILE" ]; then
                    log_error "No SKILL.md found in directory"
                    exit 1
                fi
            else
                log_error "Invalid path: $input"
                exit 1
            fi
            ;;
    esac
    
    # Step 3: Compute hash
    echo ""
    echo "=== File Hash ==="
    local hash
    hash=$(compute_hash "$SKILL_FILE")
    echo "SHA256: $hash"
    
    # Step 4: Format validation
    check_skill_format "$SKILL_FILE"
    
    # Step 5: Malicious pattern detection
    check_malicious_patterns "$SKILL_FILE"
    
    # Step 6: Protected files check
    check_protected_files "$SKILL_FILE"
    
    # Step 7: Network endpoints check
    check_network_endpoints "$SKILL_FILE"
    
    # Summary
    echo ""
    echo "=== Validation Summary ==="
    echo "Errors:   $FAILURES"
    echo "Warnings: $WARNINGS"
    
    if [ $FAILURES -gt 0 ]; then
        echo ""
        log_error "Validation FAILED - installation rejected"
        exit 1
    fi
    
    if [ $WARNINGS -gt 0 ]; then
        echo ""
        log_warning "Validation PASSED with warnings"
        log_warning "Review warnings above before proceeding"
        echo ""
        echo "To proceed with installation:"
        echo "  $0 '$input' --install"
        exit 0
    fi
    
    echo ""
    log_success "Validation PASSED - skill appears safe"
    
    if [ "$install_mode" = "--install" ]; then
        echo ""
        echo "Installing skill..."
        
        local skill_name
        skill_name=$(grep "^name:" "$SKILL_FILE" | sed 's/name:[[:space:]]*//')
        local skill_dir="$PROJECT_ROOT/.claude/skills/$skill_name"
        
        mkdir -p "$skill_dir"
        cp "$SKILL_FILE" "$skill_dir/SKILL.md"
        
        log_success "Skill installed to: $skill_dir/SKILL.md"
        log_success "Hash: $hash"
    else
        echo ""
        echo "Run with --install to proceed with installation"
    fi
}

main "$@"