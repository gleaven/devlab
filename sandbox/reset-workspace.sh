#!/bin/bash
# Reset the DevLab workspace to its initial known-good state.
# This clears all project files but preserves IDE extensions and home directory configs.

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  WARNING: This will delete ALL files in /workspace   ║"
echo "║  and restore the starter demo project.               ║"
echo "║                                                      ║"
echo "║  Your IDE extensions and tool configs are preserved.  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
read -p "Continue? (y/N): " confirm

if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    echo "Resetting workspace..."
    rm -rf /workspace/*
    rm -f /workspace/.initialized /workspace/.* 2>/dev/null

    # Re-create starter project + workspace-level Kilo rules
    cd /workspace
    mkdir -p .kilocode/rules
    cat > .kilocode/rules/devlab-workflow.md << 'RULES'
# DevLab Environment

You are running inside a DevLab sandbox on NVIDIA GB10. Use Poolside
Laguna XS.2 via LiteLLM. Be action-oriented; use write_to_file directly.
RULES
    mkdir -p demo-project && cd demo-project
    git init
    cat > README.md << 'HEREDOC'
# DevLab Demo Project

Welcome to DevLab on NVIDIA GB10. Your workspace has been reset.

Run `aider` or open Kilo Code (sidebar) to start vibe coding!
HEREDOC
    git add . && git commit -m "Initial commit (workspace reset)"
    touch /workspace/.initialized

    echo ""
    echo "Workspace reset complete. Happy coding!"
else
    echo "Cancelled."
fi
