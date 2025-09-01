#!/bin/bash

# portpeek: Find process using a port with details (PID, name, path, cmd, cwd)
# Usage: portpeek [options] <port>
# Options: -h/--help, -p/--protocol <tcp|udp|all>, --json, --quiet, -k/--kill

# Function to check dependencies
check_deps() {
  local deps="lsof awk sed basename readlink cat tr"
  local missing=""
  for dep in $deps; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      missing="$missing $dep"
    fi
  done
  if [ -n "$missing" ]; then
    echo "Missing dependencies:$missing"
    echo "Install: sudo apt install lsof coreutils gawk sed (Debian/Ubuntu)"
    echo "Or: sudo dnf install lsof coreutils gawk sed (Fedora)"
    echo "Or: sudo pacman -S lsof coreutils gawk sed (Arch)"
    exit 1
  fi
  # ss is fallback, but if not present, warn
  if ! command -v ss >/dev/null 2>&1; then
    echo "Warning: ss not found; fallback may be limited. Install net-tools or iproute2."
  fi
}

# Parse options
protocol="all"
json_output=0
quiet=0
kill_pid=0
while getopts ":hp:k-:" opt; do
  case $opt in
    h) echo "Usage: $0 [options] <port>"
       echo "Options:"
       echo "  -h, --help      Show this help"
       echo "  -p, --protocol  tcp|udp|all (default: all)"
       echo "  --json          JSON output"
       echo "  --quiet         Minimal output (PID and name only)"
       echo "  -k, --kill      Kill the PID (with confirmation)"
       exit 0 ;;
    p) protocol="$OPTARG"
       if [[ ! "$protocol" =~ ^(tcp|udp|all)$ ]]; then
         echo "Invalid protocol: $protocol" >&2
         exit 1
       fi ;;
    k) kill_pid=1 ;;
    -)
      case "$OPTARG" in
        help) exec "$0" -h ;;
        protocol=*) protocol="${OPTARG#*=}" ;;
        json) json_output=1 ;;
        quiet) quiet=1 ;;
        kill) kill_pid=1 ;;
        *) echo "Invalid option: --$OPTARG" >&2; exit 1 ;;
      esac ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
  esac
done
shift $((OPTIND-1))

port="$1"

# Validate port
if [ -z "$port" ]; then
  echo "Usage: $0 <port_number>"
  exit 1
fi
if ! [[ "$port" =~ ^[0-9]+$ && "$port" -ge 1 && "$port" -le 65535 ]]; then
  echo "Invalid port: Must be number 1-65535"
  exit 1
fi

check_deps

# Build lsof command based on protocol
lsof_proto=""
case "$protocol" in
  tcp) lsof_proto="-iTCP:$port" ;;
  udp) lsof_proto="-iUDP:$port" ;;
  all) lsof_proto="-i :$port" ;;
esac

# Try without sudo first
use_sudo=""
output=$(lsof $lsof_proto 2>/dev/null | tail -n +2)
if [ -z "$output" ]; then
  use_sudo="sudo "
  output=$($use_sudo lsof $lsof_proto 2>/dev/null | tail -n +2)
fi

# Function to output in desired format
output_process() {
  local pid="$1" process_name="$2" app_path="$3" app_name="$4" full_cmd="$5" work_dir="$6"
  
  if [ ! -d "/proc/$pid" ]; then
    echo "Process $pid vanished." >&2
    return
  fi
  
  if [ "$json_output" -eq 1 ]; then
    echo "{\"pid\": \"$pid\", \"process_name\": \"$process_name\", \"app_name\": \"$app_name\", \"app_path\": \"$app_path\", \"full_command\": \"$full_cmd\", \"working_directory\": \"$work_dir\"}"
  elif [ "$quiet" -eq 1 ]; then
    echo "PID: $pid Process: $process_name"
  else
    echo "PID: $pid"
    echo "Process Name: $process_name"
    echo "App Name: $app_name"
    echo "App Path: $app_path"
    echo "Full Command: $full_cmd"
    echo "Working Directory: $work_dir"
    echo "---"
  fi
  
  if [ "$kill_pid" -eq 1 ]; then
    if [[ -t 0 ]]; then
      read -p "Kill PID $pid? (y/n): " confirm
    else
      echo "Non-interactive mode: killing PID $pid"
      confirm="y"
    fi
    if [ "$confirm" = "y" ]; then
      $use_sudo kill -9 "$pid" && echo "Killed $pid" || echo "Failed to kill $pid"
    fi
  fi
}

if [ -n "$output" ]; then
  echo "$output" | while IFS= read -r line; do
    if [ -n "$line" ]; then
      pid=$(echo "$line" | awk '{print $2}')
      process_name=$(echo "$line" | awk '{print $1}')
      app_path=$($use_sudo readlink "/proc/$pid/exe" 2>/dev/null || echo "Unknown")
      app_name=$(basename "$app_path" 2>/dev/null || echo "Unknown")
      full_cmd=$($use_sudo cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' || echo "Unknown")
      work_dir=$($use_sudo readlink "/proc/$pid/cwd" 2>/dev/null || echo "Unknown")
      
      output_process "$pid" "$process_name" "$app_path" "$app_name" "$full_cmd" "$work_dir"
    fi
  done
else
  # Fallback to ss (only for listening ports)
  ss_filter=""
  case "$protocol" in
    tcp) ss_filter="-t" ;;
    udp) ss_filter="-u" ;;
    all) ss_filter="-tu" ;;
  esac
  ss_output=$($use_sudo ss ${ss_filter}lpn 2>/dev/null | grep ":$port " 2>/dev/null)
  if [ -n "$ss_output" ]; then
    pid=$(echo "$ss_output" | grep -o 'pid=[0-9]*' | cut -d= -f2 | head -n1)
    process_name=$(echo "$ss_output" | grep -o 'users:(("\([^"]*\)' | sed 's/users:(("//' | head -n1)
    app_path=$($use_sudo readlink "/proc/$pid/exe" 2>/dev/null || echo "Unknown")
    app_name=$(basename "$app_path" 2>/dev/null || echo "Unknown")
    full_cmd=$($use_sudo cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' || echo "Unknown")
    work_dir=$($use_sudo readlink "/proc/$pid/cwd" 2>/dev/null || echo "Unknown")
    
    output_process "$pid" "$process_name" "$app_path" "$app_name" "$full_cmd" "$work_dir"
  else
    echo "No process found using port $port."
    exit 0
  fi
fi