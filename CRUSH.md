# Crush Configuration for PortPeek

## Build Commands
- `chmod +x bin/portpeek.sh` - Make the script executable
- `./bin/portpeek.sh <port_number>` - Run the port checking script

## Lint Commands
- `shellcheck bin/portpeek.sh` - Lint the main script

## Test Commands
- `./tests/test_portpeek.sh` - Run basic tests
- `./bin/portpeek.sh 8080` - Test with a specific port
- Manual testing by running a local server and checking its port

## Code Style Guidelines
- Use shellcheck for linting bash scripts
- Follow Google Shell Style Guide: https://google.github.io/styleguide/shellguide.html
- Use 2-space indentation
- Prefer double quotes for strings with variables
- Use snake_case for variable names
- Comment complex logic
- Error handling with appropriate exit codes
- Use shellcheck directives for exceptions

## Naming Conventions
- Variables: snake_case
- Functions: snake_case
- Files: lowercase with underscores

## Imports and Dependencies
- Only standard Unix utilities (lsof, ss, readlink, etc.)
- No external dependencies

## Error Handling
- Check for required arguments
- Handle missing utilities gracefully
- Use appropriate exit codes (0 for success, 1 for general error)

## Project Structure
- Main script: bin/portpeek.sh
- Temp files: .temp/ directory
- Documentation: README.md
- Tests: tests/ directory

## Usage Examples
- `./bin/portpeek.sh 3000` - Check what's using port 3000
- `./bin/portpeek.sh --kill 3000` - Kill process using port 3000
- `./bin/portpeek.sh` - Check all ports
- `./bin/portpeek.sh --help` - Show help

## UX Features
- Colorized output for better readability
- Interactive prompts for killing processes
- Automatic .temp directory creation
- Fallback mechanisms for different systems