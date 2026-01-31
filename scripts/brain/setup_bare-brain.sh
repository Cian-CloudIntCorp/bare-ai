cat << 'EOF' > setup_bare-brain.sh
############################################################
#    ____ _                  _ _       _        ____       #
#   / ___| | ___  _    _  ___| (_)_ __ | |_      / ___|___   #
#  | |   | |/ _ \| | | |/ __| | | '_ \| __|     | |   / _ \  #
#  | |___| | (_) | |_| | (__| | | | | | |_      | |__| (_) | #
#   \____|_|\___/ \__,_|\___|_|_|_| |_|\__|      \____\___/  #
#                                                          #
#  by the Cloud Integration Corporation                    #
############################################################
#!/usr/bin/env bash
# ==============================================================================
# SCRIPT NAME:    setup_bare-brain.sh
# DESCRIPTION:    Bare-AI Brain "Apex" Installer (Level 4 Autonomy)
# AUTHOR:         Cian Egan
# DATE:           2026-01-31
# VERSION:        4.3.0-Enterprise (MagicDNS Edition)
#
# PURPOSE:
#   Bootstraps the central "Brain" node for the Bare-AI Autonomous Mesh.
#   It establishes the "Reflex Loop" architecture, allowing this node to:
#     1. Scan a fleet of workers defined in 'fleet.conf' using MagicDNS.
#     2. Harvest telemetry via SSH (bare-summarize).
#     3. Analyze health via Gemini 2.5 Flash Lite (Sub-second inference).
#     4. Execute self-healing commands (systemctl) autonomously.
#
# CHANGE LOG:
#   - v4.3.0: [FIX] Resolved 'set -u' variable expansion crash in heredoc.
#             [NEW] Integrated MagicDNS (Hostnames) for resilient discovery.
#             [SEC] Enforced 'bare-ai-brain' user context isolation.
#   - v4.1.0: Added 'bare-enroll' helper and multi-node Fleet Loop.
#   - v3.5.0: Migrated Network Identity to 'tag:brain' (Headscale ACLs).
#   - v3.0.0: Replaced Chat interface with Deterministic Reflex Engine.
# ==============================================================================

cat << 'EOF' > setup_bare-brain.sh
#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# 1. CONFIGURATION & CONSTANTS
# ==========================================
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

# The script now dynamically detects the user's home
WORKSPACE_DIR="$HOME/.bare-ai"
BARE_AI_DIR="$WORKSPACE_DIR"
BIN_DIR="$BARE_AI_DIR/bin"
LOG_DIR="$BARE_AI_DIR/logs"
FLEET_FILE="$BARE_AI_DIR/fleet.conf"
BASHRC_FILE="$HOME/.bashrc"
TEMP_FILE="$BARE_AI_DIR/temp_install_fragment"

# ==========================================
# 2. HELPER FUNCTIONS
# ==========================================
json_escape() { echo "$1" | sed 's/"/\\"/g'; }

execute_command() {
    local cmd="$1"
    local description="$2"
    echo -e "\n${YELLOW}Proposed Action:${NC}"
    echo -e "  Description: $description"
    echo -e "  Command: $cmd"
    
    mkdir -p "$LOG_DIR"
    read -p "Execute this command? (y/N): " -n 1 -r
    echo 
    
    local timestamp=$(date +'%Y-%m-%dT%H:%M:%S.%3N%z')
    local log_file="$LOG_DIR/$(date +'%Y%m%d_%H%M%S').log"
    local status="skipped"
    local exit_code="null"

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Executing...${NC}"
        set +e 
        eval "$cmd"
        exit_code=$?
        set -e
        if [ $exit_code -eq 0 ]; then
            status="success"
            echo -e "${GREEN}Success.${NC}"
        else
            status="failed"
            echo -e "${RED}Failed (Code: $exit_code).${NC}"
        fi
    else
        echo -e "${YELLOW}Skipped.${NC}"
    fi

    local clean_cmd=$(json_escape "$cmd")
    printf '{ "timestamp": "%s", "command": "%s", "status": "%s", "exit_code": %s }\n' \
        "$timestamp" "$clean_cmd" "$status" "$exit_code" > "$log_file"

    if [[ "$exit_code" != "null" ]]; then return $exit_code; fi
    return 0
}

# ==========================================
# 3. MAIN INSTALLATION
# ==========================================

echo -e "${GREEN}Starting BARE-AI BRAIN (Apex v4.3 MagicDNS) Setup...${NC}"
echo -e "${YELLOW}Installing for User: $USER${NC}"

# --- Directories ---
execute_command "mkdir -p \"$LOG_DIR\" \"$BIN_DIR\"" "Create Brain directories"

# --- Dependencies ---
if ! command -v gemini &> /dev/null; then
    echo -e "${RED}Gemini CLI missing.${NC}"
    if command -v npm &> /dev/null; then
        if sudo -v; then
            execute_command "sudo npm install -g @google/gemini-cli" "Install Gemini CLI"
        fi
    else
        echo -e "${RED}Install Node/npm first.${NC}"
        exit 1
    fi
fi

# --- Fleet Configuration ---
if [ ! -f "$FLEET_FILE" ]; then
    echo -e "${YELLOW}Creating Fleet Configuration...${NC}"
    # FIX: Using MagicDNS Hostname from your logs instead of IP
    echo "bare-rke2-zriwpj7t" > "$FLEET_FILE"
    echo -e "${GREEN}Added default worker (bare-rke2-zriwpj7t) to fleet.conf${NC}"
fi

# --- Identity ---
CONSTITUTION="# MISSION
You are the **Bare-AI Brain** (Apex Reflex).
Your goal is to monitor fleet telemetry and execute autonomous repairs.

# RULES
1. **Reflexive:** If a critical service is 'inactive', you MUST issue a repair command.
2. **Precise:** Use exact systemctl commands.
3. **Silent:** If system is healthy, output 'COMMAND: NONE'."

if [ ! -f "$BARE_AI_DIR/constitution.md" ]; then
    execute_command "echo -e \"$CONSTITUTION\" > \"$BARE_AI_DIR/constitution.md\"" "Create Constitution"
fi

# --- The "Apex" Reflex Script ---
BRAIN_SCRIPT="$BIN_DIR/bare-brain"

echo -e "${YELLOW}Compiling Apex Reflex Logic...${NC}"

cat << 'EOF' > "$BRAIN_SCRIPT"
#!/bin/bash
set -e

# Config
CONSTITUTION="$HOME/.bare-ai/constitution.md"
FLEET_FILE="$HOME/.bare-ai/fleet.conf"
LOG_FILE="$HOME/.bare-ai/reflex_history.log"
TARGET_USER="bare-ai"

echo "🧠 Brain: Scanning Fleet..."

# Loop through every Hostname in fleet.conf
while IFS= read -r WORKER_HOST || [[ -n "$WORKER_HOST" ]]; do
    [[ "$WORKER_HOST" =~ ^#.*$ ]] && continue
    [[ -z "$WORKER_HOST" ]] && continue

    echo -e "\n📡 Targeting: $WORKER_HOST"
    
    # 1. Harvest (Using MagicDNS Hostname)
    RAW_DATA=$(ssh -q -o ConnectTimeout=5 $TARGET_USER@$WORKER_HOST "bare-summarize" || echo "")

    if [ -z "$RAW_DATA" ]; then
        echo "❌ Unreachable or empty response."
        continue
    fi

    # 2. Analyze (Gemini 2.5 Flash Lite)
    PROMPT="$(cat $CONSTITUTION)
    
    URGENT TASK:
    Review this JSON from node $WORKER_HOST.
    1. If 'rke2_status' is 'inactive', output repair command starting with 'COMMAND:'.
       - Server: 'sudo systemctl start rke2-server'
       - Agent: 'sudo systemctl start rke2-agent'
    2. Else output 'COMMAND: NONE'.
    
    DATA: $RAW_DATA"

    RESPONSE=$(gemini -m gemini-2.5-flash-lite "$PROMPT")
    
    # 3. Reflex
    FIX_CMD=$(echo "$RESPONSE" | grep "COMMAND:" | cut -d':' -f2 | xargs)

    if [[ "$FIX_CMD" != "NONE" && ! -z "$FIX_CMD" ]]; then
        echo "⚡ Reflex Triggered!"
        echo "💉 Injecting: '$FIX_CMD'"
        ssh -t -q $TARGET_USER@$WORKER_HOST "$FIX_CMD"
        
        TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
        echo "[$TIMESTAMP] REFLEX | Target: $WORKER_HOST | Fix: $FIX_CMD" >> "$LOG_FILE"
        echo "✅ Repair Sent."
    else
        echo "🟢 Healthy."
    fi
done < "$FLEET_FILE"
EOF

execute_command "chmod +x \"$BRAIN_SCRIPT\"" "Make bare-brain executable"

# --- Path Update ---
cat << 'EOF' > "$TEMP_FILE"
# BARE-AI PATH
if [ -d "$HOME/.bare-ai/bin" ] ; then
    PATH="$HOME/.bare-ai/bin:$PATH"
fi
EOF

if ! grep -q "BARE-AI PATH" "$BASHRC_FILE"; then
    execute_command "cat \"$TEMP_FILE\" >> \"$BASHRC_FILE\"" "Add /bin to PATH"
fi

# --- Enroll Helper (FIXED: Safe Heredoc) ---
cat << 'EOF' > "$TEMP_FILE"
bare-enroll() {
    local target=$1
    if [ -z "$target" ]; then echo "Usage: bare-enroll <hostname>"; return 1; fi
    echo "🚀 Enrolling $target..."
    if [ -f "$HOME/setup_bare_ai.sh" ]; then
        scp "$HOME/setup_bare_ai.sh" "bare-ai@$target:/tmp/setup.sh"
        ssh "bare-ai@$target" "bash /tmp/setup.sh"
    else
        echo "Error: $HOME/setup_bare_ai.sh not found."
    fi
}
EOF

if ! grep -q "bare-enroll" "$BASHRC_FILE"; then
    execute_command "cat \"$TEMP_FILE\" >> \"$BASHRC_FILE\"" "Add bare-enroll helper"
fi

# Cleanup
rm -f "$TEMP_FILE"

echo -e "\n${GREEN}BRAIN UPGRADE COMPLETE (v4.3 MagicDNS).${NC}"
echo -e "1. Edit Fleet:  nano ~/.bare-ai/fleet.conf"
echo -e "2. Activate:    source ~/.bashrc"
echo -e "3. Run:         bare-brain"
exit 0
EOF

chmod +x setup_bare-brain.sh
./setup_bare-brain.sh