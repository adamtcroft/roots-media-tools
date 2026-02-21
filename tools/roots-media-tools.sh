#!/bin/bash

# roots-media-tools.sh : this runs an LLM instance in hopes to build media editing tools for Roots Church
# over time
#

TASKS_FILE="/home/acroft/GitHub/roots-media-tools/docs/Tasks.md"

if [ ! -s "${TASKS_FILE}" ]; then
	exit 0
fi

codex exec --dangerously-bypass-approvals-and-sandbox -C "/home/acroft/GitHub/roots-media-tools" "Read and follow the instructions outlined in AGENTS.md"
cd /home/acroft/GitHub/roots-media-tools
git add -A
git commit -m "Nightly update"
git push
