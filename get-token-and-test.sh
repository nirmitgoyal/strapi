#!/bin/bash

# Helper script to get JWT token and run tests
# Usage: ./get-token-and-test.sh [test options]

set -e

echo "🔑 Getting JWT token..."
echo ""

# Run the Node.js script to get token
TOKEN_OUTPUT=$(node get-jwt-token.js)

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
