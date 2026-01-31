#!/usr/bin/env bash
set -euo pipefail

# --- IDENTITY & VERSIONING ---
VERSION="v003-brain-enterprise"
AGENT_ROLE="Worker"

# Check if running in a container. Warn if not, as per security recommendations.
if [ ! -f "/.dockerenv" ]; then
    echo -e "\033[1;33mWarning: Running on host system. For enhanced security and enterprise showcases, Bare-ERP recommends running within a containerized environment like Docker.\033[0m"
fi

# This script sets up the BARE-AI BRAIN environment.

# Define colors for output
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

echo -e "${GREEN}Starting BARE-AI (Brain Edition) setup...${NC}"

# --- Gemini CLI Check and Installation ---
if ! command -v gemini &> /dev/null; then
    echo -e "${RED}Gemini CLI not found.${NC}"
    echo -e "${YELLOW}Attempting to install Gemini CLI via npm...${NC}"

    if command -v npm &> /dev/null; then
        echo -e "${YELLOW}Found npm. Attempting to install '@google/gemini-cli' globally with sudo...${NC}"
        # We define execute_command later, but for this early check we use a direct call if needed or move function up.
        # Ideally, helper functions should be defined before use. Moving Helper Functions UP.
    else
        echo -e "${RED}npm not found. Cannot automatically install Gemini CLI.${NC}"
        echo -e "${YELLOW}Please install Node.js and npm, then manually install the Gemini CLI: npm install -g @google/gemini-cli${NC}"
        exit 1
    fi
fi

WORKSPACE_DIR="$HOME/.bare-ai"
BRAIN_DIR="$WORKSPACE_DIR/brain"

# --- Helper Functions (Moved to Top for Scope) ---

# Function to execute commands with user confirmation (Human-in-the-Loop)
execute_command() {
    local cmd="$1"
    local description="$2"
    
    echo -e "\n${YELLOW}Proposed Action:${NC}"
    echo -e "  Description: $description"
    echo -e "  Command: $cmd"
    
    read -p "Execute this command? (y/N): " -n 1 -r
    echo # Move to a new line after user input
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Executing: $cmd${NC}"
        # Execute the command
        local exit_code=0
        eval "$cmd" || exit_code=$?
        
        local log_file="$WORKSPACE_DIR/logs/$(date +'%Y%m%d_%H%M%S')_brain.log"
        local status="failed"
        if [ $exit_code -eq 0 ]; then
            status="success"
        fi
        
        # Construct JSON log entry
        # Ensure logs directory exists before writing, though main script creates it.
        mkdir -p "$WORKSPACE_DIR/logs"
        local json_log_entry=$(printf '{ "timestamp": "%s", "role": "%s", "command": "%s", "description": "%s", "status": "%s", "exit_code": %d }' "$(date +'%Y-%m-%dT%H:%M:%S.%3N%z')" "$AGENT_ROLE" "$(echo "$cmd" | sed 's/"/\\"/g')" "$(echo "$description" | sed 's/"/\\"/g')" "$status" $exit_code)
        
        # Write JSON log to file
        echo "$json_log_entry" > "$log_file"
        
        if [ $exit_code -ne 0 ]; then
            echo -e "${RED}Error executing command: $cmd${NC}"
            # Depending on context, you might want to exit or return an error code
        fi
        return $exit_code
    else
        echo -e "${YELLOW}Skipping command: $cmd${NC}"
        mkdir -p "$WORKSPACE_DIR/logs"
        local log_file="$WORKSPACE_DIR/logs/$(date +'%Y%m%d_%H%M%S')_brain_skip.log"
        local json_log_entry=$(printf '{ "timestamp": "%s", "role": "%s", "command": "%s", "description": "%s", "status": "%s", "exit_code": null }' "$(date +'%Y-%m-%dT%H:%M:%S.%3N%z')" "$AGENT_ROLE" "$(echo "$cmd" | sed 's/"/\\"/g')" "$(echo "$description" | sed 's/"/\\"/g')" "skipped")
        echo "$json_log_entry" > "$log_file"
        return 0
    fi
}

# --- Gem Install (Now that function is defined) ---
if ! command -v gemini &> /dev/null; then
    if execute_command "sudo npm install -g @google/gemini-cli" "Install Gemini CLI globally using npm"; then
        echo -e "${GREEN}Successfully installed Gemini CLI via npm.${NC}"
    else
        echo -e "${RED}Failed to install Gemini CLI via npm.${NC}"
        exit 1
    fi
fi

# --- BRAIN CONFIGURATION ---
# Generate a unique AGENT_ID for this installation.
AGENT_ID=$(cat /proc/sys/kernel/random/uuid)

# --- Create Directory Structure ---
BARE_AI_DIR="$WORKSPACE_DIR"

echo -e "${YELLOW}Creating BARE-AI Brain configuration directory: $BARE_AI_DIR...${NC}"
# Use execute_command for critical directory creation. Added Brain-specific dirs.
execute_command "mkdir -p \"$BARE_AI_DIR/diary\" \"$BARE_AI_DIR/logs\" \"$BARE_AI_DIR/brain/context\" \"$BARE_AI_DIR/brain/archive\"" "Create BARE-AI Brain directory hierarchy"

# Check if directories were created successfully
if [ ! -d "$BARE_AI_DIR/brain" ]; then
    echo -e "${RED}Error: Failed to create BARE-AI Brain directories. Exiting.${NC}"
    exit 1
fi
echo -e "${GREEN}BARE-AI Brain directories created.${NC}"

CONFIG_FILE="$BARE_AI_DIR/config"
execute_command "echo \"AGENT_ID=$AGENT_ID\" >> \"$CONFIG_FILE\"" "Generate and save unique AGENT_ID to config file"
execute_command "touch \"$BARE_AI_DIR/brain/fleet.conf\"" "Initialize fleet.conf for Tailscale tracking"


# --- Create brain_constitution.md (v003 Upgrade) ---
# NOTE: This replaces the standard constitution with a Supervisor-specific one.
CONSTITUTION_CONTENT="# MISSION
You are the **Bare-Brain**, the central orchestrator for a distributed fleet of autonomous specialists (Vault, RKE, Tailscale).
Your goal is to aggregate 'Lessons Learned', synthesize global optimizations, and resolve conflicts between agents.

# OPERATIONAL RULES
1. **Aggregated Input:** You process JSON summaries from workers, not raw text. Do not hallucinate data that isn't in the JSON.
2. **Conflict Resolution:** If Worker-A (e.g., Vault) and Worker-B (e.g., RKE) report conflicting states, prioritize the node with the 'Production' tag or the most recent timestamp.
3. **Pattern Recognition:** Look for errors appearing on >20% of the fleet. If found, propose a Global Operational Rule.
4. **Bandwidth Efficiency:** Do not request full logs unless a summary indicates a 'CRITICAL' failure.
5. **Security (JIT):** Do not recommend 'sudo' commands for remote workers unless two previous self-correction attempts have failed.

# SUPERVISOR ACTIONS
- **Synthesize:** Combine lessons from multiple workers into a single 'Daily Fleet Report'.
- **Audit:** Identify logic errors or hallucinations in worker summaries.
- **Direct:** Output specific instructions for specific workers if optimization is needed."

echo -e "${YELLOW}Creating $BARE_AI_DIR/brain_constitution.md...${NC}"
execute_command "echo -e \"$CONSTITUTION_CONTENT\" > \"$BARE_AI_DIR/brain_constitution.md\"" "Create brain_constitution.md"

# Check if constitution.md was created successfully
if [ ! -f "$BARE_AI_DIR/brain_constitution.md" ]; then
    echo -e "${RED}Error: Failed to create brain_constitution.md. Exiting.${NC}"
    exit 1
fi
echo -e "${GREEN}Brain Constitution file created.${NC}"


# --- Create README.md ---
# Update README to include Brain instructions
README_CONTENT=$(cat << 'EOF'
# BARE-AI Brain Setup (v003)

This directory (`$BARE_AI_DIR`) stores the persistent configuration for the Central Brain.

## Directory Structure

- **`$BARE_AI_DIR/`**: Root directory.
    - **`brain/`**: Brain-specific storage.
        - **`fleet.conf`**: List of Tailscale hostnames to harvest data from.
        - **`context/`**: Staging area for incoming worker JSON summaries.
    - **`brain_constitution.md`**: The supervisor's mission rules.
    - **`diary/`**: Daily Brain-level synthesis reports.
    - **`logs/`**: JSON audit logs of all orchestration commands.

## Setup Instructions

1. **Populate Fleet:** Add your worker hostnames to `~/.bare-ai/brain/fleet.conf`. One per line.
   Example:
   vault-manager rke-node-01 tailscale-exit


2. **API Key:** Ensure `GEMINI_API_KEY` is set in your `.bashrc`.

3. **Orchestrate:** Run `bare-brain` to harvest and synthesize data.
EOF
)

echo -e "${YELLOW}Creating $BARE_AI_DIR/README.md...${NC}"
execute_command "echo -e \"$README_CONTENT\" > \"$BARE_AI_DIR/README.md\"" "Create README.md"


# --- OpenTelemetry Integration ---
DEMO_TELEMETRY_URL="www.bare-erp.com"
execute_command "curl -s -o /dev/null -w '%{http_code}' \"$DEMO_TELEMETRY_URL\"" "Ping demo telemetry endpoint (Brain Heartbeat)"


# --- Modify .bashrc (v003 Logic Injection) ---
# We inject the `bare-brain` supervisor function AND the `bare-summarize` worker function
# so this machine can act as both Brain and a Worker if needed (self-monitoring).

BASHRC_FUNCTION_DEF=$(cat << 'EOF'
# --- BARE-AI v003: The Brain & Worker Suite ---

# 1. The Central Brain Orchestrator
bare-brain() {
 local TODAY=$(date +%Y-%m-%d)
 local BRAIN_DIR="$HOME/.bare-ai/brain"
 local CONSTITUTION="$HOME/.bare-ai/brain_constitution.md"
 local FLEET_CONF="$BRAIN_DIR/fleet.conf"
 local CONTEXT_DIR="$BRAIN_DIR/context"
 
 # Safety Check: Constitution
 if [ ! -f "$CONSTITUTION" ]; then
     echo "Error: Brain constitution not found."
     return 1
 fi

 # Phase 1: HARVEST (Pull-based Intelligence Gathering)
 echo -e "\033[0;36m🧠 Brain: Initiating Intelligence Harvest via Tailscale...\033[0m"
 
 if [[ ! -s "$FLEET_CONF" ]]; then
     echo "⚠️  Fleet configuration empty. Add Tailscale hostnames to $FLEET_CONF"
 else
     while IFS= read -r host || [[ -n "$host" ]]; do
         # Skip comments or empty lines
         [[ "$host" =~ ^#.*$ ]] && continue
         [[ -z "$host" ]] && continue
         
         echo -e "📡 Querying \033[1m$host\033[0m..."
         
         # A. Remote Summarization (Intermediate Aggregation)
         # We assume the worker has 'bare-summarize' installed via v003 update.
         ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$host" "bare-summarize" 2>/dev/null || echo "⚠️  $host unreachable or function missing"
         
         # B. Pull JSON Summary
         scp -q "$host:~/.bare-ai/diary/summary_$TODAY.json" "$CONTEXT_DIR/$host.json" 2>/dev/null
     done < "$FLEET_CONF"
 fi

 # Phase 2: SYNTHESIS (Global Pattern Recognition)
 local AGGREGATED_INTEL=$(cat "$CONTEXT_DIR"/*.json 2>/dev/null || echo "No intelligence gathered today.")
 local MISSION=$(cat "$CONSTITUTION")
 
 echo -e "\033[0;32m🧠 Brain: Synthesizing Global Strategy...\033[0m"
 
 # Pass Context + Mission to Gemini 2.0 Flash (High Reasoning)
 echo -e "### FLEET INTELLIGENCE ###\n$AGGREGATED_INTEL\n\n### YOUR MISSION ###\n$MISSION" | \
 gemini -m gemini-2.0-flash -i "Review fleet health, resolve conflicts, and provide the Daily Global Strategy."
}

# 2. The Worker Summarizer (Intermediate Aggregation Tool)
# This generates high-density JSON for the Brain to consume.
bare-summarize() {
 local TODAY=$(date +%Y-%m-%d)
 local DIARY="$HOME/.bare-ai/diary/$TODAY.md"
 local OUT="$HOME/.bare-ai/diary/summary_$TODAY.json"
 
 # Ensure diary dir exists
 mkdir -p "$(dirname "$DIARY")"

 if [[ -f "$DIARY" ]]; then
     # Use Flash-Lite for cheap, fast summarization at the edge
     cat "$DIARY" | gemini -m gemini-2.5-flash-lite -p \
     "Summarize this diary into a JSON object with keys: {node: '$(hostname)', status: 'OK|FAIL', critical_errors: [], learnings: []}. Output raw JSON only." > "$OUT"
     echo "Summary generated: $OUT"
 else
     # Generate an empty status if no diary exists
     echo "{\"node\": \"$(hostname)\", \"status\": \"NO_DATA\", \"learnings\": []}" > "$OUT"
 fi
}

# 3. Fleet Enrollment Helper (Deploy v003 to workers)
bare-enroll() {
 local target=$1
 if [ -z "$target" ]; then
     echo "Usage: bare-enroll <tailscale-hostname>"
     return 1
 fi
 echo "🚀 Enrolling $target into the Bare-AI Mesh..."
 scp "$HOME/setup_bare_ai.sh" "$target:/tmp/setup.sh"
 ssh "$target" "bash /tmp/setup.sh"
}
EOF
)

# Add prompt color settings if not already present (Preserved from v002)
BASHRC_COLOR_SETTINGS=$(cat << 'EOF'
# enable color support of ls and some other commands
if [ -x /usr/bin/dircolors ]; then
 test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi
# enable bash completion in interactive shells
if ! shopt -oq posix; then
 if [ -f /usr/share/bash-completion/bash_completion ]; then
     . /usr/share/bash-completion/bash_completion
 elif [ -f /etc/bash_completion ]; then
     . /etc/bash_completion
 fi
fi
# set a fancy prompt
color_prompt=yes
force_color_prompt=yes
EOF
)

BASHRC_FILE="$HOME/.bashrc"

echo -e "${YELLOW}Modifying $BASHRC_FILE...${NC}"

# --- Handle Terminal Colors ---
if ! grep -q "color_prompt=yes" "$BASHRC_FILE" || ! grep -q "force_color_prompt=yes" "$BASHRC_FILE"; then
 echo -e "${YELLOW}Adding terminal color prompt settings to $BASHRC_FILE...${NC}"
 execute_command "echo -e \"\n$BASHRC_COLOR_SETTINGS\" >> \"$BASHRC_FILE\"" "Add terminal color prompt settings to $BASHRC_FILE"
else
 echo -e "${YELLOW}Terminal color prompt settings already exist in $BASHRC_FILE. Skipping.${NC}"
fi

# --- Handle Gemini CLI Function ---
if grep -q "^# --- BARE-AI v003: The Brain & Worker Suite ---" "$BASHRC_FILE"; then
 echo -e "${YELLOW}BARE-AI v003 functions already found in $BASHRC_FILE. Skipping addition.${NC}"
else
 # Append the function to .bashrc
 execute_command "echo -e \"\n$BASHRC_FUNCTION_DEF\n\" >> \"$BASHRC_FILE\"" "Append BARE-AI v003 functions to .bashrc"
 
 if [ ! $? -eq 0 ]; then
     echo -e "${RED}Error: Failed to append BARE-AI function to $BASHRC_FILE. Exiting.${NC}"
     exit 1
 fi
 echo -e "${YELLOW}BARE-AI v003 functions added to $BASHRC_FILE.${NC}"
 echo -e "${YELLOW}Please run 'source $BASHRC_FILE' to activate 'bare-brain' and 'bare-summarize'.${NC}"
fi

# --- API Key Instruction ---
echo -e "\n${YELLOW}IMPORTANT: Gemini API Key Setup${NC}"
echo -e "${YELLOW}To enable the Gemini CLI to authenticate, you must set your API key as an environment variable.${NC}"
echo -e "${YELLOW}Add the following line to your '$BASHRC_FILE', replacing 'YOUR_GEMINI_API_KEY' with your actual key:${NC}"
echo -e "${YELLOW}export GEMINI_API_KEY=\"YOUR_GEMINI_API_KEY\"${NC}"
echo -e "${YELLOW}After adding this line, run 'source $BASHRC_FILE' in your terminal session.${NC}"

echo -e "\n${GREEN}BARE-AI Brain (v003) setup script finished.${NC}"
echo -e "${GREEN}System is ready for Fleet Orchestration.${NC}"
exit 0