#!/bin/bash

# Usage: ./portpeek.sh <port_number>
# Example: ./portpeek.sh 3000
# Requires sudo for lsof, readlink, cat; assumes lsof is installed.

port="$1"

if [ -z "$port" ]; then
  echo "Usage: $0 <port_number>"
  exit 1
fi

# Get lsof output, skip header
output=$(sudo lsof -i :"$port" | tail -n +2)

if [ -z "$output" ]; then
  # Fallback to ss if lsof empty
  ss_output=$(sudo ss -tulpn | grep ":$port " 2>/dev/null)
  if [ -n "$ss_output" ]; then
    # Parse ss: extract pid and process from last field like users:(("node",pid=350522,fd=23))
    pid=$(echo "$ss_output" | grep -o 'pid=[0-9]*' | cut -d= -f2 | head -n1)
    process_name=$(echo "$ss_output" | grep -o 'users:(("\([^"]*\)' | sed 's/users:(("//' | head -n1)
    app_path=$(sudo readlink "/proc/$pid/exe" 2>/dev/null || echo "Unknown")
    app_name=$(basename "$app_path" 2>/dev/null || echo "Unknown")
    full_cmd=$(sudo cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' || echo "Unknown")
    work_dir=$(sudo readlink "/proc/$pid/cwd" 2>/dev/null || echo "Unknown")
    
    echo "PID: $pid"
    echo "Process Name: $process_name"
    echo "App Name: $app_name"
    echo "App Path: $app_path"
    echo "Full Command: $full_cmd"
    echo "Working Directory: $work_dir"
  else
    echo "No process found using port $port."
  fi
  exit 0
fi

# Parse each line of lsof output
echo "$output" | while IFS= read -r line; do
  if [ -n "$line" ]; then
    pid=$(echo "$line" | awk '{print $2}')
    process_name=$(echo "$line" | awk '{print $1}')
    app_path=$(sudo readlink "/proc/$pid/exe" 2>/dev/null || echo "Unknown")
    app_name=$(basename "$app_path" 2>/dev/null || echo "Unknown")
    full_cmd=$(sudo cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' || echo "Unknown")
    work_dir=$(sudo readlink "/proc/$pid/cwd" 2>/dev/null || echo "Unknown")
    
    echo "PID: $pid"
    echo "Process Name: $process_name"
    echo "App Name: $app_name"
    echo "App Path: $app_path"
    echo "Full Command: $full_cmd"
    echo "Working Directory: $work_dir"
    echo "---"  # Separator for multiple entries
  fi
done
