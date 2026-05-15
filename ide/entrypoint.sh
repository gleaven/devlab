#!/bin/bash
# DevLab IDE entrypoint
# 1. Wait for sandbox SSH to be available
# 2. Copy SSH key for passwordless access
# 3. Set up SSH port forwarding for web app previews
# 4. Start nginx (sub-path reverse proxy)
# 5. Start code-server
# Roo Code API config auto-imported via settings.json autoImportSettingsPath

set -e

SANDBOX_HOST="${SANDBOX_HOST:-devlab-sandbox}"
SANDBOX_PORT="${SANDBOX_PORT:-2222}"
SANDBOX_USER="${SANDBOX_USER:-dev}"

echo "DevLab IDE starting..."

# Wait for sandbox SSH to become available and copy SSH key
echo "Waiting for sandbox SSH at ${SANDBOX_HOST}:${SANDBOX_PORT}..."
for i in $(seq 1 60); do
    if sshpass -p "dev" ssh-copy-id \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -p "${SANDBOX_PORT}" \
        "${SANDBOX_USER}@${SANDBOX_HOST}" 2>/dev/null; then
        echo "SSH key copied to sandbox successfully."
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "WARNING: Could not connect to sandbox SSH after 60 attempts."
        echo "Terminal may require password authentication."
    fi
    sleep 2
done

# Set up SSH port forwarding for web app previews
# Forward common dev server ports from sandbox to IDE container
echo "Setting up port forwarding for dev server previews..."
ssh -N -f \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -L 3000:localhost:3000 \
    -L 5173:localhost:5173 \
    -L 8000:localhost:8000 \
    -L 8888:localhost:8888 \
    -p "${SANDBOX_PORT}" \
    "${SANDBOX_USER}@${SANDBOX_HOST}" 2>/dev/null || \
    echo "WARNING: Port forwarding setup failed. Web previews may not work."

# Start nginx in the background (handles /devlab sub-path rewriting)
echo "Starting nginx reverse proxy..."
nginx

echo "Starting code-server on internal port 8081..."

# code-server listens on 8081; nginx on 8080 handles /devlab path prefix
exec code-server \
    --bind-addr 127.0.0.1:8081 \
    --auth none \
    --disable-telemetry \
    /workspace
