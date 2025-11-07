# Changelog

All notable changes to portpeek will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-07

### Added
- Cross-platform support for macOS and Linux
- OS auto-detection (Linux/macOS/unknown)
- Universal helper functions with smart fallbacks:
  - `get_exe_path()` - Try /proc, lsof, then ps
  - `get_full_command()` - Try ps with unlimited width on macOS
  - `get_working_dir()` - Try /proc, lsof parsing, pwdx
- JSON output escaping for special characters
- Protocol validation for `--protocol=value` format
- Comprehensive test suite (`test_comprehensive.sh`)
- Deduplication logic for multiple lsof entries

### Changed
- Improved dependency detection for each platform
- Standardized on `[[  ]]` bash brackets throughout
- Enhanced JSON output with proper escaping
- Better error messages to stderr

### Fixed
- Duplicate PID entries when process has multiple connections
- Executable path detection on macOS (filter out locale files)
- Command line truncation on macOS (use ps -ww)
- Interactive mode detection for kill confirmation

## [Unreleased] - Initial Development

### Added
- Basic port lookup functionality
- Support for TCP/UDP protocol filtering
- JSON output format
- Quiet mode
- Kill process with confirmation
- Help documentation
- Dependency checking with install suggestions
