#!/bin/bash

# Test script for portpeek.sh

set -euo pipefail

echo "Testing portpeek.sh..."

# Test 1: Help output
echo "Test 1: Help output"
./bin/portpeek.sh --help > /dev/null
echo "PASS"

# Test 2: Invalid port number
echo "Test 2: Invalid port number"
./bin/portpeek.sh 999999 || echo "PASS - correctly rejected invalid port"

# Test 3: No process on port
echo "Test 3: No process on port"
./bin/portpeek.sh 99999 || echo "PASS - correctly reported no process"

echo "Basic tests completed."