# 🔒 Security Policy for Project Bare

## Supported Versions
Project Bare is an actively maintained Sovereign Architecture. Only the latest major release is supported for security updates.

| Version | Supported          |
| ------- | ------------------ |
| v5.x.x  | :white_check_mark: |
| v4.x.x  | :x:                |
| < v4.0  | :x:                |

## Architectural Security Posture
Project Bare operates on a strict Control Plane vs. Data Plane separation (see `ARCHITECTURE.md`). 
* **The Brain** (Control Plane) relies on hardware-anchored trust and Vault-integrated credentials.
* **The Body** (Worker Nodes) utilizes a No-Touch SSH gap.

## Reporting a Vulnerability
If you discover a vulnerability that compromises the "No-Touch" SSH gap, allows a Worker to escalate privileges to the Control Plane, or bypasses the Circuit Breaker logic, please **do not open a public issue**. 

Instead, please report it directly to the repository owner via private communication to allow time for patching before the vulnerability is disclosed to the public network.
