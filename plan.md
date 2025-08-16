### Plan for Making portpeek Prod-Ready

We'll keep it Bash-based, single-file script for simplicity—easy to distribute, no binaries or Docker nonsense. Focus on robustness for Linux users (assumes /proc, common tools).

**Goals**:
- Add features: Dependency checks, port validation, basic options (e.g., --help, --protocol, --json, --quiet), better error handling, non-sudo fallback.
- Make it user-friendly: Clear output, handle edge cases like vanished PIDs or no deps.
- Prep for GitHub: Repo with script + README (short, concise). Skip CONTRIBUTING.md.

**Steps**:
1. **Add dependency checks**: At start, verify required tools (lsof, ss/awk/sed/basename/readlink/cat/tr). If missing, suggest install commands for common distros.
2. **Add port validation**: Ensure input is numeric 1-65535.
3. **Add options/flags**: Use getopts for --help, -p (protocol: tcp/udp/all), --json (structured output), --quiet (minimal output), -k (kill PID with confirmation).
4. **Handle sudo reliance**: Try without sudo first; if empty/incomplete, suggest/rerun with sudo.
5. **Improve error handling**: Check if PID dir exists, handle multiple processes better, add exit codes.
6. **Update core logic**: Refine parsing for lsof/ss, add full cmd and cwd as before.
7. **Test mentally**: Simulate outputs.
8. **Create README**: Concise Markdown with description, usage, install, examples.
9. **Repo setup advice**: How to create on GH, one-liner install.

Now, implementing step by step.

### Step 1-6: Updated Script (portpeek.sh)

Here's the enhanced version. I added the features logically—starts with checks, parses opts, then runs.

```bash
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
    read -p "Kill PID $pid? (y/n): " confirm
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
```

Changes:
- Dep checks: Exits with install hints.
- Validation: Numeric check.
- Options: Help, protocol filter, JSON/quiet/kill modes.
- Sudo: Tries without, falls back.
- Error: Checks /proc existence.
- Output: Flexible formats, kill with confirm.

### Step 7: Mental Test

For your example (node on 3000):
- Runs lsof, parses as before.
- With --json: Outputs structured.
- With -k: Asks to kill.
- Invalid port: Errors out.
- No deps: Tells you to install.

Should work—tweak if real tests fail.

### Step 8: README.md Content

Copy-paste this into a file:

```markdown
# portpeek

A simple Bash script to find the process using a Linux port, showing PID, name, path, full command, and working directory.

## Why?
Quickly debug busy ports during dev or sysadmin work. Better than raw `lsof` or `ss` for details like launch command/location.

## Requirements
- Linux with /proc filesystem.
- Tools: lsof, awk, sed, basename, readlink, cat, tr (script checks and suggests installs).
- ss (optional fallback, from iproute2).

## Installation
One-liner for global use (downloads from this repo):
```
curl -o /usr/local/bin/portpeek https://raw.githubusercontent.com/yourusername/portpeek/main/portpeek.sh && chmod +x /usr/local/bin/portpeek
```
Replace `yourusername` with your GH username.

Or clone repo and symlink: `ln -s $(pwd)/portpeek.sh /usr/local/bin/portpeek`.

## Usage
```
portpeek [options] <port>
```
Options:
- `-h, --help`: Show help.
- `-p, --protocol <tcp|udp|all>`: Filter protocol (default: all).
- `--json`: JSON output.
- `--quiet`: Minimal output (PID and name).
- `-k, --kill`: Kill PID (confirms first).

Examples:
- Basic: `portpeek 3000`
  ```
  PID: 350522
  Process Name: node
  App Name: node
  App Path: /var/home/erik/.config/nvm/versions/node/v22.7.0/bin/node
  Full Command: /var/home/erik/.config/nvm/versions/node/v22.7.0/bin/node /var/home/erik/devProjects/GroupIB/ti-graph/react-scripts/scripts/start.js 
  Working Directory: /var/home/erik/devProjects/GroupIB/ti-graph
  ---
  ```
- JSON: `portpeek --json 3000` → Structured dict.
- Kill: `portpeek -k 3000` → Prompts to kill.
- Protocol: `portpeek -p tcp 80`

If no process: "No process found using port 3000."

## License
MIT License. Free to use/modify.
```

Short, covers essentials.

### Step 9: Repo Setup

1. Go to GitHub, create new repo "portpeek".
2. Add files: portpeek.sh and README.md.
3. Commit: "Initial release".
4. Optional: Add .gitignore for junk files.
5. Publish: It's live. Share the URL.

Done—it's independent (curl install), works out-of-box after deps (which it handles). If issues, iterate.
