#!/bin/bash

# portpeek: Find process using a port with details (PID, name, path, cmd, cwd)
# Cross-platform: Linux and macOS
# Usage: portpeek [options] <port>
# Options: -h/--help, -p/--protocol <tcp|udp|all>, --json, --quiet, -k/--kill

# Detect operating system
detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    *)       echo "unknown" ;;
  esac
}

OS="$(detect_os)"

# Function to check dependencies
check_deps() {
  local missing=""

  # Core dependencies (cross-platform)
  local core_deps="lsof awk basename"

  # OS-specific dependencies
  case "$OS" in
    linux)
      core_deps="$core_deps sed readlink cat tr"
      ;;
    macos)
      # macOS has all these built-in, but check anyway
      core_deps="$core_deps sed"
      ;;
    *)
      echo "Warning: Unknown OS ($OS). Attempting to run anyway..." >&2
      return 0
      ;;
  esac

  # Check for missing dependencies
  for dep in $core_deps; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      missing="$missing $dep"
    fi
  done

  if [ -n "$missing" ]; then
    echo "Missing dependencies:$missing" >&2
    case "$OS" in
      linux)
        echo "Install: sudo apt install lsof coreutils gawk sed (Debian/Ubuntu)" >&2
        echo "Or: sudo dnf install lsof coreutils gawk sed (Fedora)" >&2
        echo "Or: sudo pacman -S lsof coreutils gawk sed (Arch)" >&2
        ;;
      macos)
        echo "Install: brew install lsof gawk gnu-sed" >&2
        echo "Note: Most tools are built-in on macOS" >&2
        ;;
    esac
    exit 1
  fi

  # Optional: Check for ss on Linux (used as fallback)
  if [[ "$OS" == "linux" ]] && ! command -v ss >/dev/null 2>&1; then
    echo "Warning: ss not found; fallback may be limited. Install iproute2." >&2
  fi
}

# Universal function to get executable path
# Tries multiple methods in order of reliability
get_exe_path() {
  local pid="$1"
  local use_sudo="$2"
  local exe=""

  # Method 1: Try /proc on Linux (most reliable)
  if [[ "$OS" == "linux" ]]; then
    exe=$($use_sudo readlink "/proc/$pid/exe" 2>/dev/null)
    if [[ -n "$exe" && "$exe" != "Unknown" ]]; then
      echo "$exe"
      return 0
    fi
  fi

  # Method 2: Try lsof txt, filter for actual executables
  # On macOS, lsof can return locale files, so we need to check executability
  while IFS= read -r candidate; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      exe="$candidate"
      break
    fi
  done < <($use_sudo lsof -p "$pid" 2>/dev/null | awk '$4 == "txt" && $NF ~ /^\// {print $NF}')

  if [[ -n "$exe" ]]; then
    echo "$exe"
    return 0
  fi

  # Method 3: Try ps comm (different behavior on each OS)
  exe=$(ps -p "$pid" -o comm= 2>/dev/null | head -n1 | xargs)
  if [[ -n "$exe" && "$exe" != "-" ]]; then
    # On macOS, comm might be full path; on Linux, just basename
    echo "$exe"
    return 0
  fi

  echo "Unknown"
}

# Universal function to get full command line
get_full_command() {
  local pid="$1"
  local use_sudo="$2"
  local cmdline=""

  # Method 1: Try ps args (cross-platform, most reliable)
  # Use -ww on macOS/BSD to get unlimited width
  if [[ "$OS" == "macos" ]]; then
    cmdline=$(ps -p "$pid" -ww -o args= 2>/dev/null)
  else
    cmdline=$(ps -p "$pid" -o args= 2>/dev/null)
  fi

  if [[ -n "$cmdline" ]]; then
    echo "$cmdline"
    return 0
  fi

  # Method 2: Try /proc on Linux (fallback)
  if [[ "$OS" == "linux" ]]; then
    cmdline=$($use_sudo cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ')
    if [[ -n "$cmdline" ]]; then
      echo "$cmdline"
      return 0
    fi
  fi

  echo "Unknown"
}

# Universal function to get working directory
get_working_dir() {
  local pid="$1"
  local use_sudo="$2"
  local cwd=""

  # Method 1: Try /proc on Linux (most reliable)
  if [[ "$OS" == "linux" ]]; then
    cwd=$($use_sudo readlink "/proc/$pid/cwd" 2>/dev/null)
    if [[ -n "$cwd" && -d "$cwd" ]]; then
      echo "$cwd"
      return 0
    fi
  fi

  # Method 2: Try lsof cwd parsing (cross-platform)
  cwd=$($use_sudo lsof -p "$pid" 2>/dev/null | awk '$4 == "cwd" {print $NF; exit}')
  if [[ -n "$cwd" && -d "$cwd" ]]; then
    echo "$cwd"
    return 0
  fi

  # Method 3: Try pwdx on Linux (if available)
  if [[ "$OS" == "linux" ]] && command -v pwdx >/dev/null 2>&1; then
    cwd=$($use_sudo pwdx "$pid" 2>/dev/null | cut -d: -f2- | xargs)
    if [[ -n "$cwd" && -d "$cwd" ]]; then
      echo "$cwd"
      return 0
    fi
  fi

  echo "Unknown"
}

# Escape string for JSON output
escape_json() {
  local string="$1"
  # Escape backslashes, quotes, and control characters
  string="${string//\\/\\\\}"  # Backslash
  string="${string//\"/\\\"}"  # Double quote
  string="${string//$'\t'/\\t}" # Tab
  string="${string//$'\n'/\\n}" # Newline
  string="${string//$'\r'/\\r}" # Carriage return
  echo "$string"
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
        protocol=*)
          protocol="${OPTARG#*=}"
          if [[ ! "$protocol" =~ ^(tcp|udp|all)$ ]]; then
            echo "Invalid protocol: $protocol" >&2
            exit 1
          fi
          ;;
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
if [[ -z "$port" ]]; then
  echo "Usage: $0 <port_number>" >&2
  exit 1
fi
if ! [[ "$port" =~ ^[0-9]+$ && "$port" -ge 1 && "$port" -le 65535 ]]; then
  echo "Invalid port: Must be number 1-65535" >&2
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
# Note: Do not quote $lsof_proto as lsof needs arguments split
output=$(lsof $lsof_proto 2>/dev/null | tail -n +2)
if [[ -z "$output" ]]; then
  use_sudo="sudo "
  output=$($use_sudo lsof $lsof_proto 2>/dev/null | tail -n +2)
fi

# Function to output in desired format
output_process() {
  local pid="$1" process_name="$2" app_path="$3" app_name="$4" full_cmd="$5" work_dir="$6"

  # Check if process still exists
  if [[ "$OS" == "linux" ]]; then
    if [[ ! -d "/proc/$pid" ]]; then
      echo "Process $pid vanished." >&2
      return
    fi
  else
    # On macOS, we can't check /proc, so use ps
    if ! ps -p "$pid" >/dev/null 2>&1; then
      echo "Process $pid vanished." >&2
      return
    fi
  fi

  if [[ "$json_output" -eq 1 ]]; then
    # Escape all values for safe JSON output
    local pid_esc=$(escape_json "$pid")
    local process_name_esc=$(escape_json "$process_name")
    local app_name_esc=$(escape_json "$app_name")
    local app_path_esc=$(escape_json "$app_path")
    local full_cmd_esc=$(escape_json "$full_cmd")
    local work_dir_esc=$(escape_json "$work_dir")
    echo "{\"pid\": \"$pid_esc\", \"process_name\": \"$process_name_esc\", \"app_name\": \"$app_name_esc\", \"app_path\": \"$app_path_esc\", \"full_command\": \"$full_cmd_esc\", \"working_directory\": \"$work_dir_esc\"}"
  elif [[ "$quiet" -eq 1 ]]; then
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

  if [[ "$kill_pid" -eq 1 ]]; then
    # Try to read from /dev/tty for interactive prompt, fallback to non-interactive
    if [[ -t 1 ]] && [[ -e /dev/tty ]]; then
      read -p "Kill PID $pid? (y/n): " confirm < /dev/tty
    else
      # Assume yes in non-interactive mode
      confirm="y"
    fi
    if [[ "$confirm" = "y" ]] || [[ "$confirm" = "Y" ]]; then
      $use_sudo kill -9 "$pid" && echo "Killed $pid" || echo "Failed to kill $pid"
    fi
  fi
}

if [[ -n "$output" ]]; then
  # Extract unique PIDs to avoid duplicates (lsof can return multiple lines per PID)
  seen_pids=""

  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      pid=$(echo "$line" | awk '{print $2}')
      process_name=$(echo "$line" | awk '{print $1}')

      # Skip if we've already processed this PID
      if [[ " $seen_pids " == *" $pid "* ]]; then
        continue
      fi
      seen_pids="$seen_pids $pid"

      # Use helper functions instead of direct /proc access
      app_path=$(get_exe_path "$pid" "$use_sudo")
      app_name=$(basename "$app_path" 2>/dev/null || echo "Unknown")
      full_cmd=$(get_full_command "$pid" "$use_sudo")
      work_dir=$(get_working_dir "$pid" "$use_sudo")

      output_process "$pid" "$process_name" "$app_path" "$app_name" "$full_cmd" "$work_dir"
    fi
  done <<< "$output"
else
  # Fallback to ss (Linux only)
  if [[ "$OS" == "linux" ]]; then
    ss_filter=""
    case "$protocol" in
      tcp) ss_filter="-t" ;;
      udp) ss_filter="-u" ;;
      all) ss_filter="-tu" ;;
    esac
    # Note: Do not quote ${ss_filter}lpn as ss needs arguments split
    ss_output=$($use_sudo ss ${ss_filter}lpn 2>/dev/null | grep ":$port " 2>/dev/null)
    if [[ -n "$ss_output" ]]; then
      pid=$(echo "$ss_output" | grep -o 'pid=[0-9]*' | cut -d= -f2 | head -n1)
      process_name=$(echo "$ss_output" | grep -o 'users:(("\([^"]*\)' | sed 's/users:(("//' | head -n1)

      # Use helper functions
      app_path=$(get_exe_path "$pid" "$use_sudo")
      app_name=$(basename "$app_path" 2>/dev/null || echo "Unknown")
      full_cmd=$(get_full_command "$pid" "$use_sudo")
      work_dir=$(get_working_dir "$pid" "$use_sudo")

      output_process "$pid" "$process_name" "$app_path" "$app_name" "$full_cmd" "$work_dir"
    else
      echo "No process found using port $port."
      exit 0
    fi
  else
    # macOS: no ss, so lsof must have worked or there's nothing
    echo "No process found using port $port."
    exit 0
  fi
fi
