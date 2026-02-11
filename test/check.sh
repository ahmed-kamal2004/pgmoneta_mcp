#!/bin/bash
set -euo pipefail

readonly PGMONETA_DIR="$HOME/.pgmoneta"
readonly MASTER_KEY_FILE="$PGMONETA_DIR/master.key"
readonly TEST_SUITE_DIR_NAME="test-suite"
readonly TEST_SUITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/$TEST_SUITE_DIR_NAME" && pwd)"
readonly TEST_MASTER_KEY="$TEST_SUITE_DIR/master.key"

setup_master_key() {
    if [[ ! -f "$MASTER_KEY_FILE" ]]; then
        echo "Generating new master key..."
        pgmoneta-admin -g master-key
    else 
        echo "Master key already exists, skipping generation."
    fi
    chmod 700 "$PGMONETA_DIR"
    chmod 600 "$MASTER_KEY_FILE"
}

copy_master_key() {
    echo "Copying master key to test suite directory..."
    cat "$MASTER_KEY_FILE" > "$TEST_MASTER_KEY"
}

build_test_suite() {
    echo "Building test suite container..."
    cd "$TEST_SUITE_DIR"
    make build
    cd "$(dirname "${BASH_SOURCE[0]}")"
}

main() {
    setup_master_key
    copy_master_key
    build_test_suite
    echo "Test suite ready"
}

main "$@"
