#!/bin/sh
#
# Copyright (c) IBM Corp. 2026
# SPDX-License-Identifier: Apache-2.0
#
# wait_for_guardium_ready.sh
#
# This script is shared across the following modules via relative path
# (${path.module}/../../scripts/wait_for_guardium_ready.sh):
#   - modules/central-manager
#   - modules/aggregator
#   - modules/collector
#
# ⚠️  POSIX COMPLIANCE REQUIREMENT
# This script MUST remain POSIX Shell Command Language compliant (POSIX.1-2017)
# to ensure compatibility across all Linux distributions, including:
#   - Alpine Linux (BusyBox ash)
#   - Debian/Ubuntu (dash)
#   - RHEL/CentOS (bash in POSIX mode)
#   - Any system with /bin/sh
#
# DO NOT use Bash-specific features:
#   ❌ [[ ]] (use [ ] or case statements)
#   ❌ (( )) arithmetic (use $(( )) or expr)
#   ❌ local keyword (use function-prefixed globals)
#   ❌ echo -e (use printf)
#   ❌ &> redirection (use >/dev/null 2>&1)
#   ❌ Bash arrays or associative arrays
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
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Log to both stdout and optional log file
log_message() {
    _log_level="$1"
    _log_color="$2"
    shift 2
    _log_message="$*"
    _log_timestamp=$(get_timestamp)
    _log_formatted="${_log_color}[${_log_level}]${COLOR_RESET} ${_log_message}"

    # Print to stdout with color
    printf '%b\n' "${_log_formatted}"

    # Write to log file without color codes if GUARDIUM_LOG_FILE is set
    if [ -n "${GUARDIUM_LOG_FILE:-}" ]; then
        echo "[${_log_timestamp}] [${_log_level}] ${_log_message}" >> "$GUARDIUM_LOG_FILE"
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
    _cleanup_exit_code=$?
    if [ $_cleanup_exit_code -ne 0 ]; then
        log_error "Script interrupted or failed with exit code: $_cleanup_exit_code"
    fi
}

trap cleanup EXIT INT TERM

# ============================================================
# Pre-flight Validation
# ============================================================

validate_preflight() {
    _preflight_errors=0

    log_info "Running pre-flight validation checks..."

    # Check if expect is installed
    if ! command -v expect >/dev/null 2>&1; then
        log_error "expect is not installed"
        log_error "Install with:"
        log_error "  - Debian/Ubuntu: apt-get install expect"
        log_error "  - RHEL/CentOS:   yum install expect"
        log_error "  - macOS:         brew install expect"
        _preflight_errors=$((_preflight_errors + 1))
    else
        log_debug "✓ expect is installed: $(command -v expect)"
    fi

    # Check if ssh is installed
    if ! command -v ssh >/dev/null 2>&1; then
        log_error "ssh is not installed"
        _preflight_errors=$((_preflight_errors + 1))
    else
        log_debug "✓ ssh is installed: $(command -v ssh)"
    fi

    # Check PEM file exists
    if [ ! -f "$GUARDIUM_PEM_FILE" ]; then
        log_error "PEM file not found: $GUARDIUM_PEM_FILE"
        log_error "Verify the path is correct and the file exists"
        _preflight_errors=$((_preflight_errors + 1))
    else
        log_debug "✓ PEM file exists: $GUARDIUM_PEM_FILE"
    fi

    # Check PEM file is readable
    if [ -f "$GUARDIUM_PEM_FILE" ] && [ ! -r "$GUARDIUM_PEM_FILE" ]; then
        log_error "PEM file is not readable: $GUARDIUM_PEM_FILE"
        log_error "Fix with: chmod 400 $GUARDIUM_PEM_FILE"
        _preflight_errors=$((_preflight_errors + 1))
    else
        log_debug "✓ PEM file is readable"
    fi

    # Check PEM file permissions (should be 400 or 600)
    if [ -f "$GUARDIUM_PEM_FILE" ]; then
        # Use ls -l for POSIX compatibility
        _pem_perms=$(ls -l "$GUARDIUM_PEM_FILE" 2>/dev/null | awk '{print $1}')
        case "$_pem_perms" in
            -r--------*)
                log_debug "✓ PEM file permissions are acceptable (400)"
                ;;
            -rw-------*)
                log_debug "✓ PEM file permissions are acceptable (600)"
                ;;
            *)
                if [ -n "$_pem_perms" ]; then
                    log_warn "PEM file permissions may be too permissive: $_pem_perms"
                    log_warn "Recommended: chmod 400 $GUARDIUM_PEM_FILE"
                fi
                ;;
        esac
    fi

    # Validate numeric parameters
    case "$GUARDIUM_MAX_WAIT" in
        ''|*[!0-9]*)
            log_error "GUARDIUM_MAX_WAIT must be a number >= 60 (got: $GUARDIUM_MAX_WAIT)"
            _preflight_errors=$((_preflight_errors + 1))
            ;;
        *)
            if [ "$GUARDIUM_MAX_WAIT" -lt 60 ]; then
                log_error "GUARDIUM_MAX_WAIT must be >= 60 (got: $GUARDIUM_MAX_WAIT)"
                _preflight_errors=$((_preflight_errors + 1))
            else
                log_debug "✓ GUARDIUM_MAX_WAIT is valid: $GUARDIUM_MAX_WAIT seconds"
            fi
            ;;
    esac

    case "$GUARDIUM_POLL_INTERVAL" in
        ''|*[!0-9]*)
            log_error "GUARDIUM_POLL_INTERVAL must be a number >= 10 and <= $GUARDIUM_MAX_WAIT (got: $GUARDIUM_POLL_INTERVAL)"
            _preflight_errors=$((_preflight_errors + 1))
            ;;
        *)
            if [ "$GUARDIUM_POLL_INTERVAL" -lt 10 ] || [ "$GUARDIUM_POLL_INTERVAL" -gt "$GUARDIUM_MAX_WAIT" ]; then
                log_error "GUARDIUM_POLL_INTERVAL must be >= 10 and <= $GUARDIUM_MAX_WAIT (got: $GUARDIUM_POLL_INTERVAL)"
                _preflight_errors=$((_preflight_errors + 1))
            else
                log_debug "✓ GUARDIUM_POLL_INTERVAL is valid: $GUARDIUM_POLL_INTERVAL seconds"
            fi
            ;;
    esac

    # Validate required environment variables
    if [ -z "${GUARDIUM_INSTANCE_NAME:-}" ]; then
        log_error "GUARDIUM_INSTANCE_NAME environment variable is required"
        _preflight_errors=$((_preflight_errors + 1))
    fi

    if [ -z "${GUARDIUM_INSTANCE_PRIVATE_IP:-}" ]; then
        log_error "GUARDIUM_INSTANCE_PRIVATE_IP environment variable is required"
        _preflight_errors=$((_preflight_errors + 1))
    fi

    if [ $_preflight_errors -gt 0 ]; then
        log_error "Pre-flight validation failed with $_preflight_errors error(s)"
        return 2
    fi

    log_success "Pre-flight validation passed"
    return 0
}

# ============================================================
# Network Connectivity Determination
# ============================================================

determine_target() {
    _target_public_ip="${GUARDIUM_INSTANCE_PUBLIC_IP:-}"
    _target_private_ip="${GUARDIUM_INSTANCE_PRIVATE_IP}"

    # Prefer public IP if available and not null/empty
    if [ -n "$_target_public_ip" ] && [ "$_target_public_ip" != "null" ] && [ "$_target_public_ip" != "" ]; then
        echo "$_target_public_ip"
        return 0
    else
        echo "$_target_private_ip"
        return 0
    fi
}

get_connection_mode() {
    _conn_target="$1"
    _conn_public_ip="${GUARDIUM_INSTANCE_PUBLIC_IP:-}"

    if [ "$_conn_target" = "$_conn_public_ip" ] && [ -n "$_conn_public_ip" ] && [ "$_conn_public_ip" != "null" ]; then
        echo "public"
    else
        echo "private"
    fi
}

# ============================================================
# CLI Readiness Test
# ============================================================

test_cli_ready() {
    _test_target="$1"
    _test_pem_file="$2"

    # Test CLI and check system state via expect
    # Exit codes: 0=ready, 1=connection failed, 2=not running yet, 3=not operational
    /usr/bin/expect -c "
        set timeout 15
        log_user 0
        set prompt_pattern {[a-zA-Z0-9._-]+[.-][a-zA-Z0-9._-]+>\s*}
        set operational_seen 0
        set not_running_yet_seen 0

        spawn ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -i $_test_pem_file cli@$_test_target

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
    _disp_level="$1"      # success or warn
    _disp_icon="$2"       # ✅ or ⚠
    _disp_title="$3"
    _disp_target="$4"
    _disp_connect_mode="$5"
    _disp_start_time="$6"
    _disp_attempt="${7:-}"
    _disp_extra_msg="${8:-}"

    _disp_end_time=$(date +%s)
    _disp_total_time=$((_disp_end_time - _disp_start_time))
    _disp_minutes=$((_disp_total_time / 60))
    _disp_seconds=$((_disp_total_time % 60))

    _disp_log_func="log_${_disp_level}"

    echo ""
    $_disp_log_func "════════════════════════════════════════════════════════════"
    $_disp_log_func "$_disp_icon $_disp_title"
    $_disp_log_func "════════════════════════════════════════════════════════════"
    $_disp_log_func "Time elapsed: ${_disp_minutes}m ${_disp_seconds}s (${_disp_total_time} seconds)"
    [ -n "$_disp_attempt" ] && $_disp_log_func "Attempts:     $_disp_attempt"
    $_disp_log_func "Target:       $_disp_target ($_disp_connect_mode)"
    [ -n "$_disp_extra_msg" ] && $_disp_log_func "" && $_disp_log_func "$_disp_extra_msg"
    $_disp_log_func "════════════════════════════════════════════════════════════"
    echo ""
}

display_success() {
    display_result "success" "✅" "Guardium CLI is ready and operational on $GUARDIUM_INSTANCE_NAME" "$1" "$2" "$3" "$4"
}

display_not_running_warning() {
    _warn_extra="System reported 'System is not running yet' after timeout.\nBackground services may still be initializing.\nConfiguration will proceed, but commands may fail if services aren't ready.\nConsider increasing GUARDIUM_MAX_WAIT if this persists."
    display_result "warn" "⚠" "Guardium system is not fully running yet after timeout" "$1" "$2" "$3" "" "$_warn_extra"
}

# ============================================================
# Error Handlers
# ============================================================

handle_timeout() {
    _timeout_target="$1"
    _timeout_elapsed="$2"
    _timeout_max_wait="$3"

    echo ""
    log_error "════════════════════════════════════════════════════════════"
    log_error "❌ Guardium CLI timeout after $_timeout_max_wait seconds"
    log_error "════════════════════════════════════════════════════════════"
    log_error ""
    log_error "Instance: $GUARDIUM_INSTANCE_NAME"
    log_error "Target:   $_timeout_target"
    log_error "Elapsed:  $_timeout_elapsed seconds"
    log_error ""
    log_error "Common causes:"
    log_error "  1. Private subnet without routing (check VPC/NAT/VPN)"
    log_error "  2. Security group blocking SSH port 22"
    log_error "  3. Network connectivity issues"
    log_error ""
    log_error "Troubleshooting:"
    log_error "  • Verify instance: aws ec2 describe-instances --instance-ids <id>"
    log_error "  • Check logs: aws ec2 get-console-output --instance-id <id>"
    log_error "  • Test SSH: ssh -i $GUARDIUM_PEM_FILE cli@$_timeout_target"
    log_error "  • Increase timeout: guardium_ready_max_wait = 1800"
    log_error "════════════════════════════════════════════════════════════"

    exit 1
}


# ============================================================
# Main Polling Logic
# ============================================================

main() {
    _main_start_time=$(date +%s)

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
    _main_target=$(determine_target)
    _main_connect_mode=$(get_connection_mode "$_main_target")

    # Print header
    echo ""
    log_info "════════════════════════════════════════════════════════════"
    log_info "${BOLD}Waiting for Guardium CLI to be ready and operational${COLOR_RESET}"
    log_info "════════════════════════════════════════════════════════════"
    log_info "Instance:      $GUARDIUM_INSTANCE_NAME"
    log_info "Target:        $_main_target ($_main_connect_mode connection)"
    log_info "Max wait:      $GUARDIUM_MAX_WAIT seconds ($(($GUARDIUM_MAX_WAIT / 60)) minutes)"
    log_info "Poll interval: $GUARDIUM_POLL_INTERVAL seconds"
    if [ -n "$GUARDIUM_LOG_FILE" ]; then
        log_info "Log file:      $GUARDIUM_LOG_FILE"
    fi
    log_info "════════════════════════════════════════════════════════════"
    echo ""

    # Initialize polling variables
    _main_elapsed=0
    _main_attempt=1
    _main_max_attempts=$(($GUARDIUM_MAX_WAIT / $GUARDIUM_POLL_INTERVAL))

    # Polling loop
    while [ $_main_elapsed -lt $GUARDIUM_MAX_WAIT ]; do
        _main_progress_pct=$((_main_elapsed * 100 / GUARDIUM_MAX_WAIT))
        log_info "Attempt $_main_attempt/$_main_max_attempts: Checking Guardium CLI readiness... (${_main_elapsed}s/${GUARDIUM_MAX_WAIT}s - ${_main_progress_pct}%)"

        # Test CLI connection and check operational status
        test_cli_ready "$_main_target" "$GUARDIUM_PEM_FILE"
        _main_cli_status=$?

        if [ $_main_cli_status -eq 0 ]; then
            display_success "$_main_target" "$_main_connect_mode" "$_main_start_time" "$_main_attempt"
            exit 0
        elif [ $_main_cli_status -eq 2 ]; then
            log_debug "System not running yet (services initializing)"
        elif [ $_main_cli_status -eq 3 ]; then
            log_debug "System not operational yet (still initializing)"
        else
            log_debug "Connection failed (system may be booting)"
        fi

        # Not ready yet, wait and retry
        log_debug "Waiting $GUARDIUM_POLL_INTERVAL seconds before next attempt..."
        sleep $GUARDIUM_POLL_INTERVAL
        _main_elapsed=$((_main_elapsed + GUARDIUM_POLL_INTERVAL))
        _main_attempt=$((_main_attempt + 1))
    done

    # Final check after timeout
    test_cli_ready "$_main_target" "$GUARDIUM_PEM_FILE"
    _main_final_status=$?

    if [ $_main_final_status -eq 0 ]; then
        display_success "$_main_target" "$_main_connect_mode" "$_main_start_time" "$_main_attempt"
        exit 0
    elif [ $_main_final_status -eq 2 ]; then
        display_not_running_warning "$_main_target" "$_main_connect_mode" "$_main_start_time"
        exit 0
    else
        handle_timeout "$_main_target" "$_main_elapsed" "$GUARDIUM_MAX_WAIT"
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
