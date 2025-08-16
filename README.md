# PortPeek

A simple utility to check which processes are using specific ports and optionally kill them.

## Features

- Check what process is using a specific port
- Display detailed information about the process (PID, name, path, command, working directory)
- Kill processes using ports with confirmation
- Fallback to multiple system tools (lsof, ss) for compatibility
- Colorized output for better readability
- Support for checking all ports at once

## Requirements

- bash
- lsof or ss (usually part of util-linux package)
- sudo access (for reading process information)

## Installation

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd portpeek
   ```

2. Make the script executable:
   ```bash
   chmod +x bin/portpeek.sh
   ```

## Usage

```bash
# Check what's using port 3000
./bin/portpeek.sh 3000

# Kill the process using port 3000 (interactive)
./bin/portpeek.sh 3000

# Kill the process using port 3000 (automatic)
./bin/portpeek.sh --kill 3000

# Check all ports
./bin/portpeek.sh

# Show help
./bin/portpeek.sh --help
```

## Options

- `-h, --help`: Show help message
- `-k, --kill`: Kill the process using the port (interactive)

## Temporary Files

The script creates a `.temp` directory for any temporary files. This directory is automatically added to `.gitignore`.

## Contributing

Feel free to fork and submit pull requests. Please follow the existing code style.

## License

MIT