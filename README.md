# portpeek

A simple cross-platform Bash script to find the process using a port, showing PID, name, path, full command, and working directory.

Works on both **Linux** and **macOS**.

## Why?
Quickly debug busy ports during dev or sysadmin work. Better than raw `lsof` or `ss` for details like launch command/location.

## Requirements

### Linux
- /proc filesystem (standard on all modern Linux)
- Tools: lsof, awk, sed, basename, readlink, cat, tr (script checks and suggests installs)
- ss (optional fallback, from iproute2)

### macOS
- lsof, awk, sed, basename (all built-in)
- No additional dependencies required

## Installation
One-liner for global use (downloads from this repo):
```
curl -o /usr/local/bin/portpeek https://raw.githubusercontent.com/erik-balfe/portpeek/master/portpeek.sh && chmod +x /usr/local/bin/portpeek
```

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