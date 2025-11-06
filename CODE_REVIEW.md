# Code Quality Review: portpeek.sh

## Overview
Manual code review conducted after successful macOS and Linux testing.

## Issues Found

### 1. **MEDIUM**: Unquoted variable expansion (Lines 235, 238)
**Location**: Lines 235, 238
```bash
# Current:
output=$(lsof $lsof_proto 2>/dev/null | tail -n +2)

# Should be:
output=$(lsof "$lsof_proto" 2>/dev/null | tail -n +2)
```
**Risk**: Word splitting could occur if variable contains spaces
**Impact**: Low (lsof_proto is controlled and doesn't contain spaces)
**Fix**: Add quotes for best practice

### 2. **MEDIUM**: Missing validation for --protocol= format
**Location**: Line 200
```bash
# Current:
protocol=*) protocol="${OPTARG#*=}" ;;

# Missing validation after extraction
```
**Risk**: `--protocol=invalid` would be accepted
**Impact**: Would fail later at lsof stage
**Fix**: Add validation after extraction

### 3. **HIGH**: JSON output doesn't escape special characters
**Location**: Line 260
```bash
# Current:
echo "{\"pid\": \"$pid\", \"process_name\": \"$process_name\", ...}"
```
**Risk**: If command contains quotes or backslashes, JSON is malformed
**Example**: Command with `"test"` would break JSON
**Impact**: JSON parsers would fail
**Fix**: Properly escape JSON strings

### 4. **LOW**: Inconsistent bracket style
**Location**: Throughout
```bash
# Mix of:
if [ -z "$port" ]; then      # Line 214
if [[ "$OS" == "linux" ]]; then   # Line 78
```
**Risk**: None (both work)
**Impact**: Style inconsistency
**Recommendation**: Stick with `[[ ]]` for bash (more powerful, cleaner)

### 5. **LOW**: Unquoted variable in ss command
**Location**: Line 320
```bash
# Current:
ss_output=$($use_sudo ss ${ss_filter}lpn 2>/dev/null | grep ":$port " 2>/dev/null)

# Should be:
ss_output=$($use_sudo ss "${ss_filter}lpn" 2>/dev/null | grep ":$port " 2>/dev/null)
```
**Risk**: Word splitting on ss_filter
**Impact**: Low (controlled variable)

### 6. **INFO**: Missing set -euo pipefail
**Location**: Top of script
**Current**: No error handling flags
**Recommendation**: Consider adding for stricter error handling
**Note**: May not be suitable for this script due to intentional fallbacks

## Strengths

✅ **Excellent OS detection and abstraction**
✅ **Clear function separation and naming**
✅ **Comprehensive error handling for missing processes**
✅ **Good comments explaining macOS-specific workarounds**
✅ **Proper use of local variables in functions**
✅ **Well-structured fallback logic**
✅ **Deduplication logic is clean and effective**
✅ **Cross-platform approach is well thought out**

## Non-Issues (Intentional Design)

1. **Multiple lsof calls**: Intentional for deduplication approach ✓
2. **No set -e**: Intentional to allow fallbacks ✓
3. **sudo handling**: Properly tries without sudo first ✓
4. **Word splitting on seen_pids**: Intentional for space-separated list ✓

## Priority Fixes

**Must Fix Before PR**:
1. ✅ Issue #3: JSON escaping (HIGH priority - breaks parsing)
2. ✅ Issue #2: Protocol validation (MEDIUM priority - user input)

**Nice to Have**:
3. Issue #1: Quote $lsof_proto
4. Issue #5: Quote ss_filter
5. Issue #4: Consistent bracket style

## Test Coverage

All functional tests pass ✅:
- Basic output
- JSON output (but could break with special chars)
- Quiet output
- Protocol filtering
- Kill functionality
- Deduplication
- Cross-platform (Linux + macOS)

## Recommendation

**Action Items**:
1. Fix JSON escaping (critical for production)
2. Add protocol validation for --protocol=value
3. Add quotes to variables
4. Optional: Standardize on [[ ]] brackets

After these fixes, code is production-ready for PR.
