# DEVLAB — Browser-Based Vibe Coding Lab

> code-server VS Code in the browser, paired with an Ubuntu sandbox
> pre-loaded with Aider, Continue, Kilo Code, and Claude Code — all
> wired to whatever OpenAI-compatible LLM endpoint (Ollama, vLLM, etc.)
> you point them at, with a bundled MCP tool gateway behind them.

---

## What this demo is

DEVLAB is a two-container "vibe coding" lab you can stand up on any
Linux box with Docker. It hands a non-developer (or a developer
without a workstation) a fully provisioned VS Code IDE in their
browser and a separate Ubuntu sandbox shell, both speaking to a
locally-hosted LLM. Nothing leaves the machine unless you point the
configured endpoint at a remote API.

There are two containers:

1. **IDE container** (`demo-devlab-ide`) — runs
   [code-server](https://github.com/coder/code-server) (VS Code in the
   browser) on a `/devlab/` sub-path behind an in-container nginx
   reverse proxy. Comes with Kilo Code, Continue, Python, Go, Rust,
   Docker, Tailwind, Prettier, ESLint, GitLens, and Material Icons
   pre-installed from Open VSX. SSH key + port-forwards to the
   sandbox are set up at boot so the integrated terminal opens
   directly into the sandbox.
2. **Sandbox container** (`demo-devlab-sandbox`) — Ubuntu 24.04 with
   the full dev toolchain (Python 3, Node.js 22, Go, Rust, Docker
   CLI, build-essential, tmux, jq, etc.) plus the
   `@anthropic-ai/claude-code` and `aider-chat` CLIs. SSH on
   internal port `2222`, `dev` user with passwordless sudo and
   docker-group membership. The host's Docker socket is bind-mounted
   in so the user can build images "on" the sandbox without
   running docker-in-docker.

A third bundled service, the **MCP bridge**
(`devlab-mcp-bridge`, image `demo-mcp-bridge:latest`), aggregates the
`filesystem`, `fetch`, `memory`, and `sequential_thinking` MCP stdio
servers behind a single HTTP endpoint at `http://demo-mcp-bridge:4000/mcp/`.
The MCP configs in the IDE (Kilo Code) and the sandbox
(Claude Code, Cline) point at it out of the box.

There is **no LLM bundled in this demo**. You bring your own
OpenAI-compatible endpoint via the `OLLAMA_BASE_URL` env var (see
Configuration below). Aider, Continue, and Kilo Code talk to it
directly. Claude Code wants the Anthropic protocol — supply
`ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` if you want it to work,
otherwise stick to the three OpenAI-protocol tools.

---

## Capabilities (at a glance)

- code-server VS Code, browser-accessible at `/devlab/`.
- nginx sub-path proxy (so DEVLAB cohabits with other demos at `/`).
- SSH key auto-provisioned IDE → sandbox; integrated terminal opens
  into the sandbox by default.
- Auto-forwarded preview ports `3000`, `5173`, `8000`, `8888` from
  sandbox → IDE.
- Ubuntu 24.04 sandbox with Python 3, Node 22, Go (latest), Rust
  (rustup), Docker CLI, build-essential, tmux.
- Passwordless sudo + docker-group `dev` user; host Docker socket
  bind-mounted (image builds run on the host daemon).
- Aider, Continue, Kilo Code — three OpenAI-protocol agentic coding
  tools, all auto-pointed at the same LLM endpoint.
- Claude Code CLI (Anthropic protocol — needs a real Anthropic
  endpoint).
- Bundled MCP gateway exposing `filesystem`, `fetch`, `memory`, and
  `sequential_thinking` tools to the agentic coders.
- Persistent named volumes for `/workspace` (shared IDE↔sandbox),
  `/home/dev`, code-server data, and MCP memory/filesystem state.
- `reset-workspace` script restores `/workspace` to a known-good
  starter project.
- Optional Caddy reverse proxy (HTTPS via Let's Encrypt) as a compose
  profile.

---

## Reference build platform

This demo was built and tested on a **Dell Pro Max GB10** (NVIDIA
Grace Blackwell, **ARM / aarch64** architecture). Everything is plain
Docker — no GPU is required for DEVLAB itself — so any Linux x86_64
host with Docker also works without changes. The base images
(`codercom/code-server:latest`, `ubuntu:24.04`, `caddy:2-alpine`,
`node:22-alpine` for the bridge) are multi-arch.

If you run a local LLM (Ollama, vLLM) on the same box, that's where
your hardware demands come from — not from DEVLAB.

---

## Requirements

| Requirement | Minimum | Notes |
|---|---|---|
| OS | Linux, macOS, or Windows (WSL2) | Native Docker Desktop on macOS/Windows works; on Linux Docker Engine is fine. |
| Docker | 24.x or newer | Compose **v2** (`docker compose`, not `docker-compose`). |
| Disk | ~8 GB | code-server image (~1.5 GB), Ubuntu 24.04 + dev toolchain (~5 GB), bridge (~200 MB), volumes. |
| RAM | 8 GB minimum | Sandbox alone has `mem_limit: 8g`; IDE has `mem_limit: 2g`. Plus whatever your LLM needs. |
| GPU | Not required | The LLM endpoint you point at may need one; DEVLAB itself doesn't. |
| Ollama (or any OpenAI-compatible endpoint) | Reachable from the sandbox container | Default pattern is the host's Ollama at `http://host.docker.internal:11434/v1`. The compose file maps `host.docker.internal` to the host gateway on Linux. |
| API key | None for Ollama | Cloud APIs (`OpenAI`, `Together`, etc.) need a real key in `LLM_API_KEY`. |

---

## Installation (step-by-step)

These instructions assume a fresh Linux box. If you already have
Docker + an OpenAI-compatible endpoint working, skip to step 4.

### 1. Install Docker Engine + Compose v2

Ubuntu / Debian:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"   # let your user run docker without sudo
newgrp docker                      # apply the new group in this shell
docker compose version             # should print "Docker Compose version v2.x.x"
```

If `docker compose version` reports "command not found", install the
plugin:

```bash
sudo apt install docker-compose-plugin
```

### 2. Stand up an OpenAI-compatible LLM endpoint

Ollama is the easiest path. Install it on the **host** (not inside a
container):

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama serve &                          # if not already running as a service
ollama pull qwen2.5-coder:7b            # or llama3.1, mistral, deepseek-coder, etc.
curl http://localhost:11434/v1/models   # confirm the OpenAI-compatible endpoint is up
```

Anything that speaks OpenAI's HTTP protocol works (vLLM, llama.cpp's
server, LM Studio, LocalAI, OpenAI itself, Together, Groq, etc.).

### 3. Verify the sandbox container will be able to reach it

The compose file adds `host.docker.internal -> host-gateway` for the
sandbox, which works out of the box on Docker Desktop and on modern
Linux Docker. If you're on an unusual setup, sanity-check by running:

```bash
docker run --rm --add-host=host.docker.internal:host-gateway \
    curlimages/curl:latest \
    curl -s http://host.docker.internal:11434/v1/models
```

If that returns JSON, you're good. If not, set `OLLAMA_BASE_URL` to a
LAN IP that *is* reachable instead.

### 4. Clone the repo

```bash
git clone https://github.com/gleaven/devlab.git
cd devlab
```

### 5. Create the environment file

```bash
cp .env.example .env
```

Then edit `.env` and set the two required variables:

```ini
OLLAMA_BASE_URL=http://host.docker.internal:11434/v1
LLM_MODEL=qwen2.5-coder:7b
```

The compose file uses Bash-style `:?` guards on both — startup will
fail loudly if either is unset.

### 6. Build and start

```bash
docker compose up -d --build
```

The first build takes **5–10 minutes** (Ubuntu 24.04 base, Node.js
22, Go, Rust toolchain, Aider, Claude Code CLI, code-server
extensions). Subsequent starts take ~10 seconds.

### 7. Verify it's healthy

```bash
docker compose ps
# All three of demo-devlab-sandbox, demo-devlab-ide, and devlab-mcp-bridge
# should show "healthy" within 1–2 minutes.

# IDE health endpoint (proxies through nginx to code-server):
curl -fsS http://localhost:8080/devlab/healthz

# MCP bridge health:
docker exec demo-devlab-sandbox curl -fsS http://demo-mcp-bridge:4000/health
```

### 8. Open the IDE

```
http://localhost:8080/devlab/
```

You'll get straight into VS Code — no login, no first-run wizard. The
default terminal profile (`Sandbox Terminal`) is an SSH session into
the sandbox. Open it (Ctrl+`` ` ``) and you should see the DEVLAB
MOTD listing the available tools.

### 9. (Optional) Tail the logs

```bash
docker compose logs -f ide sandbox mcp-bridge
```

---

## Configuration

All variables can be set in `.env` or exported in your shell.

| Variable | Default | What it controls |
|---|---|---|
| `OLLAMA_BASE_URL` | _(required)_ | Any OpenAI-compatible base URL (with `/v1`). Default pattern is `http://host.docker.internal:11434/v1`. Wired into `OPENAI_API_BASE` inside the sandbox. |
| `LLM_MODEL` | _(required)_ | Default coding model (e.g. `qwen2.5-coder:7b`, `llama3.1`). Must already exist at the endpoint above. |
| `LLM_API_KEY` | `not-used` | Set if your endpoint requires a real key (cloud APIs, password-protected vLLM, etc.). Wired into `OPENAI_API_KEY`. |
| `ANTHROPIC_BASE_URL` | falls back to `OLLAMA_BASE_URL` | Override when you have a real Anthropic-protocol endpoint and want Claude Code CLI to work. |
| `ANTHROPIC_AUTH_TOKEN` | `not-used` | Anthropic API key. Required only if you actually want to use Claude Code. |
| `LANGFUSE_HOST` | _(empty)_ | Optional Langfuse observability endpoint. Empty means no-op. |
| `LANGFUSE_PUBLIC_KEY` | _(empty)_ | Langfuse public key. |
| `LANGFUSE_SECRET_KEY` | _(empty)_ | Langfuse secret key. |
| `APP_PORT` | `8080` | Host port mapped to the IDE container's nginx (which proxies code-server). |
| `DEMO_HOSTNAME` | `localhost` | Hostname Caddy serves under (proxy profile only). |
| `HTTP_PORT` | `8081` | Caddy HTTP port (proxy profile only). |
| `HTTPS_PORT` | `8443` | Caddy HTTPS port (proxy profile only). |

### What's wired where

The sandbox container exports these into the SSH environment via
`/home/dev/.ssh/environment` so they're visible to interactive shells
and to Aider / Claude Code / Continue / Kilo Code subprocesses:

| Var | Source |
|---|---|
| `OPENAI_API_BASE` | `OLLAMA_BASE_URL` |
| `OPENAI_API_KEY` | `LLM_API_KEY` (default `not-used`) |
| `ANTHROPIC_BASE_URL` | `ANTHROPIC_BASE_URL` or fallback `OLLAMA_BASE_URL` |
| `ANTHROPIC_AUTH_TOKEN` | `ANTHROPIC_AUTH_TOKEN` (default `not-used`) |
| `LLM_MODEL` | `LLM_MODEL` |

The IDE container does **not** need the LLM env vars itself — the
agentic coders that run inside the IDE (Continue, Kilo Code) read
their model config from JSON files baked into
`/home/coder/.continue/config.json` and the Kilo Code provider-settings
JSON. See "Architecture" below for the file map.

---

## Live controls (inside the IDE)

Once you're in the browser at `http://localhost:8080/devlab/`:

- **Sandbox Terminal** — default integrated-terminal profile. Drops
  you into an SSH session as `dev@devlab-sandbox`. Run `aider`,
  `claude`, `python`, `node`, `go`, `cargo`, `docker`, etc. directly.
- **Local Shell** — alternate profile, gives you a shell *inside the
  IDE container* (rarely what you want; mostly for debugging
  code-server itself).
- **Kilo Code sidebar** — agentic AI coder, pre-configured with your
  endpoint via the autoImport mechanism. Click the icon, type a
  prompt, watch it scaffold a project. Auto-approval is enabled out
  of the box (it will write/edit files without confirmations).
- **Continue (Ctrl+L for chat, Ctrl+I for inline edit, Tab for
  autocomplete)** — pre-configured to the same endpoint.
- **`reset-workspace`** (in the sandbox terminal) — wipes
  `/workspace/*` and re-creates the starter `demo-project` git repo
  + `.kilocode/rules/devlab-workflow.md`. IDE extensions and home
  configs are preserved.
- **`/workspace`** — shared bind volume between IDE and sandbox.
  Anything you write here from the IDE shows up in the sandbox shell
  immediately, and vice versa.
- **Port forwards** — the entrypoint sets up SSH `-L` forwards from
  sandbox `localhost:{3000,5173,8000,8888}` → IDE `localhost:{same}`,
  so a `npm run dev` in the sandbox is reachable at
  `http://localhost:8080/` *only if you also tunnel from your laptop
  to the IDE container's published port*. The simpler workflow:
  publish those ports in `docker-compose.yml`, or use
  code-server's port-forward UI.

---

## External services (BYO)

If you'd rather supply your own MCP gateway (e.g. a managed one or a
demo-shared LiteLLM that already aggregates MCP servers), edit the
JSON in `sandbox/mcp-config.json` and `ide/cline-mcp-settings.json`
to point at your URL, then start with the BYO override:

```bash
docker compose -f docker-compose.yml -f docker-compose.byo.yml up -d
```

`docker-compose.byo.yml` does two things:

| Override | Effect |
|---|---|
| `mcp-bridge: deploy.replicas: 0` | The bundled MCP bridge container is not started. |
| `sandbox: depends_on: !reset []` | Drops the dependency on `mcp-bridge`'s health, so the sandbox starts even though the bridge is gone. |

The **LLM** itself is always BYO — there is no bundled LLM in either
mode. Point `OLLAMA_BASE_URL` at whatever you want.

---

## Optional HTTPS reverse proxy

A Caddy service is bundled as an opt-in compose profile. It
auto-provisions Let's Encrypt certs when `DEMO_HOSTNAME` is a real
DNS name pointing at this host:

```bash
DEMO_HOSTNAME=devlab.example.com docker compose --profile proxy up -d
```

For local testing keep `DEMO_HOSTNAME=localhost` and Caddy will issue
a self-signed cert on `https://localhost:8443/devlab/`.

The bundled `Caddyfile` is intentionally minimal — one
`reverse_proxy ide:8080` line. Add basic-auth, IP allowlists, etc.
there.

---

## Authentication

DEVLAB runs **without authentication by default**. code-server has
`--auth none` in the entrypoint, which means anyone who can reach
port `8080` gets a root-equivalent shell on your sandbox (and, via
the bind-mounted `/var/run/docker.sock`, on the host Docker daemon).

**Do not expose this to the public internet without an auth layer.**
At minimum:

- **Caddy basic_auth** — add a `basic_auth` directive to the
  `Caddyfile` and run with `--profile proxy`.
- **oauth2-proxy in front of Caddy** — for SSO-style auth.
- **Cloudflare Tunnel + Access policies** — easiest if you're already
  on Cloudflare.
- **Tailscale / WireGuard** — keep the port firewalled and reach it
  only over your overlay network.

For a single-user lab on a workstation, binding `8080` to `127.0.0.1`
in `docker-compose.yml` (`"127.0.0.1:8080:8080"`) is enough.

---

## Architecture (file map)

DEVLAB has **no top-level `Dockerfile` or `server.py`**. Each
container's source lives in its own subdirectory.

### Top level

| File | Purpose |
|---|---|
| `docker-compose.yml` | Defines the three services (`sandbox`, `ide`, `mcp-bridge`) plus the optional `caddy` proxy profile. Source of truth for env vars, volumes, ports, healthchecks. |
| `docker-compose.byo.yml` | Override that disables the bundled MCP bridge for users who supply their own. |
| `.env.example` | Template for `OLLAMA_BASE_URL`, `LLM_MODEL`, ports, and optional Anthropic / Langfuse vars. Copy to `.env` and edit. |
| `Caddyfile` | One-line reverse-proxy config for the optional `--profile proxy` HTTPS frontend. |

### `ide/` — code-server container

| File | Purpose |
|---|---|
| `Dockerfile` | `codercom/code-server:latest` + nginx + openssh-client + extension install + config seed. Generates an SSH ed25519 keypair at build time. |
| `entrypoint.sh` | (1) `ssh-copy-id` into the sandbox using `sshpass` against the default `dev:dev` creds, (2) start SSH `-L` port-forwards for ports 3000/5173/8000/8888, (3) start nginx on `:8080`, (4) `exec code-server --bind-addr 127.0.0.1:8081 --auth none /workspace`. |
| `nginx.conf` | Reverse-proxies `/devlab/` → `127.0.0.1:8081/`, rewrites absolute paths in HTML/JS/CSS via `sub_filter`, long timeouts for terminal/LSP WebSockets. |
| `install-extensions.sh` | Installs Kilo Code (pinned `5.16.0`), Continue, Python, Go, Rust Analyzer, Docker, GitLens, Prettier, ESLint, Tailwind, and Material Icons from Open VSX during the image build. |
| `settings.json` | Default VS Code settings. Sets the integrated terminal default to the `Sandbox Terminal` SSH profile. Configures Kilo Code's autoImport path, auto-approval, and custom workflow instructions. Disables telemetry. |
| `continue-config.json` | Continue's `~/.continue/config.json`. Defines the chat + autocomplete model. |
| `kilo-code-settings.json` | Pre-baked Kilo Code provider-settings (read once at first launch via `kilo-code.autoImportSettingsPath`) so users skip the model-config wizard. |
| `cline-mcp-settings.json` | MCP server registration for Kilo Code, pointing at `http://demo-mcp-bridge:4000/mcp/`. |

### `sandbox/` — Ubuntu 24.04 dev container

| File | Purpose |
|---|---|
| `Dockerfile` | Ubuntu 24.04 + apt dev toolchain + Node.js 22 (NodeSource) + Go (latest from go.dev) + Rust (rustup) + Docker CLI. Installs `@anthropic-ai/claude-code` (npm) and `aider-chat` (pip). Creates `dev` user (uid 1000, password `dev`, NOPASSWD sudo, docker group). Configures sshd on port 2222 with password+env auth. Stages config files in `/etc/skel-devlab/` so the entrypoint can seed them into the `/home/dev` named volume on first run. |
| `entrypoint.sh` | (1) Seed `~/.aider.conf.yml`, `~/.claude/settings.json`, `~/.claude/mcp_servers.json`, `~/.ssh/environment`, `~/.motd` from `/etc/skel-devlab/` if missing, (2) set git defaults, (3) on first run create `/workspace/demo-project` (git init + README) and `/workspace/.kilocode/rules/devlab-workflow.md`, (4) `exec /usr/sbin/sshd -D`. |
| `aider-config.yml` | Aider's `~/.aider.conf.yml`. Model + endpoint + auto-commits + dark mode. |
| `claude-code-config.json` | Claude Code's `~/.claude/settings.json`. Permissions `allow: ["Bash(*)", "Read(*)", "Write(*)", "Edit(*)", "Glob(*)", "Grep(*)"]` — fully autonomous, no per-tool prompts. |
| `mcp-config.json` | Claude Code's `~/.claude/mcp_servers.json`. Registers the bundled bridge as an SSE MCP server. |
| `motd` | ASCII banner shown on every SSH login. |
| `reset-workspace.sh` | Wipes `/workspace` and re-seeds the starter project + Kilo rules. Installed as `/usr/local/bin/reset-workspace`. |

### Bundled MCP bridge

The `mcp-bridge` service builds from `../_shared/mcp-bridge`. It's a
Node.js HTTP server that spawns the `@modelcontextprotocol/server-*`
stdio packages (`filesystem`, `fetch`, `memory`, `sequential_thinking`)
and exposes them at `http://demo-mcp-bridge:4000/mcp/` with a
LiteLLM-compatible JSON-RPC 2.0 + SSE response format. Two named
volumes (`devlab-mcp-memory`, `devlab-mcp-fs`) persist the memory
knowledge graph and filesystem MCP's workspace.

### Volumes

| Volume | Mounted at | Why it exists |
|---|---|---|
| `devlab-workspace` | `/workspace` (sandbox **and** ide) | Shared project tree — both containers see the same files. |
| `devlab-sandbox-home` | `/home/dev` (sandbox) | Persists shell history, SSH keys, Aider/Claude/Kilo configs, and any tools the user installs into their home. |
| `devlab-ide-data` | `/home/coder/.local/share/code-server` (ide) | Persists code-server settings, installed extensions across rebuilds, open-tab state. |
| `devlab-mcp-memory` | `/mcp-data/memory` (bridge) | MCP `memory` server's `knowledge-graph.jsonl`. |
| `devlab-mcp-fs` | `/mcp-data/filesystem` (bridge) | MCP `filesystem` server's sandboxed root. |
| `devlab-caddy-data`, `devlab-caddy-config` | inside caddy | Let's Encrypt account + cert storage. |

`docker compose down` keeps these. `docker compose down -v` deletes
them — including your `/workspace` and your home directory.

---

## Troubleshooting

- **`OLLAMA_BASE_URL` / `LLM_MODEL` error on `up`** — the compose
  file uses `:?` Bash-style guards on both. Check `.env` exists in
  the same directory you ran `docker compose` from, and that both
  variables are set. Run `docker compose config` to see the
  resolved env.
- **`curl ${OLLAMA_BASE_URL}/models` works on host but the sandbox
  can't reach it** — `host.docker.internal` resolves to the host
  gateway, but the firewall on your host may be blocking traffic
  from the docker bridge interface. Either add a rule or set
  `OLLAMA_BASE_URL` to a LAN IP that's already firewall-open.
- **Browser shows nginx 502 / blank page at `/devlab/`** — the IDE
  container's nginx is up but code-server isn't. Look at
  `docker logs demo-devlab-ide` for a code-server stack trace; the
  most common cause is the `devlab-ide-data` volume containing a
  half-corrupted state from an earlier run. `docker compose down -v
  && docker compose up -d --build` will reset it (and wipe your
  `/workspace`).
- **`open terminal` opens a *Local Shell* instead of *Sandbox
  Terminal*** — your `devlab-ide-data` volume has a stale
  per-workspace setting overriding the baked-in
  `terminal.integrated.defaultProfile.linux`. Either pick "Sandbox
  Terminal" from the dropdown next to the `+` button, or wipe the
  volume.
- **SSH from IDE → sandbox prompts for password** — the entrypoint
  could not `ssh-copy-id` (60-attempt timeout). Most likely the
  sandbox sshd never came up. Check `docker logs
  demo-devlab-sandbox` and the sandbox healthcheck (`pgrep sshd`).
  As a fallback the password is `dev`.
- **`claude` CLI errors immediately** — Claude Code speaks the
  Anthropic protocol; Ollama serves OpenAI's. Either skip `claude`
  and use `aider` / Continue / Kilo Code (all OpenAI-protocol), or
  set `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` to a real
  Anthropic-compatible endpoint in `.env`.
- **MCP tool calls fail in Kilo Code / Claude Code / Cline** —
  the MCP bridge isn't reachable. From the sandbox:
  ```bash
  curl http://demo-mcp-bridge:4000/health
  curl -X POST http://demo-mcp-bridge:4000/mcp/ \
       -H 'Content-Type: application/json' \
       -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
  ```
  Check `docker logs devlab-mcp-bridge` if either fails. To swap in
  your own gateway, edit `sandbox/mcp-config.json` +
  `ide/cline-mcp-settings.json` and use the `byo` override.
- **Docker-in-sandbox can't see the host daemon** — the sandbox
  bind-mounts `/var/run/docker.sock` from the host. On systems with
  SELinux / AppArmor in enforcing mode you may need
  `:z`/`:Z` mount options. Disable the mount entirely if you don't
  want this.
- **Long first build (10+ min)** — sandbox image installs the full
  dev toolchain (Go, Rust, Node 22, Python, Aider, Claude Code).
  Subsequent builds use the BuildKit layer cache and finish in
  seconds.
- **Port already in use on `8080`** — change `APP_PORT` in `.env`
  and re-up.
- **`/workspace` files disappeared after `docker compose down -v`**
  — `-v` removes named volumes including `devlab-workspace`. There
  is no automatic backup. Use `docker compose down` (no `-v`) for
  routine restarts.

---

## FAQ

**Q: Do I need a GPU?** Not for DEVLAB itself. Whatever LLM endpoint
you point at may need one — that's a separate concern. The default
"Ollama on host" pattern uses your host GPU if Ollama is configured
for it.

**Q: Why two containers instead of one?** Isolation. The IDE
container runs untrusted-by-default browser code (code-server) and
has nginx in it. The sandbox is where users actually compile, build,
and run their projects, with passwordless sudo and the host docker
socket — keeping it separate means a bug in code-server can't
trivially escape into the sandbox toolchain. They communicate over
SSH on the internal `devlab` network.

**Q: Can I add more languages / system packages?** Yes — either edit
`sandbox/Dockerfile` and rebuild, or `sudo apt install …` from
inside the sandbox shell (changes survive across `docker compose
restart` because `/home/dev` is a volume, but apt-installed packages
in `/usr/` are lost on a rebuild).

**Q: Can I use a real Anthropic key for Claude Code and Ollama for
the others?** Yes. Set `OLLAMA_BASE_URL` to your Ollama endpoint and
also set `ANTHROPIC_BASE_URL=https://api.anthropic.com` +
`ANTHROPIC_AUTH_TOKEN=sk-ant-…`. Aider/Continue/Kilo will use
Ollama; `claude` will use the real Anthropic API.

**Q: Is `/workspace` shared with the host?** No — it's a named
Docker volume, not a bind mount. Both containers share it via the
`devlab-workspace` volume. If you want host access too, change the
volume to a bind mount in `docker-compose.yml`.

**Q: How do I save my work permanently?** Push your project to a
remote git repository from the sandbox terminal (`git remote add
origin … && git push`). Anything in `/workspace` survives container
restarts but not `docker compose down -v`.

---

## Credits

Built by Andrew Meinecke.
