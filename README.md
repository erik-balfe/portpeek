# 🔍 portpeek

> **Find which process is using a port — with full details**

A lightweight, cross-platform CLI tool that shows you exactly which process is hogging that port, with PID, name, path, command, and working directory.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)]()
[![Bash](https://img.shields.io/badge/bash-4.0%2B-green)]()

---

## ✨ Features

- 🚀 **Zero dependencies** — Pure bash, works everywhere
- 🖥️ **Cross-platform** — macOS and Linux
- 📊 **Rich output** — PID, process name, executable path, full command, working directory
- 🎯 **Smart filtering** — Filter by protocol (TCP/UDP)
- 📋 **JSON output** — Perfect for scripting and automation
- ⚡ **Interactive kill** — Quickly kill the process with confirmation
- 🎨 **Clean UI** — Readable output for humans, structured data for machines

---

## 🚀 Quick Start

### Installation

**Homebrew (macOS & Linux) — RECOMMENDED**

```bash
brew install erik-balfe/portpeek/portpeek
```

<details>
<summary><b>Alternative: One-line install script</b></summary>

```bash
curl -fsSL https://raw.githubusercontent.com/erik-balfe/portpeek/master/install.sh | bash
```
</details>

<details>
<summary><b>Alternative: Manual installation</b></summary>

```bash
# Download directly
curl -o /usr/local/bin/portpeek https://raw.githubusercontent.com/erik-balfe/portpeek/master/portpeek.sh
chmod +x /usr/local/bin/portpeek

# Or clone and link
git clone https://github.com/erik-balfe/portpeek.git
cd portpeek
sudo ln -s $(pwd)/portpeek.sh /usr/local/bin/portpeek
```
</details>

### Usage

**Basic usage:**
```bash
portpeek 3000
```

**Output:**
```
PID: 45821
Process Name: node
App Name: node
App Path: /usr/local/bin/node
Full Command: /usr/local/bin/node /app/server.js
Working Directory: /Users/erik/projects/my-app
---
```

---

## 📖 Examples

### Find process on port
```bash
portpeek 8080
```

### Filter by protocol
```bash
# TCP only
portpeek --protocol tcp 443

# UDP only
portpeek -p udp 53
```

### JSON output for scripts
```bash
portpeek --json 3000
```

**Output:**
```json
{
  "port": "3000",
  "protocol": "tcp",
  "pid": "45821",
  "process_name": "node",
  "app_name": "node",
  "app_path": "/usr/local/bin/node",
  "full_command": "/usr/local/bin/node /app/server.js",
  "working_directory": "/Users/erik/projects/my-app"
}
```

### Kill process using port
```bash
portpeek --kill 8080
# or
portpeek -k 8080
```

### Quiet mode (scripts)
```bash
portpeek --quiet 3000
# Output: 45821 node
```

---

## 🎯 Why portpeek?

**Before** (using raw `lsof`):
```bash
$ lsof -i :3000
COMMAND   PID  USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
node    45821  erik   23u  IPv4 0x1a2b3c4d5e6f7g8h      0t0  TCP *:hbci (LISTEN)
```
😕 What's the full command? Where's it running from?

**After** (using portpeek):
```bash
$ portpeek 3000
PID: 45821
Process Name: node
App Name: node
App Path: /usr/local/bin/node
Full Command: /usr/local/bin/node /app/server.js
Working Directory: /Users/erik/projects/my-app
---
```
✅ Everything you need at a glance!

---

## 🛠️ Command Reference

```
Usage: portpeek [options] <port>

Options:
  -h, --help                Show this help message
  -p, --protocol <proto>    Filter by protocol: tcp, udp, or all (default: all)
  --json                    Output in JSON format
  --quiet                   Minimal output (PID and name only)
  -k, --kill                Kill the process (with confirmation)

Examples:
  portpeek 3000                    # Find process on port 3000
  portpeek --protocol tcp 8080     # Only TCP connections
  portpeek --json 5432             # JSON output
  portpeek -k 3000                 # Kill process on port 3000
```

---

## 🔧 Requirements

### macOS
✅ **Everything built-in** — No additional dependencies

### Linux
- `lsof` (usually pre-installed)
- Standard tools: `awk`, `sed`, `readlink`, `basename`
- `/proc` filesystem (all modern Linux)

The script will check for missing dependencies and suggest how to install them.

---

## 🤝 Contributing

Found a bug? Want a feature? Contributions are welcome!

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📝 License

MIT License — see [LICENSE](LICENSE) file for details.

---

## ⭐ Like portpeek?

If this tool saved you time, give it a star! ⭐

It helps others discover the project.

---

## 📬 Support

- **Issues**: [GitHub Issues](https://github.com/erik-balfe/portpeek/issues)
- **Questions**: [Discussions](https://github.com/erik-balfe/portpeek/discussions)

---

**Made with ❤️ for developers who hate port conflicts**
