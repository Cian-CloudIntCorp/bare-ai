# 1. Enter the correct directory
cd ~/Bare-ai/scripts/worker

# 2. Write the FINAL, FIXED, FULL script
cat > setup_bare-ai-worker.sh << 'EOF'
#!/usr/bin/env bash
############################################################
#    ____ _                  _ _       _          ____     #
#   / ___| | ___  _    _  ___| (_)_ __ | |_      / ___|___   #
#  | |   | |/ _ \| | | |/ __| | | '_ \| __|     | |   / _ \  #
#  | |___| | (_) | |_| | (__| | | | | | |_      | |__| (_) | #
#   \____|_|\___/ \__,_|\___|_|_|_| |_|\__|      \____\___/  #
#                                                          #
#   by the Cloud Integration Corporation                   #
############################################################
# ==============================================================================
# SCRIPT NAME:    setup_bare-ai-worker.sh
# DESCRIPTION:    bare-ai-worker "Apex" Installer (Level 4 Autonomy)
# AUTHOR:         Cian Egan
# DATE:           2026-02-01
# VERSION:        4.5.0-Enterprise (MagicDNS + Artifacts Fixed)
# ==============================================================================
set -euo pipefail

# Check if running in a container. Warn if not, as per security recommendations.
if [ ! -f "/.dockerenv" ]; then
    echo -e "\033[1;33mWarning: Running on host system. For enhanced security and enterprise showcases, Bare-ERP recommends running within a containerized environment like Docker.\033[0m"
fi

# This script sets up the BARE-AI environment.

# Define colors for output
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

echo -e "${GREEN}Starting BARE-AI setup...${NC}"

# Define Directories
WORKSPACE_DIR="$HOME/.bare-ai"
BARE_AI_DIR="$WORKSPACE_DIR"
BIN_DIR="$BARE_AI_DIR/bin"
LOG_DIR="$BARE_AI_DIR/logs"
DIARY_DIR="$BARE_AI_DIR/diary"
CONFIG_FILE="$BARE_AI_DIR/config"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Helper Functions ---

# Function to execute commands with user confirmation (Human-in-the-Loop)
execute_command() {
    local cmd="$1"
    local description="$2"
    
    echo -e "\n${YELLOW}Proposed Action:${NC}"
    echo -e "  Description: $description"
    echo -e "  Command: $cmd"
    
    mkdir -p "$LOG_DIR"
    read -p "Execute this command? (y/N): " -n 1 -r
    echo # Move to a new line after user input
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Executing: $cmd${NC}"
        
        # Execute the command
        local exit_code=0
        eval "$cmd" || exit_code=$?

        local log_file="$LOG_DIR/$(date +'%Y%m%d_%H%M%S')_$(date +%N | cut -c1-3).log"
        local status="failed"
        if [ $exit_code -eq 0 ]; then
            status="success"
        fi
        
        # Construct JSON log entry
        local json_log_entry=$(printf '{ "timestamp": "%s", "command": "%s", "description": "%s", "status": "%s", "exit_code": %d }' "$(date +'%Y-%m-%dT%H:%M:%S.%3N%z')" "$(echo "$cmd" | sed 's/"/\\"/g')" "$(echo "$description" | sed 's/"/\\"/g')" "$status" $exit_code)
        
        # Write JSON log to file
        echo "$json_log_entry" > "$log_file"
        
        if [ $exit_code -ne 0 ]; then
            echo -e "${RED}Error executing command: $cmd${NC}"
            # Depending on context, you might want to exit or return an error code
        fi
    else
        echo -e "${YELLOW}Skipping command: $cmd${NC}"
        # Log skipped commands as well
        local log_file="$LOG_DIR/$(date +'%Y%m%d_%H%M%S')_$(date +%N | cut -c1-3).log"
        local json_log_entry=$(printf '{ "timestamp": "%s", "command": "%s", "description": "%s", "status": "%s", "exit_code": null }' "$(date +'%Y-%m-%dT%H:%M:%S.%3N%z')" "$(echo "$cmd" | sed 's/"/\\"/g')" "$(echo "$description" | sed 's/"/\\"/g')" "skipped")
        echo "$json_log_entry" > "$log_file"
    fi
}

# --- Create Directory Structure ---
echo -e "${YELLOW}Creating BARE-AI configuration directory: $BARE_AI_DIR...${NC}"
# Use execute_command for critical directory creation (Added BIN_DIR)
execute_command "mkdir -p \"$DIARY_DIR\" \"$LOG_DIR\" \"$BIN_DIR\"" "Create BARE-AI diary, logs, and bin directories"

# Check if directories were created successfully
if [ ! -d "$BARE_AI_DIR" ] || [ ! -d "$DIARY_DIR" ] || [ ! -d "$LOG_DIR" ] || [ ! -d "$BIN_DIR" ]; then
    echo -e "${RED}Error: Failed to create BARE-AI directories. Exiting.${NC}"
    exit 1
fi
echo -e "${GREEN}BARE-AI directories created.${NC}"

# --- ARTIFACT INSTALLATION (THE MISSING LINK) ---
# This is the critical fix. It installs the tool we built so the Brain can see this node.
if [ -f "$SOURCE_DIR/bare-summarize" ]; then
    echo -e "${YELLOW}Installing Telemetry Harvester (bare-summarize)...${NC}"
    execute_command "cp \"$SOURCE_DIR/bare-summarize\" \"$BIN_DIR/bare-summarize\" && chmod +x \"$BIN_DIR/bare-summarize\"" "Install bare-summarize artifact to bin"
else
    echo -e "${RED}CRITICAL WARNING: 'bare-summarize' artifact not found in $SOURCE_DIR! Brain will be blind.${NC}"
fi

# --- Gemini CLI Check and Installation ---
if ! command -v gemini &> /dev/null; then
    echo -e "${RED}Gemini CLI not found.${NC}"
    echo -e "${YELLOW}Attempting to install Gemini CLI via npm...${NC}"

    if command -v npm &> /dev/null; then
        echo -e "${YELLOW}Found npm. Attempting to install '@google/gemini-cli' globally with sudo...${NC}"
        if execute_command "sudo npm install -g @google/gemini-cli" "Install Gemini CLI globally using npm"; then
            echo -e "${GREEN}Successfully installed Gemini CLI via npm.${NC}"
        else
            echo -e "${RED}Failed to install Gemini CLI via npm.${NC}"
            echo -e "${YELLOW}Please ensure you have npm installed and sufficient permissions.${NC}"
        fi
    else
        echo -e "${RED}npm not found. Skipping Gemini install.${NC}"
    fi
fi

# --- AGENT CONFIGURATION ---
# Generate a unique AGENT_ID for this installation.
if [ ! -f "$CONFIG_FILE" ]; then
    AGENT_ID=$(cat /proc/sys/kernel/random/uuid)
    execute_command "echo \"AGENT_ID=$AGENT_ID\" >> \"$CONFIG_FILE\"" "Generate and save unique AGENT_ID to config file"
fi

# --- Create constitution.md ---
# NOTE: {{DATE}} is a placeholder to be replaced by sed when the 'bare' command is run.
CONSTITUTION_CONTENT="# MISSION
You are Bare-AI, an autonomous Linux Agent responsible for \"Self-Healing\" data pipelines.
Your goal is to fix data errors, convert formats, and verify integrity using standard Linux tools.

# OPERATIONAL RULES
1. **Tool First, Think Second:** Do not guess file contents. Use \`head\`, \`file\`, or \`grep\` to inspect them first.
2. **Verification:** Never assume a conversion worked. Always run a check command (e.g., \`jq .\` to verify JSON validity).
3. **Resource Efficiency:** Do not read files larger than 1MB into your context. Use \`split\`, \`awk\`, or \`sed\`.
4. **Self-Correction:** If a command fails, read the error code, formulate a fix, and retry once.
5. **Updates:** Use \`sudo DEBIAN_FRONTEND=noninteractive\` for updates.

# FORBIDDEN ACTIONS
- Do not use \`rm\` on files outside the \`/tmp\` directory.
- Do not Hallucinate library availability. Use \`dpkg -l\` or \`pip list\` to check before importing.

# DIARY RULES
1. Log all learnings, succinct summary of actions, file names to ~/.bare-ai/diary/{{DATE}}.md."

echo -e "${YELLOW}Creating $BARE_AI_DIR/constitution.md...${NC}"
execute_command "echo -e \"$CONSTITUTION_CONTENT\" > \"$BARE_AI_DIR/constitution.md\"" "Create constitution.md"

# --- Create README.md ---
README_CONTENT=$(cat << 'README_EOF'
# BARE-AI Setup and Configuration
This directory (`$BARE_AI_DIR`) stores the persistent configuration and memory for the BARE-AI agent.
## Directory Structure
- **`constitution.md`**: Core identity and rules.
- **`diary/`**: Daily logs.
- **`logs/`**: Session transcripts.
## Gemini CLI and API Key Setup
1. **Gemini CLI:** `npm install -g @google/gemini-cli`
2. **API Key:** `export GEMINI_API_KEY="YOUR_KEY"` in `~/.bashrc`.
README_EOF
)

echo -e "${YELLOW}Creating $BARE_AI_DIR/README.md...${NC}"
execute_command "echo -e \"$README_CONTENT\" > \"$BARE_AI_DIR/README.md\"" "Create README.md"

# --- OpenTelemetry Integration ---
DEMO_TELEMETRY_URL="www.bare-erp.com"
execute_command "curl -s -o /dev/null -w '%{http_code}' \"$DEMO_TELEMETRY_URL\"" "Ping demo telemetry endpoint (Audit)"

# --- Modify .bashrc ---
BASHRC_FILE="$HOME/.bashrc"
echo -e "${YELLOW}Modifying $BASHRC_FILE...${NC}"

# 1. Path Update (Critical for artifacts)
PATH_UPDATE=$(cat << 'INNER_EOF'
# BARE-AI PATH
if [ -d "$HOME/.bare-ai/bin" ] ; then
    PATH="$HOME/.bare-ai/bin:$PATH"
fi
INNER_EOF
)

if ! grep -q "BARE-AI PATH" "$BASHRC_FILE"; then
    execute_command "echo -e \"\n$PATH_UPDATE\" >> \"$BASHRC_FILE\"" "Add BARE-AI bin to PATH"
fi

# 2. Function Definition
BASHRC_FUNCTION_DEF=$(cat << 'INNER_EOF'
# The BARE-AI Loader
bare() {
    local TODAY=$(date +%Y-%m-%d)
    local CONSTITUTION="$HOME/.bare-ai/constitution.md"
    local DIARY="$HOME/.bare-ai/diary/$TODAY.md"
    mkdir -p "$(dirname "$DIARY")"
    touch "$DIARY"
    if [ ! -f "$CONSTITUTION" ]; then
        echo -e "\033[0;31mError: Constitution file not found.\033[0m"
        return 1
    fi
    local content=$(cat "$CONSTITUTION" | sed "s|{{DATE}}|$TODAY|")
    gemini -m gemini-2.5-flash-lite -i "$content"
}
INNER_EOF
)

if ! grep -q "^# The BARE-AI Loader" "$BASHRC_FILE"; then
    execute_command "echo -e \"\n$BASHRC_FUNCTION_DEF\n\" >> \"$BASHRC_FILE\"" "Append BARE-AI loader function to .bashrc"
fi

echo -e "\n${GREEN}BARE-AI setup script finished.${NC}"
echo -e "1. ${YELLOW}Reload:${NC} source ~/.bashrc"
echo -e "2. ${YELLOW}Test:${NC}   bare-summarize"
exit 0
EOF

chmod +x setup_bare-ai-worker.sh