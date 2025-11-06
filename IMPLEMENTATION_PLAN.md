# Implementation Plan: Cross-Platform portpeek

## Design Philosophy
**Universal First, OS-Specific Fallback**

Try methods that work on both platforms, only fall back to OS-specific commands when universal methods fail.

## Changes to portpeek.sh

### 1. Add OS Detection (Top of script, after shebang)

```bash
#!/bin/bash

# portpeek: Find process using a port with details (PID, name, path, cmd, cwd)
# Cross-platform: Linux and macOS
# Usage: portpeek [options] <port>

# Detect operating system
detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    *)       echo "unknown" ;;
  esac
}

OS="$(detect_os)"
```

### 2. Replace check_deps() Function

**Current**: Linux-centric with apt/dnf/pacman
**New**: OS-aware with appropriate package managers

```bash
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
      echo "Warning: Unknown OS. Attempting to run anyway..."
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
```

### 3. Add Universal Helper Functions

**Before the main logic, after check_deps**

```bash
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

  # Method 2: Try lsof (cross-platform but may fail)
  exe=$($use_sudo lsof -p "$pid" 2>/dev/null | awk '$4 == "txt" && $NF ~ /^\// {print $NF; exit}')
  if [[ -n "$exe" && -e "$exe" ]]; then
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
  cmdline=$(ps -p "$pid" -o args= 2>/dev/null)
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
```

### 4. Update output_process() Function

**Replace the hardcoded /proc calls with helper functions**

```bash
output_process() {
  local pid="$1" process_name="$2" app_path="$3" app_name="$4" full_cmd="$5" work_dir="$6"

  if [ ! -d "/proc/$pid" ] && [[ "$OS" == "linux" ]]; then
    echo "Process $pid vanished." >&2
    return
  fi

  # On macOS, we can't check /proc, so just try to get info
  if [[ "$OS" == "macos" ]]; then
    # Check if process still exists using ps
    if ! ps -p "$pid" >/dev/null 2>&1; then
      echo "Process $pid vanished." >&2
      return
    fi
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
```

### 5. Update Main Logic to Use Helper Functions

**Replace the direct /proc reads with helper function calls**

```bash
if [ -n "$output" ]; then
  echo "$output" | while IFS= read -r line; do
    if [ -n "$line" ]; then
      pid=$(echo "$line" | awk '{print $2}')
      process_name=$(echo "$line" | awk '{print $1}')

      # Use helper functions instead of direct /proc access
      app_path=$(get_exe_path "$pid" "$use_sudo")
      app_name=$(basename "$app_path" 2>/dev/null || echo "Unknown")
      full_cmd=$(get_full_command "$pid" "$use_sudo")
      work_dir=$(get_working_dir "$pid" "$use_sudo")

      output_process "$pid" "$process_name" "$app_path" "$app_name" "$full_cmd" "$work_dir"
    fi
  done
else
  # Fallback to ss (Linux only)
  if [[ "$OS" == "linux" ]]; then
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
```

## Benefits of This Design

1. **Universal First**: Uses `ps` and `lsof` which work on both platforms
2. **Smart Fallbacks**: Falls back to `/proc` on Linux when universal methods fail
3. **No Code Duplication**: Helper functions encapsulate OS differences
4. **Maintainable**: Clear separation of concerns
5. **Testable**: Each helper can be tested independently
6. **Graceful Degradation**: Returns "Unknown" instead of failing

## Testing Checklist

### Linux Testing:
- [ ] Basic port lookup (lsof method)
- [ ] /proc fallback working
- [ ] ss fallback when lsof empty
- [ ] All flags: --help, --json, --quiet, -k, -p
- [ ] sudo handling
- [ ] Invalid port handling
- [ ] No process on port

### macOS Testing (User will test):
- [ ] Basic port lookup (lsof method)
- [ ] lsof parsing for exe/cwd/cmd
- [ ] ps for command line
- [ ] All flags work
- [ ] No /proc paths attempted
- [ ] Dependency check for macOS

## File Changes Summary

1. **portpeek.sh**: Complete rewrite with OS detection and helper functions
2. **README.md**: Update to mention macOS support
3. **MACOS_DESIGN.md**: Research document (created)
4. **IMPLEMENTATION_PLAN.md**: This file (created)

## Branch Strategy

Feature branch: `feature/macos-support`
- Based on: current master
- Ready for: macOS testing by user
