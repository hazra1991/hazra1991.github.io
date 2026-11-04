---
layout: post
title: "Docker Deployment in Practice: Images, Mounts, Permissions and Build Args"
date: 2026-08-09
description: "What actually goes into the image and what gets mounted, why bind-mounted files end up owned by the wrong user, how build args and proxies really work, and how memory limits behave in Compose vs Swarm."
categories: [Deployment, Docker]
tags: [docker, docker-compose, permissions]
mermaid: true
---

> **Docker series:** [1. Docker: A Practical Approach]({{ site.posts | where: "slug", "docker-a-practical-aproach" | first.url | relative_url }}) · **2. Deployment in Practice** · [3. Networking Part 1: How a Request Reaches Your Container]({{ site.posts | where: "slug", "docker-networking-part-1" | first.url | relative_url }}) · [4. Networking Part 2: Subnets, IP Collisions and the Default Bridge]({{ site.posts | where: "slug", "docker-networking-part-2" | first.url | relative_url }})
{: .prompt-info}

Part 1 of the series covers *how to use* Docker. This part covers what happens once you deploy for real. These notes come from containerizing and deploying a FastAPI app (called `my-app` here) with Docker Compose on a single Linux server, and from the problems that came up along the way:

- **What belongs in the image, and what doesn't?** → [§0](#0-the-one-principle-that-explains-everything), [§1](#1-what-goes-in-the-image-vs-what-is-mounted), [§2](#2-bind-mounts-vs-named-volumes)
- **Files written by the container show up on the host owned by the wrong user.** → [§3](#3-uid--gid-matching-the-permission-denied-fix), [§4](#4-the-non-root-app-user--where-its-defined)
- **A build arg you passed is silently ignored, or the build can't reach the package index through the proxy.** → [§5](#5-arg--defaults-not-hardcoding), [§6](#6-proxy-handling--why-the-build_-prefix)
- **Memory limits that may or may not apply, depending on which tool reads the file.** → [§7](#7-memory-limits--compose-vs-swarm)
- **Everyday operations:** docker permissions, custom base images, the deploy sequence. → [§8](#8-docker-permissions-sudo--docker-group)–[§11](#11-quick-facts)

<details>
<summary><strong>📑 Table of Contents</strong></summary>
<div markdown="1">

- [The setup these notes are about](#the-setup-these-notes-are-about)
- [0. The one principle that explains everything](#0-the-one-principle-that-explains-everything)
- [1. What goes in the image vs. what is mounted](#1-what-goes-in-the-image-vs-what-is-mounted)
- [2. Bind mounts vs. named volumes](#2-bind-mounts-vs-named-volumes)
- [3. UID / GID matching (the "permission denied" fix)](#3-uid--gid-matching-the-permission-denied-fix)
- [4. The non-root `app` user](#4-the-non-root-app-user--where-its-defined)
- [5. `ARG`: defaults, not hardcoding](#5-arg--defaults-not-hardcoding)
- [6. Proxy handling: why the `BUILD_` prefix](#6-proxy-handling--why-the-build_-prefix)
- [7. Memory limits: Compose vs. Swarm](#7-memory-limits--compose-vs-swarm)
- [8. Docker permissions (sudo / docker group)](#8-docker-permissions-sudo--docker-group)
- [9. Custom base images](#9-custom-base-images)
- [10. Deploy sequence (single host)](#10-deploy-sequence-single-host)
- [11. Quick facts](#11-quick-facts)

</div>
</details>

---

## **The setup these notes are about**

Every section below refers to some part of these two files. They're simplified, but every line that matters is here, so you can come back to them while reading.

```dockerfile
FROM py314-uv:latest                      # custom base image (see §9)

ARG BUILD_HTTPS_PROXY                     # ← proxy args, prefixed on purpose (§6)
ARG BUILD_HTTP_PROXY
ARG BUILD_NO_PROXY
ARG APP_USER_ID=1000                      # ← overridable defaults (§5)
ARG APP_GROUP_ID=1000

ENV https_proxy=$BUILD_HTTPS_PROXY HTTPS_PROXY=$BUILD_HTTPS_PROXY \
    http_proxy=$BUILD_HTTP_PROXY   HTTP_PROXY=$BUILD_HTTP_PROXY \
    no_proxy=$BUILD_NO_PROXY       NO_PROXY=$BUILD_NO_PROXY

WORKDIR /app                              # ← the invariant: CWD = /app = repo root (§11)
COPY . .
RUN uv sync                               # needs network + proxy at BUILD time

RUN groupadd --gid ${APP_GROUP_ID} app && \
    useradd --create-home --uid ${APP_USER_ID} --gid ${APP_GROUP_ID} --shell /bin/bash app && \
    chown -R app:app /app
USER app                                  # ← everything below runs as non-root (§4)

ENV https_proxy="" HTTPS_PROXY="" http_proxy="" HTTP_PROXY=""   # clear build-time proxy
CMD ["uv", "run", "uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8080"]
```
{: file="Dockerfile"}

```yaml
services:
  my-app:
    build:
      context: .
      args:                                        # .env values → build args
        APP_USER_ID: ${APP_USER_ID:-1000}
        APP_GROUP_ID: ${APP_GROUP_ID:-1000}
        BUILD_HTTPS_PROXY: ${HTTPS_PROXY:-}
        BUILD_HTTP_PROXY: ${HTTP_PROXY:-}
        BUILD_NO_PROXY: ${NO_PROXY:-}
    env_file: .env                                 # runtime env (API keys, runtime proxy)
    ports:
      - "9090:8080"                                # host 9090 → container 8080
    volumes:                                       # bind mounts (§1, §2)
      - ./artifacts:/app/artifacts
      - ./reports:/app/reports
      - ./configs:/app/configs
      - ./.models:/app/.models:ro
    mem_limit: 3g                                  # §7
    mem_reservation: 1g
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      start_period: 60s                            # §11
```
{: file="docker-compose.yaml"}

---

## **0. The one principle that explains everything**

> **The image = your code + dependencies (immutable, rebuildable).
> Everything that is data, state, config, or large external assets lives
> OUTSIDE the image as a mount.**

This is the core Docker philosophy: *immutable image, mutable data outside.*
Every decision below follows from it.

---

## **1. What goes in the image vs. what is mounted**

| Thing            | In image? | Why |
|------------------|-----------|-----|
| `ai_engine/`, `domain/`, `api/` | ✅ baked in | Your code. Rebuilt when it changes. |
| Python deps (`uv sync`)         | ✅ baked in | Reproducible via `uv.lock`. |
| `artifacts/`, `reports/`        | ❌ mount    | **Output / state.** Written at runtime (indexes, logs, results). Must **outlive** the container. |
| `configs/`                      | ❌ mount    | **Changes independently.** Tweak a TOML → restart, no rebuild. |
| `.models/`                      | ❌ mount (read-only) | **Big, read-only, external assets.** GBs of tensors we only *read*. Baking them in bloats the image and couples model updates to code rebuilds. |

The mental model:
- *artifacts/reports* → persist after the container dies.
- *configs* → mounted so edits don't force a rebuild.
- *models* → external, read-mostly; we only read tensor shapes/weights.

---

## **2. Bind mounts vs. named volumes**

There are two kinds of mounts. This project uses **bind mounts**.

### **Bind mount (what we use)**
```yaml
volumes:
  - ./artifacts:/app/artifacts      # HOST path : CONTAINER path
```
- Maps a **specific host folder** (in the repo) into the container.
- You can `cd`, `cat`, `git`-ignore, edit the files directly. They're real files on the host.
- **This is why UID matching matters** (see [§3](#3-uid--gid-matching-the-permission-denied-fix)): files land on the host owned by a numeric UID.

### **Named volume (the alternative)**
```yaml
volumes:
  - artifacts-data:/app/artifacts   # NAME : CONTAINER path (no ./)
```
- Docker creates/manages storage under `/var/lib/docker/volumes/...`.
- Docker handles permissions → **no UID headache**.
- But files are "hidden" in Docker's storage, not sitting in your repo; you'd `docker cp` or exec in to see them.

> **Why named volumes "just work":** when an empty named volume is mounted for the first time, Docker copies the contents **and ownership** of that directory from the image into the volume. If the image's `/app/artifacts` is owned by `app`, so is the volume. A bind mount does no such copying. The host folder wins, with whatever owner it already has.
{: .prompt-tip}

### **Trade-off**
| | Bind mount | Named volume |
|---|---|---|
| See/edit files directly | ✅ | ❌ (managed by Docker) |
| UID matching needed | ✅ yes | ❌ no |
| Best for | configs, dev, inspecting output | opaque persistent state |

### **In production**
Both are used. It depends on the data's role:
- **configs/** → bind mount, or config manager (K8s ConfigMaps, Docker secrets, env).
- **.models/** → bind mount (read-only), shared NFS, or pulled from object storage (S3) at startup. Never baked into the image.
- **artifacts/reports (state/output)** → in serious prod usually a **named volume**, **network volume**, or straight to **object storage / DB**. (Kubernetes `PersistentVolumeClaim` is the same idea: managed persistence decoupled from the pod.)

> A bind-mount + UID-matching setup is legitimate and production-shaped for a
> **single host**. Going multi-host (K8s/Swarm) only changes *where* persistent
> data lives, not the principle.
{: .prompt-info}

---

## **3. UID / GID matching (the "permission denied" fix)**

### **Why it's needed (and NOT a hack)**
It has a name: the **UID/GID mapping problem** with bind mounts.
- The Linux **kernel is shared** between host and container: one kernel, one set of numeric UIDs.
- A file stores a **number** (UID), not a username. Your login name is just a label the host's `/etc/passwd` maps to a number.
- When a container process writes to a bind mount, the kernel stamps the file with the container process's **numeric UID**. The same number appears on the host.
- Inside the container that number may have no name / a different name; on the host it's your user. **The number is the only thing that crosses the boundary.**

```text
 container                         host
 ─────────                         ────
 user "app"  = UID 1001  ──write──▶ ./artifacts/index.faiss  owner: 1001
                                    host /etc/passwd: 1001 = you  ✅ you can read/edit it

 user "app"  = UID 1000  ──write──▶ ./artifacts/index.faiss  owner: 1000
                                    host /etc/passwd: 1000 = someone else (or nobody) ❌
```

So matching the numbers is the *correct* fix. Heavier alternatives:
- rootless Docker / user namespaces (`userns-remap`)
- named volumes (Docker manages ownership)

For a box where you want to read `./artifacts` and `./reports` directly as yourself, UID-matching is the normal, recommended choice.

### **How to find your IDs**
```bash
id
# e.g. uid=<your-uid>(<your-user>) gid=<your-gid>(<your-group>)
```

### **How to apply them**
Set in `.env` (compose forwards these as build args; how that works is in [§5](#5-arg--defaults-not-hardcoding)):
```dotenv
APP_USER_ID=<your-uid>     # from `id -u`
APP_GROUP_ID=<your-gid>    # from `id -g`
```
{: file=".env"}

These are **build args** (baked into the image), so changing them requires a **rebuild**:
```bash
docker compose up --build -d
```

> A plain `docker compose up -d` after editing `.env` reuses the old image, so the old UID stays. If the permission error survives your fix, you probably forgot `--build`.
{: .prompt-warning}

---

## **4. The non-root `app` user — where it's defined**

The container runs as a non-root user `app`. It is **created inside the Dockerfile**:

```dockerfile
RUN groupadd --gid ${APP_GROUP_ID} app && \
    useradd --create-home --uid ${APP_USER_ID} --gid ${APP_GROUP_ID} --shell /bin/bash app && \
    chown -R app:app /app
USER app
```
{: file="Dockerfile"}

- `groupadd --gid ... app` → creates a **group** `app` with that GID.
- `useradd --uid ... --gid ... app` → creates a **user** `app` with that UID, in that group.
- `chown -R app:app /app` → gives the app ownership of its files.
- `USER app` → everything after (including the final `CMD uvicorn ...`) runs **as `app`, not root**.

**Why create a user at all?** Security. By default a container runs as `root`
(UID 0). If the app is compromised, root-in-container is a much bigger blast
radius (especially with mounts). Running non-root is a Docker best practice.

> The name `app` is arbitrary. Only the **number** matters for the mounts.
{: .prompt-tip}

---

## **5. `ARG` — defaults, NOT hardcoding**

```dockerfile
ARG BUILD_HTTPS_PROXY        # NO default → empty "" unless --build-arg is passed
ARG APP_USER_ID=1000         # default 1000, but OVERRIDABLE
```

- `ARG X` (no `=`) → **no value** baked in; empty unless someone passes `--build-arg X=...`.
- `ARG X=1000` → `1000` is a **fallback default**. Override with `--build-arg APP_USER_ID=$(id -u)` or via `.env` (compose forwards it).

So these are **knobs with defaults**, not hardcoded values. Real hardcoding would
be `ENV APP_USER_ID=1000` (no way to change) or writing `1000` literally in `useradd`.

**The flow:**

```text
.env: APP_USER_ID=1001
   │
   ▼  compose: args: APP_USER_ID: ${APP_USER_ID:-1000}
--build-arg APP_USER_ID=1001
   │
   ▼  Dockerfile: ARG APP_USER_ID=1000   ← default overridden
useradd --uid 1001 ...
```

The `1000` only applies if you forget to set it.

---

## **6. Proxy handling — why the `BUILD_` prefix**

```dockerfile
ARG BUILD_HTTPS_PROXY
ARG BUILD_HTTP_PROXY
ARG BUILD_NO_PROXY
ENV https_proxy=$BUILD_HTTPS_PROXY HTTPS_PROXY=$BUILD_HTTPS_PROXY ...
```
{: file="Dockerfile"}

- The arg names deliberately **do NOT** match the proxy ENV names.
- Reason: the base image sets the proxy ENV vars to `""`, and **ENV shadows ARG**
  during variable expansion. If the ARG had the same name, expansion would pick up
  the empty ENV instead.
- The `BUILD_` prefix dodges the shadowing, then we assign them to the real proxy
  ENV vars explicitly.

> **Why not Docker's built-in proxy args?** Docker has *predefined* build args (`HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`, `FTP_PROXY`, `ALL_PROXY` and their lowercase forms). You can pass them with `--build-arg` without declaring an `ARG`, and they're kept out of `docker history`. With a normal base image that's the simplest route. Here it doesn't help: the base image's empty `ENV https_proxy=""` wins over an arg with the same name, which is exactly the shadowing above.
{: .prompt-info}

### **Consequence for manual builds**
`docker build` must use the **prefixed** names, or they're silently ignored
(→ `uv sync` can't reach the internal index → build fails):
```bash
docker build \
  --build-arg BUILD_HTTPS_PROXY="$HTTPS_PROXY" \
  --build-arg BUILD_HTTP_PROXY="$HTTP_PROXY" \
  --build-arg BUILD_NO_PROXY="$NO_PROXY" \
  -t my-app:latest .
```
Easier: `docker compose build` maps `.env` proxies to the `BUILD_*` args automatically.

The proxy is also cleared at the end of the Dockerfile (`ENV https_proxy="" ...`) so the
**runtime** proxy comes from compose env, not the build-time values.

> Anything set with `ENV` is stored in the image config and visible with `docker inspect` / `docker history`. If your proxy URL contains credentials (`http://user:pass@proxy:8080`), they end up in the image. Prefer a credential-free proxy URL for builds.
{: .prompt-warning}

---

## **7. Memory limits — compose vs. swarm**

`docker-compose.yaml` often contains **both** key sets, kept consistent:

```yaml
mem_limit: 3g
mem_reservation: 1g
deploy:
  resources:
    limits:
      memory: 3G
    reservations:
      memory: 1G
```
{: file="docker-compose.yaml"}

To understand why both exist, first: **Compose and Swarm are two different tools**, even though they can read the same file.

| | `docker compose up` | Docker Swarm (`docker stack deploy`) |
|---|---|---|
| What it is | Runs containers on **one machine** (dev box / single server) | An **orchestrator / cluster**: runs containers across **many machines** (nodes) |
| Command | `docker compose up -d` | `docker swarm init` then `docker stack deploy -c docker-compose.yaml mystack` |
| Who uses it | Local dev, single-server deploys (**our case**) | Multi-server production clusters (like a simpler Kubernetes) |
| Multi-node scheduling, rolling updates | ❌ no (replicas only on the one host) | ✅ yes |

Analogy:
- **Compose** = a car engine running in one garage.
- **Swarm** = a fleet manager coordinating cars across many garages.

### **Same file, different fields read**

| Key | Read by | Meaning |
|-----|---------|---------|
| `mem_limit` | `docker compose up` | Hard cap; the container is OOM-killed if it exceeds it. |
| `mem_reservation` | `docker compose up` | **Soft limit.** Only enforced when the host runs short of memory: Docker then pushes the container back toward this value. It is not a guaranteed amount of memory. |
| `deploy.resources.limits/reservations` | **Swarm**, and also **current `docker compose`** | In Swarm, reservations are also used to decide which node has room for the container. |

```mermaid
graph LR
  C[docker-compose.yaml] --> U[docker compose up<br/>single host, Compose v2]
  C --> S[docker stack deploy<br/>Swarm]
  U -->|reads| M[mem_limit / mem_reservation]
  U -->|reads| D[deploy.resources]
  S -->|reads| D
  S -.ignores.-> M
```

> **Correction to a common belief:** "plain `docker compose up` ignores `deploy.resources`" was true for the old Python `docker-compose` v1, which needed a `--compatibility` flag. The current `docker compose` (v2, the CLI plugin) applies `deploy.resources` limits on a single host too. Swarm still ignores `mem_limit` / `mem_reservation`.
{: .prompt-warning}

**Verify on your own machine** instead of trusting either claim:
```bash
docker compose up -d
docker stats --no-stream        # the "MEM USAGE / LIMIT" column shows the limit actually applied
```

**Our situation:**
- Real usage ≈ 1 GB (embedding model + FAISS); 3 GB leaves headroom.
- We deploy on **one server**. `mem_limit` / `mem_reservation` is enough, and `deploy.resources` is future-proofing in case we ever move to Swarm.
- Keeping both is safe **as long as the values are identical**, so it never matters which one a tool reads.

---

## **8. Docker permissions (sudo / docker group)**

If you get `permission denied ... /var/run/docker.sock` without sudo, your user
isn't in the `docker` group.

- Quick: prefix commands with `sudo`. Use `sudo -E` to preserve proxy env, or rely
  on `.env` (compose reads it regardless).
- Permanent: `sudo usermod -aG docker "$USER"` then re-login or `newgrp docker`.

> The `docker` group is effectively **root-equivalent**. Anyone in it can start a container that mounts `/` from the host and edit anything.
{: .prompt-danger}

---

## **9. Custom base images**

`FROM py314-uv:latest` is a **custom base image** that is not on any registry. Docker can't pull it, so it has to exist locally before the build:
```bash
# check if present
docker images | grep py314-uv

# load from a saved tarball
docker load -i py314-uv-3.14.5.tar.gz      # -> "Loaded image: py314-uv:latest"

# or build it from its dir
docker build -t py314-uv:latest py314-uv/
```

> The tarball comes from `docker save py314-uv:latest | gzip > py314-uv-3.14.5.tar.gz` on a machine that has the image. This is how you move images to servers without a registry.
{: .prompt-tip}

---

## **10. Deploy sequence (single host)**

```bash
# 1. host dirs for the mounts
mkdir -p .models artifacts configs reports

# 2. create .env  (API keys + config path + proxies + YOUR uid/gid)
#    ANTHROPIC_API_KEY=...
#    CODEGEN_API_KEY=...
#    AI_ENGINE_CONFIG_FILEPATH=./configs/ai_engine/engine.toml
#    LOG_LEVEL=INFO
#    HTTPS_PROXY=...  HTTP_PROXY=...  NO_PROXY=localhost,127.0.0.1
#    APP_USER_ID=<your-uid>     # <- from `id -u`
#    APP_GROUP_ID=<your-gid>    # <- from `id -g`

# 3. build + run  (rebuild needed because UID/proxy are build args)
docker compose up --build -d        # add sudo if not in docker group

# 4. verify
docker compose ps
docker compose logs -f my-app
curl http://localhost:9090/health    # host 9090 -> container 8080
```

> Create the mount directories **before** the first `up`. If a bind-mount source doesn't exist, Docker creates it **as root**, and the non-root `app` user then can't write into it.
{: .prompt-warning}

### **Common operations**
```bash
docker compose restart my-app
docker compose down                  # stop + remove container (mounts persist)
docker compose up --build -d         # rebuild after code/config-arg change
docker compose logs --tail=100 my-app
```

---

## **11. Quick facts**

- **Port mapping:** host **9090** → container **8080**. How that works, and why the app binds `0.0.0.0`, is covered in [Networking Part 1]({{ site.posts | where: "slug", "docker-networking-part-1" | first.url | relative_url }}).
- **Single worker on purpose:** the generate-lock lives in process memory; multiple
  worker processes would each have their own lock + engine (RAM × N, lock useless).
- **Healthcheck `start_period: 60s`:** the app loads encoders + builds the index before
  answering; don't let Docker mark it unhealthy for a slow boot.
- **`WORKDIR /app` is THE invariant:** CWD = /app = repo root, so `./configs/...`,
  `./artifacts`, `./.models` paths and `from ai_engine...` imports all resolve.
