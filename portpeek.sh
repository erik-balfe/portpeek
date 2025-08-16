#!/bin/bash

# PortPeek - A utility to check which processes are using a specific port
# Usage: ./portpeek.sh <port_number>
# Example: ./portpeek.sh 3000

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print usage
print_usage() {
  echo "Usage: $0 <port_number>"
  echo "Example: $0 3000"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to kill process by PID
kill_process() {
  local pid=$1
  echo -e "${YELLOW}Killing process with PID: $pid${NC}"
  if sudo kill -9 "$pid" 2>/dev/null; then
    echo -e "${GREEN}Process $pid killed successfully${NC}"
  else
    echo -e "${RED}Failed to kill process $pid${NC}"
  fi
}

# Function to get process info using lsof
get_lsof_info() {
  local port=$1
  local output
  
  # Get lsof output, skip header
  output=$(sudo lsof -i :"$port" 2>/dev/null | tail -n +2)
  
  if [ -n "$output" ]; then
    echo "$output" | while IFS= read -r line; do
      if [ -n "$line" ]; then
        local pid process_name app_path app_name full_cmd work_dir
        
        pid=$(echo "$line" | awk '{print $2}')
        process_name=$(echo "$line" | awk '{print $1}')
        app_path=$(sudo readlink "/proc/$pid/exe" 2>/dev/null || echo "Unknown")
        app_name=$(basename "$app_path" 2>/dev/null || echo "Unknown")
        full_cmd=$(sudo cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' || echo "Unknown")
        work_dir=$(sudo readlink "/proc/$pid/cwd" 2>/dev/null || echo "Unknown")
        
        echo "========================================"
        echo -e "${GREEN}PORT:${NC} $port"
        echo -e "${GREEN}PID:${NC} $pid"
        echo -e "${GREEN}Process Name:${NC} $process_name"
        echo -e "${GREEN}App Name:${NC} $app_name"
        echo -e "${GREEN}App Path:${NC} $app_path"
        echo -e "${GREEN}Full Command:${NC} $full_cmd"
        echo -e "${GREEN}Working Directory:${NC} $work_dir"
        echo "========================================"
        
        # Ask user if they want to kill the process
        read -p "Kill this process? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          kill_process "$pid"
        fi
      fi
    done
    return 0
  fi
  return 1
}

# Function to get process info using ss as fallback
get_ss_info() {
  local port=$1
  local ss_output pid process_name app_path app_name full_cmd work_dir
  
  ss_output=$(sudo ss -tulpn 2>/dev/null | grep ":$port " 2>/dev/null)
  
  if [ -n "$ss_output" ]; then
    # Parse ss: extract pid and process from last field like users:(("node",pid=350522,fd=23))
    pid=$(echo "$ss_output" | grep -o 'pid=[0-9]*' | cut -d= -f2 | head -n1)
    process_name=$(echo "$ss_output" | grep -o 'users:(("\([^"]*\)' | sed 's/users:(("//' | head -n1)
    app_path=$(sudo readlink "/proc/$pid/exe" 2>/dev/null || echo "Unknown")
    app_name=$(basename "$app_path" 2>/dev/null || echo "Unknown")
    full_cmd=$(sudo cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' || echo "Unknown")
    work_dir=$(sudo readlink "/proc/$pid/cwd" 2>/dev/null || echo "Unknown")
    
    echo "========================================"
    echo -e "${GREEN}PORT:${NC} $port"
    echo -e "${GREEN}PID:${NC} $pid"
    echo -e "${GREEN}Process Name:${NC} $process_name"
    echo -e "${GREEN}App Name:${NC} $app_name"
    echo -e "${GREEN}App Path:${NC} $app_path"
    echo -e "${GREEN}Full Command:${NC} $full_cmd"
    echo -e "${GREEN}Working Directory:${NC} $work_dir"
    echo "========================================"
    
    # Ask user if they want to kill the process
    read -p "Kill this process? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      kill_process "$pid"
    fi
    return 0
  fi
  return 1
}

# Main script execution
main() {
  local port=$1
  
  # Check if port argument is provided
  if [ -z "$port" ]; then
    echo -e "${RED}Error: Port number is required${NC}"
    print_usage
    exit 1
  fi
  
  # Validate port number
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
    echo -e "${RED}Error: Invalid port number. Must be between 1 and 65535${NC}"
    exit 1
  fi
  
  # Check if required commands exist
  if ! command_exists lsof && ! command_exists ss; then
    echo -e "${RED}Error: Neither lsof nor ss command found. Please install either util-linux or lsof package${NC}"
    exit 1
  fi
  
  echo -e "${YELLOW}Checking for processes using port $port...${NC}"
  
  # Try lsof first, then fallback to ss
  if ! get_lsof_info "$port"; then
    if ! get_ss_info "$port"; then
      echo -e "${RED}No process found using port $port${NC}"
      exit 0
    fi
  fi
}

# Run main function with all arguments
main "$@"