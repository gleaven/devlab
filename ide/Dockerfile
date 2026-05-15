# DevLab IDE — code-server (VS Code in the browser)
# Connects to the sandbox container via SSH for terminal access
# nginx reverse proxy handles /devlab sub-path rewriting

FROM codercom/code-server:latest

USER root

# Install SSH client + nginx (reverse proxy for /devlab sub-path)
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client sshpass curl jq nginx \
    && rm -rf /var/lib/apt/lists/*

# nginx config for /devlab path rewriting
COPY nginx.conf /etc/nginx/sites-available/default
# nginx runs as coder user — ensure temp dirs are writable
RUN mkdir -p /var/lib/nginx/body /var/lib/nginx/proxy /var/lib/nginx/fastcgi /var/lib/nginx/uwsgi /var/lib/nginx/scgi && \
    chown -R coder:coder /var/lib/nginx /var/log/nginx /run && \
    sed -i 's/^user .*/# user disabled - running as coder/' /etc/nginx/nginx.conf && \
    sed -i 's|pid /run/nginx.pid|pid /tmp/nginx.pid|' /etc/nginx/nginx.conf

# Create workspace directory
RUN mkdir -p /workspace && chown coder:coder /workspace

# Pre-install extensions from Open VSX
COPY install-extensions.sh /tmp/install-extensions.sh
RUN chmod +x /tmp/install-extensions.sh && \
    su coder -c "bash /tmp/install-extensions.sh"

# Default VS Code settings
RUN mkdir -p /home/coder/.local/share/code-server/User
COPY settings.json /home/coder/.local/share/code-server/User/settings.json
RUN chown -R coder:coder /home/coder/.local/share/code-server

# Continue extension configuration
RUN mkdir -p /home/coder/.continue
COPY continue-config.json /home/coder/.continue/config.json
RUN chown -R coder:coder /home/coder/.continue

# Kilo Code — pre-configure MCP servers
RUN mkdir -p /home/coder/.local/share/code-server/User/globalStorage/kilocode.kilo-code/settings
COPY cline-mcp-settings.json /home/coder/.local/share/code-server/User/globalStorage/kilocode.kilo-code/settings/mcp_settings.json
RUN chown -R coder:coder /home/coder/.local/share/code-server/User/globalStorage/kilocode.kilo-code

# Kilo Code — pre-configure API provider via autoImport
# settings.json sets kilo-code.autoImportSettingsPath -> this file; on first
# launch Kilo reads it and writes its globalState (no wizard needed).
RUN mkdir -p /home/coder/.config/kilo-code
COPY kilo-code-settings.json /home/coder/.config/kilo-code/provider-settings.json
RUN chown -R coder:coder /home/coder/.config/kilo-code

# SSH keypair for connecting to sandbox
RUN mkdir -p /home/coder/.ssh && \
    ssh-keygen -t ed25519 -f /home/coder/.ssh/id_ed25519 -N "" && \
    chown -R coder:coder /home/coder/.ssh

# Entrypoint: set up SSH then start code-server
COPY entrypoint.sh /usr/local/bin/devlab-entrypoint.sh
RUN chmod +x /usr/local/bin/devlab-entrypoint.sh

USER coder
WORKDIR /workspace

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/devlab-entrypoint.sh"]
