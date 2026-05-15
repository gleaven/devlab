#!/bin/bash
# Install VS Code extensions from Open VSX registry
# These are pre-installed during Docker build for instant availability

EXTENSIONS=(
    # AI coding tools
    # Kilo 5.16.0 pinned: 7.x is the latest pre-release line but its kilo.jsonc
    # config schema isn't fully documented for shipping baked configs (per
    # https://kilo.ai/docs/getting-started/settings — they expect users to
    # write kilo.jsonc via the Settings UI). 5.x supports the documented
    # autoImportSettingsPath mechanism we rely on. Revisit when 7.x docs catch up.
    "kilocode.kilo-code@5.16.0"           # Kilo Code — agentic AI coder (Cline-lineage, BYOK)
    "Continue.continue"                   # Continue — AI autocomplete

    # Language support
    "ms-python.python"                    # Python
    "golang.Go"                           # Go
    "rust-lang.rust-analyzer"             # Rust

    # Development tools
    "ms-azuretools.vscode-docker"         # Docker
    "eamodio.gitlens"                     # GitLens

    # Formatters & linters
    "esbenp.prettier-vscode"              # Prettier
    "dbaeumer.vscode-eslint"              # ESLint

    # Web development
    "bradlc.vscode-tailwindcss"           # Tailwind CSS

    # UI
    "pkief.material-icon-theme"           # Material Icons
)

for ext in "${EXTENSIONS[@]}"; do
    echo "Installing: $ext"
    code-server --install-extension "$ext" 2>/dev/null || \
        echo "  Warning: $ext may not be available on Open VSX"
done

echo "Extension installation complete."
