#!/bin/bash
# state-switch.sh — switch active project state
# Usage: bash /path/to/state-switch.sh <project-name>
#
# Switches the active Working State project:
#   1. Saves current project.yaml → projects/<current-name>.yaml (overwrite)
#   2. Loads target project snapshot → active/project.yaml
#   3. Resets task.yaml for new project context
#   4. Appends StateSwitch event to project event log
#
# Project snapshots stored under ~/.hermes/state/projects/<name>.yaml
# global.yaml is NEVER modified by this script.

set -e

STATE_DIR="$HOME/.hermes/state"
PROJECTS_DIR="$STATE_DIR/projects"
ACTIVE_DIR="$STATE_DIR/active"
EVENTS_DIR="$STATE_DIR/events"

name="$1"

if [ -z "$name" ]; then
    echo "Usage: state-switch <project-name>"
    echo ""
    echo "Available projects:"
    ls "$PROJECTS_DIR"/*.yaml 2>/dev/null | sed 's|.*/||; s|\.yaml$||'
    exit 1
fi

src="$PROJECTS_DIR/$name.yaml"

if [ ! -f "$src" ]; then
    echo "Error: project '$name' not found in $PROJECTS_DIR"
    echo "Available:"
    ls "$PROJECTS_DIR"/*.yaml 2>/dev/null | sed 's|.*/||; s|\.yaml$||'
    exit 1
fi

# Save current project as snapshot
backup_name=""
if [ -f "$ACTIVE_DIR/project.yaml" ]; then
    raw_name=$(grep '^project:' "$ACTIVE_DIR/project.yaml" | head -1 | sed 's/^project: *"//; s/"$//')
    if [ -n "$raw_name" ]; then
        backup_name=$(echo "$raw_name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
        cp "$ACTIVE_DIR/project.yaml" "$PROJECTS_DIR/${backup_name}.yaml"
        echo "Snapshot saved: $backup_name"
    fi
fi

# Switch — load target snapshot into active
cp "$src" "$ACTIVE_DIR/project.yaml"
echo "Switched to project: $name"

# Reset task for new project context
cat > "$ACTIVE_DIR/task.yaml" << TASKEOF
# Task Working State
# Switched by state-switch at $(date -u +"%Y-%m-%dT%H:%M:%SZ")

schema_version: 1
updated_at: "$(date +"%Y-%m-%dT%H:%M:%S%z")"

current_task: "New session — project switched to $name"
current_blocker: null
completed_this_session: []
next_actions:
  - "Review project state and continue"
open_questions: []
TASKEOF

# Log the switch to the target project's event log
ts=$(date +"%Y-%m-%dT%H:%M:%S%z")
from="${backup_name:-unknown}"
mkdir -p "$EVENTS_DIR"
echo "${ts} | StateSwitch | ${from} → ${name}" >> "$EVENTS_DIR/${name}.log"
echo "${ts} | StateSwitch | ${from} → ${name}" >> "$EVENTS_DIR/global.log"

echo ""
echo "Active project: $name"
head -5 "$ACTIVE_DIR/project.yaml"