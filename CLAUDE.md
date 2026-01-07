# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker Manager is an interactive Bash script (~873 lines) that manages Docker Compose projects individually or in batches. It provides a menu-driven interface with advanced features including port mapping visualization, simple log viewing, and multi-project operations.

**Version**: 2.0 (Enhanced)
**Size**: ~873 lines
**Dependencies**: Docker Compose V2, bash 4+, column, less

## Architecture Overview

### Single Script Design
The entire application is contained in `docker-manager.sh` - a single Bash script organized into functional sections with clear separation of concerns.

### Code Organization (by line ranges)

```
Lines 1-31:      Initialization (colors, dependency checks, docker group validation)
Lines 32-40:     Global Variables (arrays, mode flags, cache settings)
Lines 41-87:     Utility Functions (select_services - extracted pattern)
Lines 88-122:    Project Selection (select_project - discovers docker-compose.yml files)
Lines 123-173:   Status & Validation (require_built, check_status)
Lines 174-299:   Port Mapping Functions (generate_service_url, show_port_mappings)
Lines 300-378:   Log Functions (quick_tail_logs - simplified)
Lines 379-665:   Multi-Project Functions (select_multiple_projects, multi_project_status, batch_operation, multiproject_menu)
Lines 666-873:   Main Program (menu loop with 14 options + navigation)
```

## Key Components

### Global Variables (Lines 32-40)
```bash
declare -a PROJECTS=()              # All discovered projects
declare -a SELECTED_PROJECTS=()     # Currently selected for batch ops
declare -A PROJECT_SELECTION=()     # Selection state tracking
declare -A PROJECT_STATUS_CACHE=()  # Status cache (30s TTL)
MULTI_PROJECT_MODE=false            # Current mode flag
CACHE_TTL=30                        # Cache timeout in seconds
```

### Core Functions

**select_services()** (Lines 47-121)
- Extracted pattern from options 10, 11, 12
- Accepts: prompt message, allow_multiple boolean
- Returns: Space-separated list of selected service names to stdout ONLY
- **All prompts and errors go to stderr (>&2)** to prevent contamination
- Handles both numeric input and service names (exact match)
- Validates input is not empty and services exist
- Critical fix: Messages redirected to stderr prevent wrong services from being selected

**select_project()** (Lines 94-122)
- Discovers `docker-compose.yml` files in HOME directory
- Populates global `PROJECTS` array
- Interactive numbered selection
- Changes working directory to selected project

**check_status()** (Lines 140-173)
- Displays comprehensive service status table
- Cross-references defined services vs running containers
- Color coding: green (Up), red (Exited/Not built), yellow (other)
- Format: SERVICE | IMAGE | STATUS

### Port Mapping (Lines 174-299)

**generate_service_url()** (Lines 180-233)
- Pattern matches service names and ports to generate appropriate URLs
- Recognizes: nginx/apache → http://, postgres → postgresql://, redis → redis://, etc.
- Falls back to common ports: 80/8080 → http, 443 → https, 5432 → postgresql, etc.

**show_port_mappings()** (Lines 235-299)
- Parses `docker compose ps --format "{{.Service}}\t{{.Ports}}\t{{.Status}}"`
- Extracts port mappings using regex: `([0-9]+)-\>([0-9]+)/(tcp|udp)`
- Displays table: SERVICE | CONTAINER_PORT | HOST_PORT | PROTOCOL | URL
- Handles stopped services and services without exposed ports

### Simple Logs (Lines 300-378)

**quick_tail_logs()** (Lines 340-378)
- Simplified log viewer (user requested)
- Lists all services with option 0 for "all services"
- User selects service by number
- Shows last 100 lines with `docker compose logs --tail=100`
- Uses `less -R` for paging (press 'q' to exit)
- Press ENTER to return to main menu
- No complex submenus or save options

### Multi-Project Management (Lines 379-665)

**select_multiple_projects()** (Lines ~385-470)
- **Interactive toggle mode** (user preference)
- Shows checkboxes [X] / [ ] for each project
- Commands: number (toggle), 'a' (all), 'n' (none), 'd' (done)
- Updates global `SELECTED_PROJECTS` array
- Validates at least 1 project selected

**multi_project_status()** (Lines ~475-525)
- Displays table of selected projects
- Columns: PROJECT | SERVICES | RUNNING | STOPPED | NOT_BUILT
- Calculates per-project statistics on-the-fly

**batch_operation()** (Lines ~530-595)
- **Sequential execution** (user preference) for safety
- Operations: start, stop, restart, up, down, build
- Confirmation prompt for destructive operations (down)
- Per-project success/failure tracking
- Summary report with failed project list

**multiproject_menu()** (Lines ~600-665)
- Dedicated submenu for multi-project mode
- Project selection options (s, a, n)
- 6 batch operations
- Loop until user exits back to single-project mode

## Menu Structure

### Main Menu Options (Lines 666-873)

**1-12**: Original single-project operations (maintained for backwards compatibility)
- Options 10-11 now use **FIXED** `select_services()` with stderr redirection

**13**: Simple log viewer (quick_tail_logs) - select service, view 100 lines, press ENTER
**14**: Port mapping visualization (show_port_mappings)
**m**: Multi-project mode (enters multiproject_menu loop)
**c**: Change project (calls select_project)
**e**: Exit script

## Important Implementation Details

### Service Selection Pattern - CRITICAL FIX
Previously duplicated in options 10, 11, 12 - now centralized in `select_services()` function.

**IMPORTANT BUG FIX**: The function was printing error messages and prompts to stdout, which were being captured by `SELECTED_SERVICES=$(select_services ...)`. This caused ALL services to be restarted/stopped instead of just the selected ones.

**Solution**: All non-result output redirected to stderr using `>&2`:
- Service list display: `echo "..." >&2`
- Error messages: `echo "..." >&2`
- Prompts: Already go to stderr via `read -rp`
- Only the final service names go to stdout: `echo "$RESULT" | xargs`

This function now correctly handles:
- Comma-separated input
- Mixed numeric/name input
- **Exact name matching** (not regex) to prevent selecting wrong services
- Validation against available services (empty input, non-existent services)
- Error messaging for invalid selections (to stderr)
- Returns error code if no valid services selected

### Multi-Project Toggle UI
User chose interactive toggle mode over comma-separated input. Implementation uses:
- Clear screen + redraw on each action for visual feedback
- Array membership check using `[[ " ${ARRAY[*]} " =~ " $ELEMENT " ]]` pattern
- Array element removal by rebuilding array without target element

### Batch Execution Model
User chose sequential execution over parallel. Implementation:
- Loop through projects one by one
- Capture exit codes individually
- Display progress with per-project output
- Summary table at end with success/failure counts

### Docker Compose V2
Script requires `docker compose` (V2, integrated) NOT `docker-compose` (V1, standalone). Validated at startup (lines 18-23).

## Testing the Script

Since this is an interactive script:

**Manual testing approach**:
1. Create test docker-compose.yml files in HOME subdirectories
2. Run script: `./docker-manager.sh`
3. Test each menu option with various project states
4. Verify color output and error handling

**Key test scenarios**:
- No projects found
- Projects without services
- Services defined but not built
- Mixed states (some running, some stopped)
- Multiple projects selection/deselection
- Batch operations with intentional failures

## Modifying the Script

**Adding menu options**:
1. Add option display (lines 620-640)
2. Add case handler (lines 646-1100)
3. Implement function in appropriate section
4. Update CLAUDE.md with new line ranges

**Adding batch operations**:
1. Add option in `multiproject_menu()` (lines 840-846)
2. Add case handler calling `batch_operation()` with appropriate flags
3. Add confirmation if destructive

**Changing cache TTL**:
Modify `CACHE_TTL=30` (line 40) to desired seconds

**Modifying port URL generation**:
Edit `generate_service_url()` (lines 180-233) case statements

## Code Conventions

**Error Handling**: Uses `set -euo pipefail` for strict mode. Functions return 1 on error, 0 on success.

**Color Variables**: Defined globally (lines 9-15), used consistently throughout for visual feedback.

**Array Operations**: Uses `mapfile -t` for populating arrays from command output.

**User Input**: All reads use `-r` flag, most have colored prompts with emojis.

**Clear Sections**: Functions grouped by purpose with header comments (`# ========= SECTION =========`).

## Performance Considerations

**Batch operations** are intentionally sequential (user preference). For 5 projects doing `docker compose up -d`, expect 20-30 seconds total.

**Project discovery** (`find ~ -name "docker-compose.yml"`) can be slow on large HOME directories. Consider adding exclusion patterns if needed.

## Recent Changes

### Bug Fixes
1. **Options 10 & 11 fixed** - `select_services()` was contaminating output with error messages causing all services to be selected. Fixed by redirecting all non-result output to stderr.
2. **Log viewer simplified** - Removed complex submenu. Now: select service → view 100 lines → press ENTER to continue. Simple and clean.
3. **Dashboard removed** - User found no value, removed to reduce complexity (-97 lines)

## Critical Files

- **docker-manager.sh** - Main script file (~873 lines)
- **README.md** - User documentation with examples
- **CLAUDE.md** - This file, developer/AI guidance
