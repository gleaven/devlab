# DevLab Sandbox — Ubuntu 24.04 development environment
# Provides: Python 3, Node.js 22, Go, Rust, Docker CLI, Claude Code, Aider
# MCP servers accessed through LiteLLM gateway (not installed locally)
# Accessible via SSH from the IDE container on port 2222

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── Core development tools ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake pkg-config \
    openssh-server sudo \
    curl wget git vim tmux htop \
    python3 python3-pip python3-venv python3-dev \
    ca-certificates gnupg \
    net-tools iputils-ping dnsutils \
    jq unzip zip \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 22 LTS ─────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# ── Create dev user ────────────────────────────────────────────────
RUN userdel -r ubuntu 2>/dev/null; \
    useradd -m -s /bin/bash -u 1000 dev && \
    echo "dev:dev" | chpasswd && \
    usermod -aG sudo,docker dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ── Configure SSH on port 2222 ─────────────────────────────────────
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitUserEnvironment no/PermitUserEnvironment yes/' /etc/ssh/sshd_config

# ── Go (latest from official tarball) ──────────────────────────────
RUN ARCH=$(dpkg --print-architecture) && \
    GO_VERSION=$(curl -s 'https://go.dev/dl/?mode=json' | jq -r '.[0].version') && \
    curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-${ARCH}.tar.gz" | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"

# ── AI coding tools (global) ──────────────────────────────────────
RUN npm install -g @anthropic-ai/claude-code && \
    pip3 install --break-system-packages aider-chat

# MCP servers are exposed by the bundled bridge service (see ../docker-compose.yml,
# the demo-mcp-bridge container) at http://demo-mcp-bridge:4000/mcp/. No local
# installation needed — the bridge multiplexes filesystem, fetch, memory,
# sequential-thinking, etc. Configured via .claude/mcp_servers.json (seeded
# from sandbox/mcp-config.json) and ide/cline-mcp-settings.json.

# ── Rust (global install — /home/dev is a volume mount, can't store toolchains there)
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
ENV PATH="/usr/local/cargo/bin:${PATH}"

# ── System-wide tool paths ──────────────────────────────────────
# /etc/profile.d is sourced for login shells; /etc/environment is read by PAM.
# Both ensure Go, Rust, and pip-installed tools are available in SSH sessions.
RUN echo 'export PATH="/usr/local/cargo/bin:/usr/local/go/bin:$PATH"' > /etc/profile.d/devlab-tools.sh && \
    echo 'export RUSTUP_HOME=/usr/local/rustup' >> /etc/profile.d/devlab-tools.sh && \
    echo 'export CARGO_HOME=/usr/local/cargo' >> /etc/profile.d/devlab-tools.sh && \
    chmod +x /etc/profile.d/devlab-tools.sh && \
    sed -i 's|^PATH=.*|PATH="/usr/local/cargo/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"|' /etc/environment && \
    echo 'RUSTUP_HOME=/usr/local/rustup' >> /etc/environment && \
    echo 'CARGO_HOME=/usr/local/cargo' >> /etc/environment

# ── Dev user environment ──────────────────────────────────────────

# Stage config files in /etc/skel-devlab (NOT /home/dev, which is a volume mount).
# The entrypoint seeds these into the volume on first run.
RUN mkdir -p /etc/skel-devlab/.ssh /etc/skel-devlab/.claude /etc/skel-devlab/.mcp && \
    echo "ANTHROPIC_BASE_URL=http://host.docker.internal:11434" > /etc/skel-devlab/.ssh/environment && \
    echo "ANTHROPIC_AUTH_TOKEN=not-used" >> /etc/skel-devlab/.ssh/environment && \
    echo "OPENAI_API_BASE=http://host.docker.internal:11434/v1" >> /etc/skel-devlab/.ssh/environment && \
    echo "OPENAI_API_KEY=not-used" >> /etc/skel-devlab/.ssh/environment && \
    echo "PATH=/usr/local/cargo/bin:/usr/local/go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> /etc/skel-devlab/.ssh/environment

COPY --chown=dev:dev claude-code-config.json /etc/skel-devlab/.claude/settings.json
COPY --chown=dev:dev mcp-config.json /etc/skel-devlab/.claude/mcp_servers.json
COPY --chown=dev:dev aider-config.yml /etc/skel-devlab/.aider.conf.yml
COPY --chown=dev:dev motd /etc/skel-devlab/.motd

# Entrypoint & reset script
COPY entrypoint.sh /entrypoint.sh
COPY reset-workspace.sh /usr/local/bin/reset-workspace
RUN chmod +x /entrypoint.sh /usr/local/bin/reset-workspace

EXPOSE 2222

ENTRYPOINT ["/entrypoint.sh"]
