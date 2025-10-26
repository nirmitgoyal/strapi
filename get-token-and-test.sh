#!/bin/bash

# Helper script to get JWT token and run tests
# Usage: ./get-token-and-test.sh [test options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔑 Getting JWT token..."
echo ""

# Run the helper script to get token
TOKEN_OUTPUT=$("$SCRIPT_DIR/get-token.sh")

# Extract just the token (the export line)
JWT_TOKEN=$(echo "$TOKEN_OUTPUT" | grep "^export JWT=" | sed "s/export JWT='//g" | sed "s/'//g")

if [ -z "$JWT_TOKEN" ]; then
    echo "❌ Failed to get JWT token"
    echo ""
    echo "$TOKEN_OUTPUT"
    exit 1
fi

# Show the output
echo "$TOKEN_OUTPUT"

# Export the token
export JWT="$JWT_TOKEN"

# Run tests if no arguments, or pass arguments to test script
if [ $# -eq 0 ]; then
    echo "Running all tests..."
    ./run-all-audit-tests.sh
else
    echo "Running tests with options: $@"
    ./run-all-audit-tests.sh "$@"
fi
