#!/bin/bash
#
# Copyright (c) IBM Corp. 2026
# SPDX-License-Identifier: Apache-2.0
#
# wait_for_guardium_ready.sh
#
# Polls a Guardium instance until its CLI is ready and operational.
# Used by Terraform modules to ensure Guardium is fully initialized before
# attempting configuration.
#
# Exit Codes:
#   0 - Success: Guardium CLI is ready and operational
#   1 - Timeout: CLI did not become ready within max_wait
#   2 - Pre-flight validation failed (missing dependencies, bad PEM file, etc.)
#   3 - Invalid parameters
#
# Environment Variables (all required unless noted):
#   GUARDIUM_INSTANCE_NAME       - Name of the Guardium instance
#   GUARDIUM_INSTANCE_PUBLIC_IP  - Public IP (may be empty for private-only deployments)
#   GUARDIUM_INSTANCE_PRIVATE_IP - Private IP address
#   GUARDIUM_PEM_FILE            - Path to SSH private key file
#   GUARDIUM_MAX_WAIT            - Maximum wait time in seconds (default: 1200)
#   GUARDIUM_POLL_INTERVAL       - Seconds between polling attempts (default: 30)
#   GUARDIUM_LOG_FILE            - Optional log file path (empty = stdout only)
#   GUARDIUM_DEBUG               - Enable debug logging (default: false)


# ============================================================
# Color Codes and Formatting
# ============================================================

# Check if stdout is a terminal for color support
if [ -t 1 ]; then
    COLOR_RESET='\033[0m'
    COLOR_RED='\033[0;31m'
    COLOR_GREEN='\033[0;32m'
    COLOR_YELLOW='\033[0;33m'
    COLOR_BLUE='\033[0;34m'
    COLOR_CYAN='\033[0;36m'
    BOLD='\033[1m'
else
    COLOR_RESET=''
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_CYAN=''
    BOLD=''
fi

# ============================================================
# Logging Functions
# ============================================================

# Get current timestamp in ISO 8601 format
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"
}

# Log to both stdout and optional log file
log_message() {
    local level="$1"
    local color="$2"
    shift 2
    local message="$*"
    local timestamp=$(get_timestamp)
    local formatted_message="${color}[${level}]${COLOR_RESET} ${message}"

    # Print to stdout with color
    echo -e "${formatted_message}"

    # Write to log file without color codes if GUARDIUM_LOG_FILE is set
    if [ -n "${GUARDIUM_LOG_FILE:-}" ]; then
        echo "[${timestamp}] [${level}] ${message}" >> "$GUARDIUM_LOG_FILE"
    fi
}

log_info() {
    log_message "INFO" "${COLOR_BLUE}" "$@"
}

log_success() {
    log_message "SUCCESS" "${COLOR_GREEN}" "$@"
}

log_warn() {
    log_message "WARN" "${COLOR_YELLOW}" "$@"
}

log_error() {
    log_message "ERROR" "${COLOR_RED}" "$@"
}

log_debug() {
    if [ "${GUARDIUM_DEBUG:-false}" = "true" ]; then
        log_message "DEBUG" "${COLOR_CYAN}" "$@"
    fi
}

# ============================================================
# Cleanup Handler
# ============================================================

cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Script interrupted or failed with exit code: $exit_code"
    fi
}

trap cleanup EXIT INT TERM

# ============================================================
# Pre-flight Validation
# ============================================================

validate_preflight() {
    local errors=0

    log_info "Running pre-flight validation checks..."

    # Check if expect is installed
    if ! command -v expect &> /dev/null; then
        log_error "expect is not installed"
        log_error "Install with:"
        log_error "  - Debian/Ubuntu: apt-get install expect"
        log_error "  - RHEL/CentOS:   yum install expect"
        log_error "  - macOS:         brew install expect"
        ((errors++))
    else
        log_debug "✓ expect is installed: $(command -v expect)"
    fi

    # Check if ssh is installed
    if ! command -v ssh &> /dev/null; then
        log_error "ssh is not installed"
        ((errors++))
    else
        log_debug "✓ ssh is installed: $(command -v ssh)"
    fi

    # Check PEM file exists
    if [ ! -f "$GUARDIUM_PEM_FILE" ]; then
        log_error "PEM file not found: $GUARDIUM_PEM_FILE"
        log_error "Verify the path is correct and the file exists"
        ((errors++))
    else
        log_debug "✓ PEM file exists: $GUARDIUM_PEM_FILE"
    fi

    # Check PEM file is readable
    if [ -f "$GUARDIUM_PEM_FILE" ] && [ ! -r "$GUARDIUM_PEM_FILE" ]; then
        log_error "PEM file is not readable: $GUARDIUM_PEM_FILE"
        log_error "Fix with: chmod 400 $GUARDIUM_PEM_FILE"
        ((errors++))
    else
        log_debug "✓ PEM file is readable"
    fi

    # Check PEM file permissions (should be 400 or 600)
    if [ -f "$GUARDIUM_PEM_FILE" ]; then
        # Use stat command (works on both Linux and macOS)
        local perms
        if stat -c %a "$GUARDIUM_PEM_FILE" &>/dev/null; then
            # Linux
            perms=$(stat -c %a "$GUARDIUM_PEM_FILE")
        elif stat -f %A "$GUARDIUM_PEM_FILE" &>/dev/null; then
            # macOS
            perms=$(stat -f %A "$GUARDIUM_PEM_FILE")
        else
            log_warn "Unable to check PEM file permissions"
            perms="unknown"
        fi

        if [ "$perms" != "400" ] && [ "$perms" != "600" ] && [ "$perms" != "unknown" ]; then
            log_warn "PEM file permissions are $perms (recommended: 400 or 600)"
            log_warn "Fix with: chmod 400 $GUARDIUM_PEM_FILE"
        else
            log_debug "✓ PEM file permissions are acceptable: $perms"
        fi
    fi

    # Validate numeric parameters
    if ! [[ "$GUARDIUM_MAX_WAIT" =~ ^[0-9]+$ ]] || [ "$GUARDIUM_MAX_WAIT" -lt 60 ]; then
        log_error "GUARDIUM_MAX_WAIT must be a number >= 60 (got: $GUARDIUM_MAX_WAIT)"
        ((errors++))
    else
        log_debug "✓ GUARDIUM_MAX_WAIT is valid: $GUARDIUM_MAX_WAIT seconds"
    fi

    if ! [[ "$GUARDIUM_POLL_INTERVAL" =~ ^[0-9]+$ ]] || [ "$GUARDIUM_POLL_INTERVAL" -lt 10 ] || [ "$GUARDIUM_POLL_INTERVAL" -gt "$GUARDIUM_MAX_WAIT" ]; then
        log_error "GUARDIUM_POLL_INTERVAL must be a number >= 10 and <= $GUARDIUM_MAX_WAIT (got: $GUARDIUM_POLL_INTERVAL)"
        ((errors++))
    else
        log_debug "✓ GUARDIUM_POLL_INTERVAL is valid: $GUARDIUM_POLL_INTERVAL seconds"
    fi

    # Validate required environment variables
    if [ -z "${GUARDIUM_INSTANCE_NAME:-}" ]; then
        log_error "GUARDIUM_INSTANCE_NAME environment variable is required"
        ((errors++))
    fi

    if [ -z "${GUARDIUM_INSTANCE_PRIVATE_IP:-}" ]; then
        log_error "GUARDIUM_INSTANCE_PRIVATE_IP environment variable is required"
        ((errors++))
    fi

    if [ $errors -gt 0 ]; then
        log_error "Pre-flight validation failed with $errors error(s)"
        return 2
    fi

    log_success "Pre-flight validation passed"
    return 0
}

# ============================================================
# Network Connectivity Determination
# ============================================================

determine_target() {
    local public_ip="${GUARDIUM_INSTANCE_PUBLIC_IP:-}"
    local private_ip="${GUARDIUM_INSTANCE_PRIVATE_IP}"

    # Prefer public IP if available and not null/empty
    if [ -n "$public_ip" ] && [ "$public_ip" != "null" ] && [ "$public_ip" != "" ]; then
        echo "$public_ip"
        return 0
    else
        echo "$private_ip"
        return 0
    fi
}

get_connection_mode() {
    local target="$1"
    local public_ip="${GUARDIUM_INSTANCE_PUBLIC_IP:-}"

    if [ "$target" = "$public_ip" ] && [ -n "$public_ip" ] && [ "$public_ip" != "null" ]; then
        echo "public"
    else
        echo "private"
    fi
}

# ============================================================
# CLI Readiness Test
# ============================================================

test_cli_ready() {
    local target="$1"
    local pem_file="$2"

    # Test CLI and check system state via expect
    # Exit codes: 0=ready, 1=connection failed, 2=not running yet, 3=not operational
    /usr/bin/expect -c "
        set timeout 15
        log_user 0
        set prompt_pattern {[a-zA-Z0-9._-]+[.-][a-zA-Z0-9._-]+>\s*}
        set operational_seen 0
        set not_running_yet_seen 0

        spawn ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -i $pem_file cli@$target

        expect {
            -nocase {System is now operational in CLI regular mode} {
                set operational_seen 1
                exp_continue
            }
            -nocase {System is not running yet} {
                set not_running_yet_seen 1
                exp_continue
            }
            -re \$prompt_pattern {
                send \"quit\r\"
                expect eof
                if {\$not_running_yet_seen == 1} {
                    exit 2
                } elseif {\$operational_seen == 1} {
                    exit 0
                } else {
                    exit 3
                }
            }
            timeout { exit 1 }
            eof { exit 1 }
        }
    " >/dev/null 2>&1

    return $?
}

# ============================================================
# Success/Warning Display Functions
# ============================================================

# Display result with elapsed time
display_result() {
    local level="$1"      # success or warn
    local icon="$2"       # ✅ or ⚠
    local title="$3"
    local target="$4"
    local connect_mode="$5"
    local start_time="$6"
    local attempt="${7:-}"
    local extra_msg="${8:-}"

    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    local minutes=$((total_time / 60))
    local seconds=$((total_time % 60))

    local log_func="log_${level}"

    echo ""
    $log_func "════════════════════════════════════════════════════════════"
    $log_func "$icon $title"
    $log_func "════════════════════════════════════════════════════════════"
    $log_func "Time elapsed: ${minutes}m ${seconds}s (${total_time} seconds)"
    [ -n "$attempt" ] && $log_func "Attempts:     $attempt"
    $log_func "Target:       $target ($connect_mode)"
    [ -n "$extra_msg" ] && $log_func "" && $log_func "$extra_msg"
    $log_func "════════════════════════════════════════════════════════════"
    echo ""
}

display_success() {
    display_result "success" "✅" "Guardium CLI is ready and operational on $GUARDIUM_INSTANCE_NAME" "$1" "$2" "$3" "$4"
}

display_not_running_warning() {
    local extra="System reported 'System is not running yet' after timeout.\nBackground services may still be initializing.\nConfiguration will proceed, but commands may fail if services aren't ready.\nConsider increasing GUARDIUM_MAX_WAIT if this persists."
    display_result "warn" "⚠" "Guardium system is not fully running yet after timeout" "$1" "$2" "$3" "" "$extra"
}

# ============================================================
# Error Handlers
# ============================================================

handle_timeout() {
    local target="$1"
    local elapsed="$2"
    local max_wait="$3"

    echo ""
    log_error "════════════════════════════════════════════════════════════"
    log_error "❌ Guardium CLI timeout after $max_wait seconds"
    log_error "════════════════════════════════════════════════════════════"
    log_error ""
    log_error "Instance: $GUARDIUM_INSTANCE_NAME"
    log_error "Target:   $target"
    log_error "Elapsed:  $elapsed seconds"
    log_error ""
    log_error "Common causes:"
    log_error "  1. Private subnet without routing (check VPC/NAT/VPN)"
    log_error "  2. Security group blocking SSH port 22"
    log_error "  3. Network connectivity issues"
    log_error ""
    log_error "Troubleshooting:"
    log_error "  • Verify instance: aws ec2 describe-instances --instance-ids <id>"
    log_error "  • Check logs: aws ec2 get-console-output --instance-id <id>"
    log_error "  • Test SSH: ssh -i $GUARDIUM_PEM_FILE cli@$target"
    log_error "  • Increase timeout: guardium_ready_max_wait = 1800"
    log_error "════════════════════════════════════════════════════════════"

    exit 1
}


# ============================================================
# Main Polling Logic
# ============================================================

main() {
    local start_time=$(date +%s)

    # Set defaults for optional parameters
    GUARDIUM_MAX_WAIT="${GUARDIUM_MAX_WAIT:-1200}"
    GUARDIUM_POLL_INTERVAL="${GUARDIUM_POLL_INTERVAL:-30}"
    GUARDIUM_LOG_FILE="${GUARDIUM_LOG_FILE:-}"

    # Create log file if specified
    if [ -n "$GUARDIUM_LOG_FILE" ]; then
        mkdir -p "$(dirname "$GUARDIUM_LOG_FILE")"
        touch "$GUARDIUM_LOG_FILE" || {
            log_warn "Unable to create log file: $GUARDIUM_LOG_FILE"
            log_warn "Continuing with stdout logging only"
            GUARDIUM_LOG_FILE=""
        }
    fi

    # Run pre-flight validation
    if ! validate_preflight; then
        exit 2
    fi

    # Determine connection target
    local target=$(determine_target)
    local connect_mode=$(get_connection_mode "$target")

    # Print header
    echo ""
    log_info "════════════════════════════════════════════════════════════"
    log_info "${BOLD}Waiting for Guardium CLI to be ready and operational${COLOR_RESET}"
    log_info "════════════════════════════════════════════════════════════"
    log_info "Instance:      $GUARDIUM_INSTANCE_NAME"
    log_info "Target:        $target ($connect_mode connection)"
    log_info "Max wait:      $GUARDIUM_MAX_WAIT seconds ($(($GUARDIUM_MAX_WAIT / 60)) minutes)"
    log_info "Poll interval: $GUARDIUM_POLL_INTERVAL seconds"
    if [ -n "$GUARDIUM_LOG_FILE" ]; then
        log_info "Log file:      $GUARDIUM_LOG_FILE"
    fi
    log_info "════════════════════════════════════════════════════════════"
    echo ""

    # Initialize polling variables
    local elapsed=0
    local attempt=1
    local max_attempts=$(($GUARDIUM_MAX_WAIT / $GUARDIUM_POLL_INTERVAL))

    # Polling loop
    while [ $elapsed -lt $GUARDIUM_MAX_WAIT ]; do
        local progress_pct=$((elapsed * 100 / GUARDIUM_MAX_WAIT))
        log_info "Attempt $attempt/$max_attempts: Checking Guardium CLI readiness... (${elapsed}s/${GUARDIUM_MAX_WAIT}s - ${progress_pct}%)"

        # Test CLI connection and check operational status
        test_cli_ready "$target" "$GUARDIUM_PEM_FILE"
        local cli_status=$?

        if [ $cli_status -eq 0 ]; then
            display_success "$target" "$connect_mode" "$start_time" "$attempt"
            exit 0
        elif [ $cli_status -eq 2 ]; then
            log_debug "System not running yet (services initializing)"
        elif [ $cli_status -eq 3 ]; then
            log_debug "System not operational yet (still initializing)"
        else
            log_debug "Connection failed (system may be booting)"
        fi

        # Not ready yet, wait and retry
        log_debug "Waiting $GUARDIUM_POLL_INTERVAL seconds before next attempt..."
        sleep $GUARDIUM_POLL_INTERVAL
        elapsed=$((elapsed + GUARDIUM_POLL_INTERVAL))
        ((attempt++))
    done

    # Final check after timeout
    test_cli_ready "$target" "$GUARDIUM_PEM_FILE"
    local final_status=$?

    if [ $final_status -eq 0 ]; then
        display_success "$target" "$connect_mode" "$start_time" "$attempt"
        exit 0
    elif [ $final_status -eq 2 ]; then
        display_not_running_warning "$target" "$connect_mode" "$start_time"
        exit 0
    else
        handle_timeout "$target" "$elapsed" "$GUARDIUM_MAX_WAIT"
    fi
}

# ============================================================
# Script Entry Point
# ============================================================

# Validate required environment variables before starting
if [ -z "${GUARDIUM_INSTANCE_NAME:-}" ] || [ -z "${GUARDIUM_INSTANCE_PRIVATE_IP:-}" ] || [ -z "${GUARDIUM_PEM_FILE:-}" ]; then
    echo "ERROR: Required environment variables not set"
    echo ""
    echo "Required variables:"
    echo "  GUARDIUM_INSTANCE_NAME       - Name of the Guardium instance"
    echo "  GUARDIUM_INSTANCE_PRIVATE_IP - Private IP address"
    echo "  GUARDIUM_PEM_FILE            - Path to SSH private key"
    echo ""
    echo "Optional variables:"
    echo "  GUARDIUM_INSTANCE_PUBLIC_IP  - Public IP (for public connectivity)"
    echo "  GUARDIUM_MAX_WAIT            - Maximum wait time in seconds (default: 1200)"
    echo "  GUARDIUM_POLL_INTERVAL       - Seconds between polls (default: 30)"
    echo "  GUARDIUM_LOG_FILE            - Log file path (default: stdout only)"
    echo "  GUARDIUM_DEBUG               - Enable debug logging (default: false)"
    echo ""
    exit 3
fi

# Run main function
main

# Made with Bob
