# 🏛️ PROJECT BARE: Architectural Handover & Protocol
**Target Audience:** Autonomous Infrastructure Deployment AI & Human Engineers
**Repository:** `http://github.com/Cian-CloudIntCorp/bare-ai`

## 1. The Architectural Paradigm
Project Bare is a Level 4 Autonomous, Sovereign IPv6 Overlay network. It operates on a strict **MAPE-K Loop** (Monitor, Analyze, Plan, Execute, Knowledge). 

To achieve this, the architecture strictly separates the **Control Plane** from the **Data Plane**. 

* **The Brain (Control Plane):** Resides centrally on `bare-dc` (the Proxmox host/management layer). It handles the Analyze and Plan phases using Large Language Models.
* **The Body (Worker VMs):** The templates and active nodes. They handle the Monitor (`bare-summarize`) and Execute (SSH endpoints) phases.

## 2. GitHub Pull Manifest (For VM Templates)
When cloning or pulling from the `bare-ai` repository to construct a VM Template, you must strictly filter the components. 

### ✅ REQUIRED (Pull to VM Template):
* `bare-summarize`: The telemetry sensor. This script harvests local node data and outputs it as structured JSON for the Brain.
* Worker setup scripts.
* Public SSH Keys (`.pub`) required for the Brain to access the worker.

### ❌ FORBIDDEN (Do NOT put on VM Template):
* `bare-brain`: The LLM inference engine. This belongs *only* on the Control Plane.
* `setup_bare-brain.sh`: The Apex installer we use for the Control Plane.
* `constitution.md`: The Brain's rule logic.
* `fleet.conf`: The Brain's targeting list.
* Any private keys (`id_ed25519`), `.env` files, or API keys. 

## 3. Worker Node Security & Configuration Posture
The VM template must be prepared to receive commands from the Brain seamlessly via the "No-Touch" SSH gap. 

1.  **Identity:** Create the standard `bare-ai` user.
2.  **Access Control:** Configure `/etc/ssh/sshd_config` to explicitly whitelist the `bare-ai` user (`AllowUsers bare-ai`).
3.  **The Effector (Permissions):** The `bare-ai` user must be able to execute specific self-healing commands without a password prompt (e.g., `sudo systemctl restart rke2-server`). Configure the `sudoers` file accordingly.

## 4. End-State Goal
When a template is cloned into a live VM, it should boot up silently, connect to the overlay, and wait to be scraped by the centralized `bare-brain` service. It does not think; it only reports and reacts.

### ⚠️ CLARIFICATION: Developer Tools vs. Production Services
Do not confuse the autonomous `bare-brain` service with the human developer CLI tool (`bare` / `gemini-cli`). 
* **FORBIDDEN:** The autonomous `bare-brain` loop script MUST NOT run on worker nodes. 
* **PERMITTED:** The `bare` (Gemini) interactive command-line interface IS PERMITTED on worker nodes for human administrative and debugging purposes.
