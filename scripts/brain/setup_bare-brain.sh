#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# SCRIPT NAME:    setup_bare-brain.sh
# VERSION:        5.0.1-Vault-Integrated (Patched)
# DESCRIPTION:    Installs Brain v5 with dynamic secret fetching capabilities.
# ==============================================================================

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

WORKSPACE_DIR="$HOME/.bare-ai"
BIN_DIR="$WORKSPACE_DIR/bin"
LOG_DIR="$WORKSPACE_DIR/logs"
CONFIG_DIR="$WORKSPACE_DIR/config"
FLEET_FILE="$WORKSPACE_DIR/fleet.conf"
CONSTITUTION_SRC="constitution.md" 
BASHRC_FILE="$HOME/.bashrc"

echo -e "${GREEN}Installing Bare-AI Brain (v5.0.1)...${NC}"
mkdir -p "$LOG_DIR" "$BIN_DIR" "$CONFIG_DIR"

# --- 0. DEPENDENCY CHECK ---
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Installing jq (required for JSON parsing)...${NC}"
    sudo apt-get update -qq && sudo apt-get install -y -qq jq
fi

if ! command -v npm &> /dev/null; then
    echo -e "${YELLOW}Installing npm and Gemini CLI (Brain Engine)...${NC}"
    sudo apt-get update -qq && sudo apt-get install -y -qq npm
    sudo npm install -g @google/gemini-cli
fi

# --- 1. PURGE DEBRIS ---
rm -f "$WORKSPACE_DIR/brain_constitution.md"

# --- 2. INSTALL CONSTITUTION ---
TARGET_CONST="$WORKSPACE_DIR/constitution.md"
if [ -f "$CONSTITUTION_SRC" ]; then
    cp "$CONSTITUTION_SRC" "$TARGET_CONST"
else
    echo -e "${YELLOW}Warning: Source constitution not found. Using default.${NC}"
fi

# --- 3. COMPILE BRAIN LOGIC (VAULT EDITION) ---
BRAIN_SCRIPT="$BIN_DIR/bare-brain"

cat << 'INNER_EOF' > "$BRAIN_SCRIPT"
#!/bin/bash
set -e

# Config
CONSTITUTION="$HOME/.bare-ai/constitution.md"
FLEET_FILE="$HOME/.bare-ai/fleet.conf"
LOG_FILE="$HOME/.bare-ai/reflex_history.log"
CRED_FILE="$HOME/.bare-ai/config/vault.env"
TARGET_USER="bare-ai"

# --- VAULT AUTHENTICATION FUNCTION ---
fetch_api_key() {
    # 1. Load Credentials (RoleID / SecretID)
    if [ ! -f "$CRED_FILE" ]; then
        echo "❌ Error: Vault credentials not found at $CRED_FILE" >&2
        return 1
    fi
    source "$CRED_FILE"

    # 2. Login to Vault (AppRole) -> Get Token
    VAULT_TOKEN=$(curl -s -k --request POST \
        --data "{\"role_id\":\"$VAULT_ROLE_ID\",\"secret_id\":\"$VAULT_SECRET_ID\"}" \
        "$VAULT_ADDR/v1/auth/approle/login" | jq -r '.auth.client_token')

    if [[ "$VAULT_TOKEN" == "null" || -z "$VAULT_TOKEN" ]]; then
        echo "❌ Error: Failed to authenticate with Vault." >&2
        return 1
    fi

    # 3. Read the Secret -> Get Key
    API_KEY=$(curl -s -k \
        --header "X-Vault-Token: $VAULT_TOKEN" \
        "$VAULT_ADDR/v1/secret/data/bare-ai/brain" | jq -r '.data.data.key')
    
    if [[ "$API_KEY" == "null" || -z "$API_KEY" ]]; then
        echo "❌ Error: Authenticated, but failed to read secret." >&2
        return 1
    fi

    echo "$API_KEY"
}

# --- CIRCUIT BREAKER ---
should_block_reflex() {
    local target=$1
    local time_pattern=$(date +%Y-%m-%d\ %H:)
    local recent=$(grep "$target" "$LOG_FILE" 2>/dev/null | grep "REFLEX" | grep "$time_pattern" | tail -n 1)
    if [[ -n "$recent" ]]; then echo "YES"; else echo "NO"; fi
}

# --- MAIN EXECUTION ---
echo "🧠 Brain v5.0 (Vault-Aware): Scanning Fleet..."

# Fetch Key securely into memory (never saved to disk)
GEMINI_API_KEY=$(fetch_api_key) || { echo "💀 Fatal: Cannot retrieve Neural Engine Key."; exit 1; }
export GEMINI_API_KEY

while IFS= read -r WORKER_HOST || [[ -n "$WORKER_HOST" ]]; do
    [[ "$WORKER_HOST" =~ ^#.*$ ]] && continue
    [[ -z "$WORKER_HOST" ]] && continue
    
    echo -e "\n📡 Targeting: $WORKER_HOST"
    
    # 1. Harvest
    RAW_DATA=$(ssh -q -o ConnectTimeout=5 $TARGET_USER@$WORKER_HOST "bare-summarize" || echo "")
    if [ -z "$RAW_DATA" ]; then echo "❌ Unreachable."; continue; fi

    # 2. Circuit Breaker
    if [[ $(should_block_reflex "$WORKER_HOST") == "YES" ]]; then
        echo "⚠️  Circuit Breaker: Skipping."
        continue
    fi

    # 3. Analyze
    PROMPT="$(cat $CONSTITUTION)
    URGENT TASK: Analyze this telemetry.
    DATA: $RAW_DATA"

    # Call Gemini (Now using the fetched key implicitly via env var)
    RESPONSE=$(gemini -m gemini-2.5-flash-lite "$PROMPT" 2>/dev/null || echo "")

    # Fallback Logic
    if [ -z "$RESPONSE" ]; then
        echo "⚠️  Offline Mode: Engaging Spinal Cord."
        if echo "$RAW_DATA" | grep -q '"rke2_status": "inactive"'; then
            RESPONSE=$'REASON: Spinal Cord detected inactive service.\nCOMMAND: sudo systemctl start rke2-server'
        else
            RESPONSE=$'REASON: Spinal Cord nominal.\nCOMMAND: NONE'
        fi
    fi

    # 4. Reflex Action
    REASON=$(echo "$RESPONSE" | grep "REASON:" | cut -d':' -f2- | xargs)
    FIX_CMD=$(echo "$RESPONSE" | grep "COMMAND:" | cut -d':' -f2- | xargs)

    if [[ "$FIX_CMD" != "NONE" && ! -z "$FIX_CMD" ]]; then
        echo "⚡ REFLEX TRIGGERED: $FIX_CMD"
        ssh -t -q $TARGET_USER@$WORKER_HOST "$FIX_CMD"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] REFLEX | $WORKER_HOST | $REASON | $FIX_CMD" >> "$LOG_FILE"
    else
        echo "🟢 Healthy ($REASON)"
    fi
done < "$FLEET_FILE"
INNER_EOF

chmod +x "$BRAIN_SCRIPT"
echo -e "${GREEN}Brain v5.0.1 Update Complete.${NC}"
