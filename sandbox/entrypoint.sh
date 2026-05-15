#!/bin/bash
# DevLab Sandbox entrypoint
# Seeds config files into /home/dev volume, initializes workspace, starts SSH

set -e

# ── Seed config files into /home/dev volume (first-run only) ──────
# Named volume at /home/dev is empty on first run, hiding Dockerfile files.
# Copy from /etc/skel-devlab (staged during build) if not already present.

if [ -d /etc/skel-devlab ]; then
    chown -R dev:dev /home/dev

    su dev -c '
        cp -n /etc/skel-devlab/.aider.conf.yml /home/dev/.aider.conf.yml 2>/dev/null || true
        cp -n /etc/skel-devlab/.motd /home/dev/.motd 2>/dev/null || true

        mkdir -p /home/dev/.claude
        cp -n /etc/skel-devlab/.claude/settings.json /home/dev/.claude/settings.json 2>/dev/null || true
        cp -n /etc/skel-devlab/.claude/mcp_servers.json /home/dev/.claude/mcp_servers.json 2>/dev/null || true

        mkdir -p /home/dev/.ssh
        cp -n /etc/skel-devlab/.ssh/environment /home/dev/.ssh/environment 2>/dev/null || true
        chmod 700 /home/dev/.ssh

        mkdir -p /home/dev/.mcp
    '
fi

# ── Git config ───────────────────────────────────────────────────
su dev -c '
    git config --global user.email "dev@devlab.local" 2>/dev/null || true
    git config --global user.name "DevLab User" 2>/dev/null || true
    git config --global init.defaultBranch main 2>/dev/null || true
'

# ── Workspace initialization ─────────────────────────────────────
mkdir -p /workspace
chown -R dev:dev /workspace

if [ ! -f /workspace/.initialized ]; then
    su dev -c '
        cd /workspace

        # Workspace-level rules — Kilo Code reads .kilocode/rules/*.md
        # (canonical path per https://kilo.ai/docs/customize/custom-rules — replaces
        # the legacy .roorules path that emitted a deprecation warning)
        mkdir -p .kilocode/rules
        cat > .kilocode/rules/devlab-workflow.md << "RULES"
# DevLab Environment

You are running inside a DevLab sandbox on an NVIDIA GB10 (ARM64, Blackwell GPU).
The agentic coding model is Poolside Laguna XS.2 BF16, served from node 2 of
the GB10 cluster and routed through LiteLLM.

## Available Tools
- Python 3, Node.js 22, Go, Rust, Docker CLI
- Full sudo access, internet through LiteLLM gateway
- /workspace is the persistent project directory

## CRITICAL Workflow Rules
- Be ACTION-ORIENTED. When asked to create something, start writing files immediately.
- Do NOT call list_files before creating files. You already know the workspace is at /workspace.
- NEVER call the same tool twice in a row. After any tool result, proceed to the next step.
- Create project directories and files directly with write_to_file — no need to explore first.
- NEVER use apply_diff. ALWAYS use write_to_file to create or modify files. If you need to edit a file, read it first with read_file, then write the complete updated content with write_to_file.
- If any tool call fails, do NOT retry the same call. Switch to a different approach immediately.
- Web apps can be previewed via port forwarding (ports 3000, 5173, 8000).
- All code stays local — nothing leaves this device.
RULES

        mkdir -p demo-project && cd demo-project
        git init
        cat > README.md << "HEREDOC"
# DevLab Demo Project

Welcome to DevLab on NVIDIA GB10.

## AI Coding Tools

### Kilo Code (VS Code Sidebar) — READY TO USE
Kilo Code is the primary agentic AI coder, pre-configured with Poolside
Laguna XS.2 (BF16) via LiteLLM. No wizard, no setup.
- Click the **Kilo Code icon** in the left sidebar
- Type a prompt and press Enter

### Continue (VS Code) — READY TO USE
Tab autocomplete and inline chat are pre-configured with Laguna.
- Press `Tab` to accept autocomplete suggestions
- Press `Ctrl+L` to open Continue chat
- Press `Ctrl+I` to edit selected code with AI

### Claude Code (Terminal) — READY TO USE
```bash
claude
```

### Aider (Terminal) — READY TO USE
```bash
aider
```

## Languages & Runtimes
- Python 3, Node.js 22, Go, Rust
- Docker CLI (build and run containers)

## Useful Commands
- `reset-workspace` — restore workspace to initial state
- `docker ps` — list running containers

## Getting Started
Try asking Kilo Code to build something:
> "Create a React todo app with a dark theme"
HEREDOC
        git add . && git commit -m "Initial commit"
    '
    touch /workspace/.initialized
fi

# ── Shell config ─────────────────────────────────────────────────
if ! grep -q '.motd' /home/dev/.bashrc 2>/dev/null; then
    echo 'cat ~/.motd 2>/dev/null' >> /home/dev/.bashrc
fi

# ── Start SSH daemon ─────────────────────────────────────────────
exec /usr/sbin/sshd -D
