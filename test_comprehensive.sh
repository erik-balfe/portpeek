#!/bin/bash

# Comprehensive test script for portpeek
# Tests all features on Linux

set -e

PORTPEEK="./portpeek.sh"
TEST_PORT=8765

echo "======================================"
echo "Comprehensive portpeek Test Suite"
echo "======================================"

# Check if portpeek exists
if [ ! -f "$PORTPEEK" ]; then
    echo "ERROR: portpeek.sh not found!"
    exit 1
fi

# Test 1: Help
echo -e "\n[Test 1] Testing --help flag"
$PORTPEEK --help
echo "✓ Help works"

# Test 2: Invalid port
echo -e "\n[Test 2] Testing invalid port validation"
$PORTPEEK 99999 2>&1 | grep -q "Invalid port" && echo "✓ Invalid port validation works" || echo "✗ FAILED"

# Test 3: Non-existent port
echo -e "\n[Test 3] Testing non-existent port"
$PORTPEEK 9999 2>&1 | grep -q "No process found" && echo "✓ Non-existent port handling works" || echo "✗ FAILED"

# Test 4-9: Start a test server and test various options
echo -e "\n[Test 4] Starting test server on port $TEST_PORT"

# Start Node.js test server if available
if command -v node >/dev/null 2>&1; then
    node -e "require('http').createServer((req, res) => res.end('Test Server')).listen($TEST_PORT, () => console.log('Server ready'))" &
    SERVER_PID=$!
    echo "Started Node.js test server (PID: $SERVER_PID)"
    sleep 2
elif command -v python3 >/dev/null 2>&1; then
    python3 -m http.server $TEST_PORT >/dev/null 2>&1 &
    SERVER_PID=$!
    echo "Started Python test server (PID: $SERVER_PID)"
    sleep 2
else
    # Fallback to nc
    nc -l $TEST_PORT >/dev/null 2>&1 &
    SERVER_PID=$!
    echo "Started nc listener (PID: $SERVER_PID)"
    sleep 1
fi

# Test 5: Basic output
echo -e "\n[Test 5] Testing basic output"
OUTPUT=$($PORTPEEK $TEST_PORT 2>&1)
echo "$OUTPUT"
echo "$OUTPUT" | grep -q "PID:" && echo "✓ Basic output works" || echo "✗ FAILED"

# Check for duplicates
PID_COUNT=$(echo "$OUTPUT" | grep -c "PID:" || true)
if [ "$PID_COUNT" -eq 1 ]; then
    echo "✓ No duplicate entries"
else
    echo "✗ FAILED: Found $PID_COUNT PID entries (should be 1)"
fi

# Test 6: JSON output
echo -e "\n[Test 6] Testing JSON output"
JSON_OUTPUT=$($PORTPEEK --json $TEST_PORT 2>&1 | grep -v "Warning:")
echo "$JSON_OUTPUT"
echo "$JSON_OUTPUT" | grep -q '"pid"' && echo "✓ JSON output works" || echo "✗ FAILED"

# Check JSON for duplicates
JSON_COUNT=$(echo "$JSON_OUTPUT" | grep -c '"pid"' || true)
if [ "$JSON_COUNT" -eq 1 ]; then
    echo "✓ No duplicate JSON entries"
else
    echo "✗ FAILED: Found $JSON_COUNT JSON entries (should be 1)"
fi

# Test 7: Quiet output
echo -e "\n[Test 7] Testing quiet output"
QUIET_OUTPUT=$($PORTPEEK --quiet $TEST_PORT 2>&1 | grep -v "Warning:")
echo "$QUIET_OUTPUT"
echo "$QUIET_OUTPUT" | grep -q "PID:" && echo "✓ Quiet output works" || echo "✗ FAILED"

# Test 8: Protocol filter
echo -e "\n[Test 8] Testing protocol filter (TCP)"
PROTO_OUTPUT=$($PORTPEEK -p tcp $TEST_PORT 2>&1)
echo "$PROTO_OUTPUT" | grep -q "PID:" && echo "✓ Protocol filter works" || echo "✗ FAILED"

# Test 9: Kill functionality (non-interactive)
echo -e "\n[Test 9] Testing kill functionality"
echo "Note: Testing with 'y' response"
# We can't easily test interactive input, but we can verify the script runs
$PORTPEEK -k $TEST_PORT 2>&1 | head -n 20
echo "✓ Kill flag executed (manual verification needed for confirmation prompt)"

# Clean up - kill the test server if it's still running
if ps -p $SERVER_PID >/dev/null 2>&1; then
    kill $SERVER_PID 2>/dev/null || true
    echo "Cleaned up test server"
fi

echo -e "\n======================================"
echo "Test Suite Complete!"
echo "======================================"
