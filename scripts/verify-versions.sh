#!/bin/bash
# =============================================================================
# verify-versions.sh - Verify Pinned vs Running Versions
# =============================================================================
# Description: Compares pinned image tags in docker-compose.yml with running
#              container versions to detect drift or mismatches
# Usage: ./verify-versions.sh
# Exit Codes: 0=all match, 1=mismatch found
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Track overall status
EXIT_CODE=0

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
print_header() {
    echo ""
    echo "=============================================="
    echo "  Version Verification Report"
    echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="
    echo ""
}

print_result() {
    local component="$1"
    local pinned="$2"
    local running="$3"
    local status="$4"

    if [[ "$status" == "MATCH" ]]; then
        printf "%-12s %-25s %-25s ${GREEN}%s${NC}\n" "$component" "$pinned" "$running" "$status"
    elif [[ "$status" == "MISMATCH" ]]; then
        printf "%-12s %-25s %-25s ${RED}%s${NC}\n" "$component" "$pinned" "$running" "$status"
        EXIT_CODE=1
    else
        printf "%-12s %-25s %-25s ${YELLOW}%s${NC}\n" "$component" "$pinned" "$running" "$status"
    fi
}

get_pinned_version() {
    local service="$1"
    grep -A1 "^  ${service}:" "$COMPOSE_FILE" | grep "image:" | awk -F: '{print $2":"$3}' | tr -d ' '
}

get_running_version() {
    local container="$1"
    docker inspect "$container" --format '{{.Config.Image}}' 2>/dev/null
}

get_actual_version() {
    local container="$1"
    local type="$2"

    case "$type" in
        n8n)
            docker exec "$container" n8n --version 2>/dev/null
            ;;
        postgres)
            docker exec "$container" postgres --version 2>/dev/null | awk '{print $3}'
            ;;
        redis)
            docker exec "$container" redis-server --version 2>/dev/null | awk '{print $3}' | cut -d= -f2
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    print_header

    # Check compose file exists
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        echo -e "${RED}ERROR: docker-compose.yml not found at $COMPOSE_FILE${NC}"
        exit 1
    fi

    # Print table header
    printf "%-12s %-25s %-25s %s\n" "Component" "Pinned Image" "Running Image" "Status"
    printf "%-12s %-25s %-25s %s\n" "-----------" "------------------------" "------------------------" "--------"

    # Check n8n main
    PINNED_N8N=$(get_pinned_version "n8n")
    RUNNING_N8N=$(get_running_version "n8n-main")
    if [[ "$PINNED_N8N" == "$RUNNING_N8N" ]]; then
        print_result "n8n" "$PINNED_N8N" "$RUNNING_N8N" "MATCH"
    elif [[ -z "$RUNNING_N8N" ]]; then
        print_result "n8n" "$PINNED_N8N" "(not running)" "NOT RUNNING"
    else
        print_result "n8n" "$PINNED_N8N" "$RUNNING_N8N" "MISMATCH"
    fi

    # Check n8n worker
    PINNED_WORKER=$(get_pinned_version "n8n-worker")
    RUNNING_WORKER=$(get_running_version "n8n-n8n-worker-1")
    if [[ "$PINNED_WORKER" == "$RUNNING_WORKER" ]]; then
        print_result "n8n-worker" "$PINNED_WORKER" "$RUNNING_WORKER" "MATCH"
    elif [[ -z "$RUNNING_WORKER" ]]; then
        print_result "n8n-worker" "$PINNED_WORKER" "(not running)" "NOT RUNNING"
    else
        print_result "n8n-worker" "$PINNED_WORKER" "$RUNNING_WORKER" "MISMATCH"
    fi

    # Check PostgreSQL
    PINNED_PG=$(get_pinned_version "postgres")
    RUNNING_PG=$(get_running_version "n8n-postgres")
    if [[ "$PINNED_PG" == "$RUNNING_PG" ]]; then
        print_result "postgres" "$PINNED_PG" "$RUNNING_PG" "MATCH"
    elif [[ -z "$RUNNING_PG" ]]; then
        print_result "postgres" "$PINNED_PG" "(not running)" "NOT RUNNING"
    else
        print_result "postgres" "$PINNED_PG" "$RUNNING_PG" "MISMATCH"
    fi

    # Check Redis
    PINNED_REDIS=$(get_pinned_version "redis")
    RUNNING_REDIS=$(get_running_version "n8n-redis")
    if [[ "$PINNED_REDIS" == "$RUNNING_REDIS" ]]; then
        print_result "redis" "$PINNED_REDIS" "$RUNNING_REDIS" "MATCH"
    elif [[ -z "$RUNNING_REDIS" ]]; then
        print_result "redis" "$PINNED_REDIS" "(not running)" "NOT RUNNING"
    else
        print_result "redis" "$PINNED_REDIS" "$RUNNING_REDIS" "MISMATCH"
    fi

    echo ""

    # Show actual software versions
    echo "Actual Software Versions:"
    echo "-------------------------"

    N8N_VER=$(get_actual_version "n8n-main" "n8n")
    PG_VER=$(get_actual_version "n8n-postgres" "postgres")
    REDIS_VER=$(get_actual_version "n8n-redis" "redis")

    printf "  n8n:        %s\n" "${N8N_VER:-N/A}"
    printf "  PostgreSQL: %s\n" "${PG_VER:-N/A}"
    printf "  Redis:      %s\n" "${REDIS_VER:-N/A}"

    echo ""

    # Summary
    if [[ $EXIT_CODE -eq 0 ]]; then
        echo -e "${GREEN}All pinned versions match running containers.${NC}"
    else
        echo -e "${RED}Version mismatch detected! Run 'docker compose up -d' to sync.${NC}"
    fi

    echo ""
    exit $EXIT_CODE
}

main "$@"
