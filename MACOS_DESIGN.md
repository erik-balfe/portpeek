# macOS Cross-Platform Design Research

## Goal
Make portpeek universal with fallbacks: Try cross-platform methods first, fall back to OS-specific when needed.

## Current Linux-Only Dependencies

### Critical Issues:
1. **`/proc` filesystem** - Does not exist on macOS
   - `/proc/$PID/exe` → Executable path
   - `/proc/$PID/cmdline` → Full command line
   - `/proc/$PID/cwd` → Current working directory

2. **`ss` command** - Not available on macOS
   - Used as fallback when lsof fails
   - macOS uses `netstat` or `lsof` only

## Cross-Platform Command Research

### Method 1: lsof (Universal - Works on Both)
**Port Discovery**: ✅ Works identically
```bash
lsof -i :$PORT  # Both Linux and macOS
```

**Process Details from lsof**:
- **cwd (working directory)**: `lsof -p $PID -a -d cwd -Fn`
  - Returns: `n/path/to/directory`
  - ✅ Works on macOS
  - ⚠️  Segfaults on minimal Linux (tested)

- **txt (executable)**: `lsof -p $PID -a -d txt -Fn`
  - Returns: `n/path/to/executable`
  - ✅ Works on macOS
  - ⚠️  May fail on some Linux

### Method 2: ps (Universal - Works on Both)
**Command line**: ✅ Cross-platform
```bash
# Linux (procps)
ps -p $PID -o args=
ps -p $PID -o command=

# macOS (BSD ps)
ps -p $PID -o command=
ps -p $PID -o args=
```

**Executable path**: Different formats
```bash
# Linux
ps -p $PID -o comm=     # Short name only

# macOS
ps -p $PID -o comm=     # Full path on macOS!
```

**Working directory**: ❌ NOT cross-platform
```bash
# Linux procps: ps -p $PID -o cwd=  (not supported on most Linux)
# macOS: No cwd in ps
```

### Method 3: /proc (Linux ONLY)
```bash
readlink /proc/$PID/exe       # Executable path
cat /proc/$PID/cmdline        # Full command
readlink /proc/$PID/cwd       # Working directory
```
✅ Most reliable on Linux
❌ Does not exist on macOS

### Method 4: pwdx (Linux utility)
```bash
pwdx $PID  # Returns: "PID: /path/to/cwd"
```
✅ Works on Linux
❌ Not available on macOS by default

### Method 5: lsof cwd alternative (macOS-friendly)
```bash
# On macOS, parse lsof output for cwd
lsof -p $PID 2>/dev/null | awk '$4 == "cwd" {print $NF}'
```
✅ Works on macOS
⚠️  Format may vary

## Universal Strategy Design

### Tier 1: Universal Methods (Try First)
These work on both platforms:

1. **Port → PID**: `lsof -i :$PORT`
2. **Full Command**: `ps -p $PID -o args=`
3. **Process Name**: Extract from lsof output or `ps -p $PID -o comm=`

### Tier 2: OS-Specific Fallbacks

#### For Executable Path:
```
1. Try: ps -p $PID -o comm= (works differently on each OS)
   - Linux: returns basename only
   - macOS: may return full path
2. Try: lsof -p $PID -a -d txt (parse for executable)
3. Linux fallback: readlink /proc/$PID/exe
4. macOS fallback: lsof -p $PID | grep txt | awk '{print $NF}'
```

#### For Working Directory:
```
1. Try: lsof -p $PID | awk '$4 == "cwd" {print $NF}' (universal lsof parsing)
2. Linux fallback: readlink /proc/$PID/cwd
3. Linux fallback: pwdx $PID (if available)
4. Last resort: "Unknown"
```

#### For Full Command:
```
1. Try: ps -p $PID -o args= (universal)
2. Linux fallback: cat /proc/$PID/cmdline | tr '\0' ' '
3. Last resort: ps -p $PID -o comm=
```

## Implementation Architecture

### Structure:
```bash
#!/bin/bash

# 1. Detect OS
detect_os() {
  OS_TYPE="$(uname -s)"
  case "$OS_TYPE" in
    Linux*)  OS="linux" ;;
    Darwin*) OS="macos" ;;
    *)       OS="unknown" ;;
  esac
}

# 2. Universal helper functions with smart fallbacks
get_process_exe() {
  local pid="$1"
  local exe=""

  # Try 1: ps comm (different on each OS)
  exe=$(ps -p "$pid" -o comm= 2>/dev/null | head -n1)
  if [[ -n "$exe" && "$exe" != "-" ]]; then
    # On macOS this might be full path, on Linux just basename
    if [[ "$exe" == /* ]]; then
      echo "$exe"
      return 0
    fi
  fi

  # Try 2: lsof txt method
  exe=$(lsof -p "$pid" 2>/dev/null | awk '$4 == "txt" {print $NF; exit}')
  if [[ -n "$exe" && -e "$exe" ]]; then
    echo "$exe"
    return 0
  fi

  # Try 3: OS-specific fallback
  if [[ "$OS" == "linux" ]]; then
    exe=$(readlink "/proc/$pid/exe" 2>/dev/null)
    if [[ -n "$exe" ]]; then
      echo "$exe"
      return 0
    fi
  fi

  echo "Unknown"
}

get_process_cmdline() {
  local pid="$1"
  local cmdline=""

  # Try 1: ps (universal)
  cmdline=$(ps -p "$pid" -o args= 2>/dev/null)
  if [[ -n "$cmdline" ]]; then
    echo "$cmdline"
    return 0
  fi

  # Try 2: Linux /proc fallback
  if [[ "$OS" == "linux" && -f "/proc/$pid/cmdline" ]]; then
    cmdline=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ')
    if [[ -n "$cmdline" ]]; then
      echo "$cmdline"
      return 0
    fi
  fi

  echo "Unknown"
}

get_process_cwd() {
  local pid="$1"
  local cwd=""

  # Try 1: lsof (universal parsing)
  cwd=$(lsof -p "$pid" 2>/dev/null | awk '$4 == "cwd" {print $NF; exit}')
  if [[ -n "$cwd" && -d "$cwd" ]]; then
    echo "$cwd"
    return 0
  fi

  # Try 2: Linux /proc fallback
  if [[ "$OS" == "linux" ]]; then
    cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null)
    if [[ -n "$cwd" ]]; then
      echo "$cwd"
      return 0
    fi
  fi

  # Try 3: Linux pwdx fallback
  if [[ "$OS" == "linux" ]] && command -v pwdx >/dev/null 2>&1; then
    cwd=$(pwdx "$pid" 2>/dev/null | cut -d: -f2- | xargs)
    if [[ -n "$cwd" ]]; then
      echo "$cwd"
      return 0
    fi
  fi

  echo "Unknown"
}

# 3. Update dependency checks for OS
check_deps() {
  local required="lsof ps awk basename"
  local linux_optional="readlink cat tr sed"

  case "$OS" in
    linux)
      required="$required $linux_optional"
      # Check for ss as optional
      ;;
    macos)
      # macOS has these built-in, just check essentials
      ;;
  esac

  # Check and warn...
}
```

## Dependency Changes

### Linux:
- **Required**: lsof, ps, awk, basename, readlink, cat, tr, sed
- **Optional**: ss (for fallback)
- **Install**: Same as current (apt/dnf/pacman)

### macOS:
- **Required**: lsof, ps, awk, basename (all built-in)
- **Optional**: None needed
- **Install**: `brew install lsof` (if not present, though it's built-in)

## Testing Strategy

### Linux Tests:
1. Port discovery with lsof
2. /proc filesystem methods
3. Fallback to lsof parsing
4. sudo handling

### macOS Tests:
1. Port discovery with lsof
2. lsof parsing for cwd/exe
3. ps for command lines
4. No /proc paths attempted

## Migration Plan

1. ✅ Research cross-platform methods
2. Add OS detection at script start
3. Refactor into helper functions (get_process_exe, get_process_cmdline, get_process_cwd)
4. Update dependency checks for each OS
5. Remove ss fallback for macOS (not needed)
6. Test on Linux first (we have access)
7. Push to feature branch for macOS testing

## Expected Outcome

**One script that**:
- Works on Linux (maintains current functionality)
- Works on macOS (new support)
- Auto-detects OS
- Uses best available method for each platform
- Gracefully degrades if tools missing
