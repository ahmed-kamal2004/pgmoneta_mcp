#!/bin/bash
## Copyright (C) 2026 The pgmoneta community
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program. If not, see <https://www.gnu.org/licenses/>.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PGMONETA_DIR="$HOME/.pgmoneta"
readonly PGMONETA_MCP_DIR="$HOME/.pgmoneta-mcp"
readonly MASTER_KEY_FILE="$PGMONETA_DIR/master.key"
readonly MCP_MASTER_KEY_FILE="$PGMONETA_MCP_DIR/master.key"
readonly TEST_SUITE_DIR_NAME="test-suite"
readonly TEST_SUITE_DIR="$SCRIPT_DIR/$TEST_SUITE_DIR_NAME"
readonly TEST_MASTER_KEY="$TEST_SUITE_DIR/master.key"
MASTER_KEY_PATH=

## Master key is needed by the integration tests, it needs to be existing in the 
setup_master_key() {
    if [[ -f "$MCP_MASTER_KEY_FILE" ]]; then
        echo "MCP master key already exists, skipping generation."
        chmod 700 "$PGMONETA_MCP_DIR"
        chmod 600 "$MCP_MASTER_KEY_FILE"
        MASTER_KEY_PATH="$MCP_MASTER_KEY_FILE"
    elif [[ -f "$MASTER_KEY_FILE" ]]; then
        echo "Master key already exists, skipping generation."
        chmod 700 "$PGMONETA_DIR"
        chmod 600 "$MASTER_KEY_FILE"
        MASTER_KEY_PATH="$MASTER_KEY_FILE"
    else
        mkdir -p "$PGMONETA_DIR"
        echo "Generating new master key..."
        chmod 700 "$PGMONETA_DIR"
        pgmoneta-admin -g master-key
        chmod 600 "$MASTER_KEY_FILE"
        MASTER_KEY_PATH="$MASTER_KEY_FILE"
    fi
}

copy_master_key() {
    echo "Copying master key to test suite directory..."
    cat "$MASTER_KEY_PATH" > "$TEST_MASTER_KEY"
    mkdir -p "$PGMONETA_MCP_DIR"
    chmod 700 "$PGMONETA_MCP_DIR"
    cat "$MASTER_KEY_PATH" > "$MCP_MASTER_KEY_FILE"
    chmod 600 "$MCP_MASTER_KEY_FILE"
}

build_test_suite() {
    echo "Building test suite container..."
    cd "$TEST_SUITE_DIR"
    make build
    cd "$SCRIPT_DIR"
}

check_port() {
    local port="$1"
    if nc -z localhost "$port" 2>/dev/null; then
        echo "Error: Port $port is already in use. Stop the process using it or change the port configuration in Makefile and tests."
        exit 1
    fi
}

check_container_exists() {
    local container_engine=""
    local container_name="pgmoneta-container"
    
    if command -v podman >/dev/null 2>&1; then
        container_engine="podman"
    elif command -v docker >/dev/null 2>&1; then
        container_engine="docker"
    else
        echo "Error: Neither Docker nor Podman is installed" >&2
        exit 1
    fi
    
    if $container_engine ps -a --format "{{.Names}}" 2>/dev/null | grep -q "$container_name"; then
        echo "Container '$container_name' already exists."
        
        if $container_engine ps --format "{{.Names}}" 2>/dev/null | grep -q "$container_name"; then
            echo "Container is already running. Skipping start."
            return 0
        else
            echo "Container exists but is stopped. Starting it..."
            cd "$TEST_SUITE_DIR"
            $container_engine start "$container_name"
            cd "$SCRIPT_DIR"
            return 0
        fi
    fi
    return 1
}

start_composed_container() {
    if check_container_exists; then
        return 0
    fi
    echo "Starting composed container for testing..."
    check_port 5432
    cd "$TEST_SUITE_DIR"
    make run-default
    cd "$SCRIPT_DIR"
    wait_for_container
}

wait_for_container() {
    max_wait=30
    count=0

    until nc -z localhost 5002; do
        if [ "$count" -ge "$max_wait" ]; then
            echo "pgmoneta did not become ready within ${max_wait}s"
            exit 1
        fi

        echo "Waiting for pgmoneta..."
        sleep 1
        count=$((count + 1))
    done
}

remove_target_directory_if_exists() {
    local target_dir="$SCRIPT_DIR/../target"
    if [[ -d "$target_dir" ]]; then
        echo "Removing existing target directory..."
        rm -rf "$target_dir"
    fi
}

cleanup() {
    echo "Cleaning up test suite environment..."
    remove_target_directory_if_exists
    cd "$TEST_SUITE_DIR"
    make clean
    cd "$SCRIPT_DIR"
}

install_dependencies() {
    echo "Installing dependencies..."
    sudo dnf update -y
    sudo dnf install -y cargo make
}

usage() {
   echo "Usage: $0 [options] [sub-command]"
   echo "Subcommands:"
   echo " setup          Install Dependencies e.g (Rust, Cargo and Make) required for building and running tests"
   echo " build          Set up environment (build, postgreSQL and pgmoneta composed image) without running tests"
   echo " clean          Clean up test suite environment and remove the composed image"
   echo " test           Starts the composed container and run full test suite (clean + build + test)"
   echo " integration    Starts the composed container and run only integration tests (clean + build + integration)"
   echo " unit           Starts the composed container and run only unit tests (clean + build + unit)"
   echo "Options (run tests with optional filter; default is full suite):"
   echo " -m, --module NAME   Run all tests in module NAME"
   echo "Examples:"
   echo "  $0                  Run full test suite"
   echo "  $0 test             Run full test suite"
   echo "  $0 build            Set up environment only; then run e.g. $0 test -m security"
   echo "  $0 test -m security       Run all tests in module 'security'"
   echo "  $0 integration -m info_test    Run integration tests in module 'info_test'"
   exit 1
}

main() {
    MODULE_FILTER=""
    SUBCOMMAND=""
    while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--module)
            shift
            [[ $# -eq 0 ]] && { echo "Error: -m/--module requires NAME"; usage; }
            MODULE_FILTER="$1"
            shift
            ;;
        setup)
            [[ -n "$SUBCOMMAND" ]] && usage
            SUBCOMMAND="setup"
            shift
            ;;
        build)
            [[ -n "$SUBCOMMAND" ]] && usage
            SUBCOMMAND="build"
            shift
            ;;
        clean)
            [[ -n "$SUBCOMMAND" ]] && usage
            SUBCOMMAND="clean"
            shift
            ;;
        test)
            [[ -n "$SUBCOMMAND" ]] && usage
            SUBCOMMAND="test"
            shift
            ;;
        integration)
            [[ -n "$SUBCOMMAND" ]] && usage
            SUBCOMMAND="integration"
            shift
            ;;
        unit)
            [[ -n "$SUBCOMMAND" ]] && usage
            SUBCOMMAND="unit"
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Invalid option: $1"
            usage
            ;;
        *)
            echo "Invalid parameter: $1"
            usage
            ;;
    esac
    done

    if [[ -n "$MODULE_FILTER" ]] && [[ -n "$SUBCOMMAND" ]] && \
       [[ "$SUBCOMMAND" != "test" ]] && [[ "$SUBCOMMAND" != "integration" ]] && [[ "$SUBCOMMAND" != "unit" ]]; then
        echo "Error: -m/--module option can only be used with 'test', 'integration', or 'unit' subcommands, or no subcommand"
        usage
    fi

    if [[ "$SUBCOMMAND" == "setup" ]]; then 
        install_dependencies
        echo "Dependencies installed."
        exit 0
    fi
    if [[ "$SUBCOMMAND" == "build" ]]; then
        setup_master_key
        copy_master_key
        build_test_suite
        echo "Test suite environment set up."
        exit 0
    fi
    if [[ "$SUBCOMMAND" == "clean" ]]; then
        cleanup
        echo "Test suite environment cleaned."
        exit 0
    fi
    if [[ "$SUBCOMMAND" == "test" ]]; then
        start_composed_container
        if [[ -n "$MODULE_FILTER" ]]; then
            cargo test --all-features -- --test-threads=1 --nocapture -- $MODULE_FILTER
        else 
            cargo test --all-features -- --test-threads=1 --nocapture
        fi
        exit 0
    fi
    if [[ "$SUBCOMMAND" == "integration" ]]; then
        start_composed_container
        if [[ -n "$MODULE_FILTER" ]]; then
            cargo test --test "*" -- --test-threads=1 --nocapture -- $MODULE_FILTER
        else 
            cargo test --test "*" -- --test-threads=1 --nocapture
        fi
        exit 0
    fi
    if [[ "$SUBCOMMAND" == "unit" ]]; then
        if [[ -n "$MODULE_FILTER" ]]; then
            cargo test --lib -- --test-threads=1 --nocapture -- $MODULE_FILTER
        else 
            cargo test --lib -- --test-threads=1 --nocapture
        fi
        exit 0
    fi
    if [[ -z "$SUBCOMMAND" ]]; then
        cleanup
        setup_master_key
        copy_master_key
        build_test_suite
        start_composed_container
        if [[ -n "$MODULE_FILTER" ]]; then
            cargo test -- --test-threads=1 --nocapture -- $MODULE_FILTER
        else 
            cargo test -- --test-threads=1 --nocapture
        fi
        exit 0
    fi
}

main "$@"