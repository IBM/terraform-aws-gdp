#!/bin/sh
#
# Copyright (c) IBM Corp. 2026
# SPDX-License-Identifier: Apache-2.0
#
# resolve_agg_host.sh
#
# Resolves the private IP address of the aggregator that a given collector
# should export data to, based on the assignment rule:
#   - Collectors are assigned to aggregators in batches of COLLECTORS_PER_AGG
#   - Collector 1..N  → aggregator 1
#   - Collector N+1..2N → aggregator 2
#   - etc.
#
# If the collector index exceeds total capacity (aggregator_count × COLLECTORS_PER_AGG),
# or if COLLECTORS_PER_AGG is 0, no aggregator is assigned.
#
# Called by modules/collector/main.tf via:
#   ${path.module}/../../scripts/resolve_agg_host.sh
#
# Prints the resolved private IP to stdout (or empty string if no assignment).
# Always exits 0 — "no assignment" is not an error.
#
# ⚠️  POSIX COMPLIANCE REQUIREMENT
# This script MUST remain POSIX Shell Command Language compliant (POSIX.1-2017).
# DO NOT use Bash-specific features:
#   ❌ [[ ]] (use [ ] or case statements)
#   ❌ (( )) arithmetic (use $(( )) or expr)
#   ❌ local keyword (use function-prefixed globals)
#   ❌ echo -e (use printf)
#   ❌ &> redirection (use >/dev/null 2>&1)
#   ❌ Bash arrays or associative arrays
#
# Environment Variables (all required):
#   COLLECTOR_INDEX      - 1-based index of the collector being configured
#   COLLECTOR_NAME       - Name tag of the collector (for log messages)
#   COLLECTORS_PER_AGG   - Number of collectors per aggregator (0 = disabled)
#   AGG_NAME_PREFIX      - Name prefix for aggregator instances (e.g. "guard-agg")
#   AWS_REGION           - AWS region to query

# ============================================================
# Logging (to stderr so stdout stays clean for IP output)
# ============================================================

log_info() {
    printf '[INFO] %s\n' "$*" >&2
}

log_warn() {
    printf '[WARN] %s\n' "$*" >&2
}

log_error() {
    printf '[ERROR] %s\n' "$*" >&2
}

# ============================================================
# Input validation
# ============================================================

_validate_inputs() {
    _vi_errors=0

    if [ -z "${COLLECTOR_INDEX:-}" ]; then
        log_error "COLLECTOR_INDEX is required"
        _vi_errors=$((_vi_errors + 1))
    fi
    if [ -z "${COLLECTOR_NAME:-}" ]; then
        log_error "COLLECTOR_NAME is required"
        _vi_errors=$((_vi_errors + 1))
    fi
    if [ -z "${COLLECTORS_PER_AGG:-}" ]; then
        log_error "COLLECTORS_PER_AGG is required"
        _vi_errors=$((_vi_errors + 1))
    fi
    if [ -z "${AGG_NAME_PREFIX:-}" ]; then
        log_error "AGG_NAME_PREFIX is required"
        _vi_errors=$((_vi_errors + 1))
    fi
    if [ -z "${AWS_REGION:-}" ]; then
        log_error "AWS_REGION is required"
        _vi_errors=$((_vi_errors + 1))
    fi

    if [ "$_vi_errors" -gt 0 ]; then
        return 1
    fi
    return 0
}

# ============================================================
# Main
# ============================================================

main() {
    if ! _validate_inputs; then
        exit 1
    fi

    # Disabled: COLLECTORS_PER_AGG = 0 means no assignment
    if [ "${COLLECTORS_PER_AGG}" -eq 0 ]; then
        log_info "Aggregator assignment disabled (COLLECTORS_PER_AGG=0). Skipping for ${COLLECTOR_NAME}."
        printf ''
        exit 0
    fi

    # Compute which aggregator this collector maps to (1-based, ceiling division)
    # ceil(a/b) = (a + b - 1) / b  (integer arithmetic)
    _agg_index=$(( (COLLECTOR_INDEX + COLLECTORS_PER_AGG - 1) / COLLECTORS_PER_AGG ))

    log_info "Collector ${COLLECTOR_NAME} (index ${COLLECTOR_INDEX}): maps to aggregator index ${_agg_index} (${COLLECTORS_PER_AGG} collectors/aggregator)."

    # Count how many aggregators exist with this prefix (running instances only)
    _agg_count=$(aws ec2 describe-instances \
        --region "${AWS_REGION}" \
        --filters \
            "Name=tag:Name,Values=${AGG_NAME_PREFIX}-*" \
            "Name=instance-state-name,Values=running" \
        --query "length(Reservations[].Instances[])" \
        --output text 2>/dev/null)

    # Treat empty/None/null as 0
    case "${_agg_count}" in
        ''|None|null) _agg_count=0 ;;
    esac

    # Capacity check
    _total_slots=$(( _agg_count * COLLECTORS_PER_AGG ))
    if [ "${_agg_index}" -gt "${_agg_count}" ]; then
        log_info "Collector ${COLLECTOR_NAME} (index ${COLLECTOR_INDEX}) exceeds aggregator capacity" \
            "(${_agg_count} aggregators x ${COLLECTORS_PER_AGG} per agg = ${_total_slots} slots)." \
            "No aggregator assigned."
        printf ''
        exit 0
    fi

    # Construct the aggregator Name tag, e.g. "guard-agg-03"
    _agg_name=$(printf '%s-%02d' "${AGG_NAME_PREFIX}" "${_agg_index}")
    log_info "Looking up private IP for aggregator '${_agg_name}' in region '${AWS_REGION}'..."

    # Query AWS for the private IP of the target aggregator
    _agg_ip=$(aws ec2 describe-instances \
        --region "${AWS_REGION}" \
        --filters \
            "Name=tag:Name,Values=${_agg_name}" \
            "Name=instance-state-name,Values=running" \
        --query "Reservations[0].Instances[0].PrivateIpAddress" \
        --output text 2>/dev/null)

    # Treat empty/None/null as "not found"
    case "${_agg_ip}" in
        ''|None|null)
            log_warn "Aggregator '${_agg_name}' not found or has no private IP. No aggregator assigned to ${COLLECTOR_NAME}."
            printf ''
            exit 0
            ;;
    esac

    log_info "Resolved aggregator for ${COLLECTOR_NAME}: ${_agg_name} → ${_agg_ip}"
    printf '%s' "${_agg_ip}"
    exit 0
}

main
