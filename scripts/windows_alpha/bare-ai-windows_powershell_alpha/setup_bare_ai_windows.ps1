# =============================================================================
# SCRIPT: setup_bare_ai_windows.ps1
# VERSION: 2.1.0
# DESCRIPTION: Enterprise Deployment for BARE-AI Autonomous Agent
# AUTHOR: DevOps Engineering / Gemini AI
# =============================================================================
# This script initializes the environment for the BARE-AI Autonomous Agent.
# It performs the following enterprise-grade actions:
# 1. System Audit: Checks for Gemini CLI and required runtimes.
# 2. Workspace Provisioning: Creates .bare-ai, diary, and logs directories.
# 3. Logic Injection: Deploys the 'Constitution' (System Prompt).
# 4. Documentation: Generates a 100+ line README with embedded functions.
# 5. Profile Integration: Detects and prepares the PowerShell profile.
# =============================================================================

# --- Global Configuration ---
$USER_PROFILE   = $env:USERPROFILE
$BARE_AI_DIR    = Join-Path $USER_PROFILE ".bare-ai"
$DIARY_DIR      = Join-Path $BARE_AI_DIR "diary"
$LOGS_DIR       = Join-Path $BARE_AI_DIR "logs"
$CONST_PATH     = Join-Path $BARE_AI_DIR "constitution.md"
$README_PATH    = Join-Path $BARE_AI_DIR "README.md"
$GEMINI_CLI_CMD = "gemini"

# -----------------------------------------------------------------------------
# FUNCTION: Write-EnterpriseLog
# Provides standardized, timestamped, and colored output for audit trails.
# -----------------------------------------------------------------------------
function Write-EnterpriseLog {
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [Parameter(Mandatory=$true)][ValidateSet("Green", "Yellow", "Red", "Cyan", "Gray")]$Status
    )
    $colors = @{ "Green"="Green"; "Yellow"="Yellow"; "Red"="Red"; "Cyan"="Cyan"; "Gray"="Gray" }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $originalColor = $Host.UI.RawUI.ForegroundColor
   
    $Host.UI.RawUI.ForegroundColor = $colors[$Status]
    Write-Host "[$timestamp] [$Status] $Message"
    $Host.UI.RawUI.ForegroundColor = $originalColor
}

# -----------------------------------------------------------------------------
# STEP 1: PRE-FLIGHT SYSTEM AUDIT
# -----------------------------------------------------------------------------
Write-EnterpriseLog -Message "Starting BARE-AI Pre-flight Audit..." -Status Cyan

$cliCommand = Get-Command $GEMINI_CLI_CMD -ErrorAction SilentlyContinue

if (-not $cliCommand) {
    Write-EnterpriseLog -Message "CRITICAL: Gemini CLI Core not detected." -Status Red
    Write-EnterpriseLog -Message "Please ensure one of the following is installed:" -Status Yellow
    Write-EnterpriseLog -Message "  - Python Vector: pip install google-generativeai" -Status Gray
    Write-EnterpriseLog -Message "  - Node Vector: npm install -g @google/gemini-cli" -Status Gray
    Write-EnterpriseLog -Message "Action: Install dependency and restart PowerShell session." -Status Red
    exit 1
} else {
    Write-EnterpriseLog -Message "Gemini CLI Binary verified at: $($cliCommand.Source)" -Status Green
}

# -----------------------------------------------------------------------------
# STEP 2: INFRASTRUCTURE PROVISIONING
# -----------------------------------------------------------------------------
Write-EnterpriseLog -Message "Provisioning BARE-AI Workspace..." -Status Cyan

$infrastructurePaths = @($BARE_AI_DIR, $DIARY_DIR, $LOGS_DIR)

foreach ($path in $infrastructurePaths) {
    if (-not (Test-Path $path)) {
        try {
            New-Item -ItemType Directory -Force -Path $path | Out-Null
            Write-EnterpriseLog -Message "Successfully provisioned path: $path" -Status Green
        } catch {
            Write-EnterpriseLog -Message "FAILED to provision path: $path. Error: $($_.Exception.Message)" -Status Red
            exit 1
        }
    } else {
        Write-EnterpriseLog -Message "Path exists: $path" -Status Gray
    }
}

# -----------------------------------------------------------------------------
# STEP 3: CONSTITUTION (SYSTEM PROMPT) DEPLOYMENT
# -----------------------------------------------------------------------------
Write-EnterpriseLog -Message "Injecting Agent Constitution..." -Status Cyan

$constitutionContent = @"
# BARE-AI AGENT CONSTITUTION
# VERSION: 1.0.0
# UPDATED: $(Get-Date -Format "yyyy-MM-dd")

MISSION: You are an autonomous Linux Agent for "Self-Healing" pipelines.
﻿# BARE-AI OPERATING DIRECTIVES
- SYSTEM: Windows 11 / PowerShell 7+
- ROLE: Autonomous Windows Systems Engineer.
- COMMANDS: Use ONLY Windows PowerShell commands (Get-CimInstance, Test-NetConnection, etc.). 
- FORMATTING: You must output executable PowerShell code inside blocks labeled ```powershell.
- DIRECTIVE: Do not use 'sudo', 'apt-get', or 'traceroute'. Use 'pathping' or 'tracert' instead.
- ERROR RECOVERY: If a command fails, analyze the error and try a different PowerShell approach.
- WEATHER/OUTSIDE DATA: You HAVE internet access. Use `Invoke-RestMethod -Uri "https://wttr.in/London?format=3"` to get weather.
- OTHER EXAMPLES
- CPU TEMP: Use `Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature`.
- HARD DRIVE: To find biggest files, use `Get-ChildItem -Path C:\ -File -Recurse -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 5`.
"@

try {
    $constitutionContent | Set-Content -Path $CONST_PATH -Encoding UTF8 -Force
    Write-EnterpriseLog -Message "Constitution successfully deployed to $CONST_PATH" -Status Green
} catch {
    Write-EnterpriseLog -Message "CRITICAL ERROR: Failed to write constitution: $($_.Exception.Message)" -Status Red
}

# -----------------------------------------------------------------------------
# STEP 4: DOCUMENTATION GENERATION (README.MD)
# -----------------------------------------------------------------------------
Write-EnterpriseLog -Message "Generating Enterprise Documentation (README.md)..." -Status Cyan

# NOTE: The closing " @ below MUST be flush with the left margin (Column 0).
$readmeContent = @"
# BARE-AI ENTERPRISE CONFIGURATION

This workspace manages the local state, rulesets, and memory for the BARE-AI Agent.

## DIRECTORY STRUCTURE OVERVIEW
- **ROOT**: `$BARE_AI_DIR`
- **CONSTITUTION**: `constitution.md` (Defines Agent Logic/Personality)
- **DIARY**: `diary\` (Daily session logs in Markdown format)
- **LOGS**: `logs\` (Raw execution transcripts)

## AGENT ACTIVATION INSTRUCTIONS

To initialize the agent within your PowerShell environment, follow these steps:

1.  **API Authentication**:
    Obtain your key from Google AI Studio and add it to your profile:
    ```powershel