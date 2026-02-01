# 🦾 Bare-AI: Autonomous Infrastructure Management
**Version:** 4.5.6-Enterprise (Architect Edition)  
**Author:** Cian Egan  
**Date:** 2026-02-01  

Bare-AI is a multi-node, self-healing architecture designed to manage data pipelines and infrastructure integrity across Linux and Windows environments.

## 🏛️ System Architecture

The fleet follows a strict role-based hierarchy to ensure safety and scalability:

### 1. The Architect (Dev Console)
- **Primary Host:** `penguin` (Chromebook/Debian)
- **Role:** Central Command & Deployment.
- **Key Tools:**
    - `bare`: Local Gemini-powered coding assistant with log-forwarding to a daily diary.
    - `bare-enroll`: The "Deployment Gun" used to push worker logic to remote nodes via SSH/Headscale.
    - `bare-status`: Local telemetry auditing tool.

### 2. The Brain (Coordinator)
- **Primary Host:** `bare-dc` (User: `bare-ai-brain`)
- **Role:** Autonomous fleet monitoring and decision-making.
- **Logic:** Runs high-frequency health checks and executes self-healing protocols.

### 3. The Workers (Fleet Nodes)
- **Hosts:** `bare-rke2`, `bare-dc-headscale`, etc.
- **Role:** Payload execution and telemetry reporting.
- **Core Tool:** `bare-summarize` (Binary artifact for JSON telemetry harvesting).

## 📜 The "Gold Standard" Naming Convention
To ensure enterprise-grade consistency, the repository follows these naming rules:
- **The Box (Installers):** Must have the `.sh` extension (e.g., `setup_bare-ai-worker.sh`).
- **The Product (Tools):** Must have **NO** extension (e.g., `bare-summarize`). This allows the underlying logic to be rewritten (e.g., from Bash to Python) without breaking system calls.

## 🚀 Quick Start: Enrolling a New Worker

From the **Architect Console** (Penguin), run:
```bash
bare-enroll <user@host_or_headscale_ip>
