---
layout: post
title: "systemd, systemctl and Service Files — A Clear Mental Model"
date: 2026-09-21
description: "A no-black-box reference: what systemd is, what a service is, where .service files live and how systemd finds them, name collisions, enable vs start, symlinking your own unit files, drop-in overrides, service types (simple, oneshot, notify) and cron vs systemd timers."
categories: [Linux, Administration]
tags: [systemd, linux, cron, cheatsheet]
---

A no-black-box reference. Read this top to bottom once and the whole thing clicks: what systemd is, what a service is, where `.service` files live, how systemd finds them, name collisions, `enable` vs `start`, symlinking your own service files, drop-in overrides, service types and timers. Real examples from an actual machine throughout.

<details>
<summary><strong>📑 Table of Contents</strong></summary>
<div markdown="1">

- [1. What problem does systemd solve?](#sec-1)
- [2. What is a "service"?](#sec-2)
- [3. What is a `.service` file?](#sec-3)
  - [Example: `devicehub-api.service`](#sec-3-1)
  - [What each section means](#sec-3-2)
- [4. Where do `.service` files live, and how does systemd find them?](#sec-4)
  - [The two hard rules](#sec-4-1)
- [5. Name collisions & priority](#sec-5)
- [6. What is `systemctl`?](#sec-6)
  - [How `enable` really works (the symlink)](#sec-6-1)
- [7. `enable` vs `start` vs `--now`](#sec-7)
- [8. How this all ties together: the nginx reverse-proxy picture](#sec-8)
- [9. Is creating a `.service` file "installing an application"?](#sec-9)
- [10. Keeping your `.service` file in your own repo (the symlink trick)](#sec-10)
  - [Can you point systemd at arbitrary custom directories?](#sec-10-1)
- [11. Drop-in overrides — customizing a package's service *without* editing its file](#sec-11)
  - [The problem drop-ins solve](#sec-11-1)
  - [What a drop-in actually is](#sec-11-2)
  - [How does systemd know to look? Is it automatic?](#sec-11-3)
  - [Merging vs overriding — the tricky part (`ExecStart`)](#sec-11-4)
  - [The easy way to create a drop-in](#sec-11-5)
  - [Don't forget to apply it](#sec-11-6)
- [12. Service types (`Type=`) — simple, oneshot, notify, and the default rule](#sec-12)
  - [What is the default if you omit `Type=`?](#sec-12-1)
  - [The three types you'll actually meet](#sec-12-2)
  - [Deep dive: how `Type=notify` actually works (the mechanism)](#sec-12-3)
  - [Wiring `notify` into a FastAPI app (devicehub example)](#sec-12-4)
  - [⚠️ The `NotifyAccess` gotcha (bites `uv run` / wrapper setups)](#sec-12-5)
  - [Should you bother with `notify`?](#sec-12-6)
- [13. Scheduled jobs — cron vs systemd timers (and what "migrated to systemd" means)](#sec-13)
  - [There are two separate schedulers on a Linux box](#sec-13-1)
  - [What does "migrated to systemd" actually mean?](#sec-13-2)
  - [Was any of this automatic?](#sec-13-3)
  - [What the two files look like](#sec-13-4)
  - [Two things to burn into memory](#sec-13-5)
  - [Where do `.timer` files live?](#sec-13-6)
  - [Why teams bother moving cron → systemd](#sec-13-7)
  - [What you can do with it (the split: enable the timer, start the service)](#sec-13-8)
- [14. One-page cheat sheet](#sec-14)

</div>
</details>

---

## 1. What problem does systemd solve? {#sec-1}

Think about what happens when your Ubuntu machine boots up. Dozens of things need to start: the networking stack, the SSH server so you can log in remotely, Docker, your display manager, time synchronization, and so on. Somebody has to orchestrate all of that — decide what starts first, what depends on what, restart things that crash, and collect their logs.

Before systemd existed, Linux used simple shell scripts (called "init scripts") for this, and they were fragile, slow, and hard to manage.

**systemd is the first process that runs when your Linux machine boots.** It literally has process ID **1**. It is *not* something you installed — it came baked into Ubuntu. It is the "init system," meaning it is responsible for initializing everything else on your machine. Every single process on your system is either systemd itself or something that systemd (directly or indirectly) started.

> **Mental model:** systemd is the operating system's project manager. It reads a bunch of configuration files that describe *what* needs to run, *how* to run it, and *when* to run it — then it manages all of that for the lifetime of the machine.
{: .prompt-tip}

---

## 2. What is a "service"? {#sec-2}

A "service" is just systemd's word for a long-running background process — what Unix people traditionally call a **daemon**.

- Your SSH server is a service.
- Docker is a service.
- Nginx is a service.
- Your devicehub FastAPI app is a service.

The key idea: a service is a program that should **start, keep running in the background, and ideally restart if it crashes** — without anyone manually typing commands in a terminal.

**Why you need this:** when you run

```bash
uvicorn devicehub_api.api.app:app --host 127.0.0.1 --port 8000
```

by hand in a terminal, it works — but the moment you close that terminal or log out, the process dies. A service file tells systemd *"run this command for me, keep it alive, and start it automatically on boot."*

---

## 3. What is a `.service` file? {#sec-3}

A `.service` file is just a **plain-text configuration file** — nothing more. It is not a script, it is not compiled code, it is not an application. It is a *declarative description* that tells systemd: here is the command to run, here is which user to run it as, here is what it depends on, and here is what to do if it fails. That's the entire idea.

### Example: `devicehub-api.service` {#sec-3-1}

Located at `/etc/systemd/system/devicehub-api.service`:

```ini
[Unit]
Description=Devicehub FastAPI Backend
After=network.target

[Service]
Type=simple
User=user01
WorkingDirectory=/home_ldap/user01/workspace/devicehub-backend
ExecStart=/usr/local/bin/uv run uvicorn devicehub_api.api.app:app --host 127.0.0.1 --port 8000
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### What each section means {#sec-3-2}

**`[Unit]` — metadata.**
- `Description` is a human-readable label (this is the "Devicehub FastAPI Backend" you see in `systemctl status` output).
- `After=network.target` means *"don't start this until networking is up,"* because your API server needs a network to listen on. This is how systemd handles **ordering and dependencies**.

**`[Service]` — the actual runtime configuration.**
- `ExecStart` is the command systemd will execute — the *exact same command* you'd type in a terminal.
- `WorkingDirectory` is the directory systemd `cd`s into before running that command.
- `User` tells it which Linux user to run as.
- `Restart=on-failure` means if the process crashes (exits non-zero), systemd automatically restarts it.

**`[Install]` — *when* this service should start.**
- `WantedBy=multi-user.target` means *"start this service when the system reaches the normal multi-user runlevel"* — in practical terms, during a normal boot, after the system is basically up and running.
- **This section only matters when you run `systemctl enable`** (more on that below).

---

## 4. Where do `.service` files live, and how does systemd find them? {#sec-4}

systemd looks in **specific directories**, and the location matters because it determines **priority**. There are three main places:

| Directory | Who owns it | Purpose |
|---|---|---|
| `/usr/lib/systemd/system/` | Packages (`apt`) | Where installed software drops its service files. **Never edit these** — package updates overwrite them. |
| `/etc/systemd/system/` | You (the admin) | Your own service files and overrides. **Highest priority.** |
| `/run/systemd/system/` | Runtime | Generated units that don't survive a reboot. Rarely touched directly. |

When you ran `sudo apt install nginx`, the nginx package dropped `nginx.service` into `/usr/lib/systemd/system/`. Your `devicehub-api.service` sits in `/etc/systemd/system/` because it's *your* app.

### The two hard rules {#sec-4-1}

1. **The file must end in `.service`.** That's how systemd knows it describes a service, as opposed to a `.timer`, `.socket`, `.mount`, or other unit type.
2. **It must be in one of these directories** for systemd to find it. You can't just put a `.service` file in your home directory and expect it to work.

The filename, minus the `.service` extension, becomes the **unit name** you use in all `systemctl` commands (e.g. `devicehub-api`).

---

## 5. Name collisions & priority {#sec-5}

**The filename *is* the identity.**

If you create `/etc/systemd/system/nginx.service`, it will **shadow (override)** the `/usr/lib/systemd/system/nginx.service` that came with the package. systemd uses a clear priority order:

```
/etc/systemd/system/   >   /run/systemd/system/   >   /usr/lib/systemd/system/
      (wins)                                              (lowest)
```

Within the *same* directory you simply cannot have two files with the same name — the filesystem prevents it. So the name you choose for your `.service` file is essentially a **unique identifier on that machine**.

---

## 6. What is `systemctl`? {#sec-6}

If systemd is the **engine**, `systemctl` is the **steering wheel**. It's the command-line tool you use to talk to systemd.

| Command | What it actually does |
|---|---|
| `systemctl start devicehub-api` | Run the `ExecStart` command **right now**. Process starts in the background; systemd tracks it. |
| `systemctl stop devicehub-api` | Send a termination signal to the process and clean up. |
| `systemctl enable devicehub-api` | **Does not start anything.** Creates a symlink in `multi-user.target.wants/` so the service starts automatically **on boot**. |
| `systemctl disable devicehub-api` | Removes that symlink (won't start on boot). Does *not* stop a running instance. |
| `systemctl daemon-reload` | *"I changed a `.service` file on disk — re-read it."* Required after editing any unit file. |
| `systemctl status devicehub-api` | Show whether it's running, its PID, memory, CPU time, and the last few log lines. |

> **Why `daemon-reload` exists:** systemd caches unit file contents in memory. After editing a service file (or a drop-in), you must run `daemon-reload` before the change takes effect.
{: .prompt-info}

### How `enable` really works (the symlink) {#sec-6-1}

`systemctl enable` creates a symlink from `multi-user.target.wants/devicehub-api.service` back to your service file. That symlink is how systemd knows *"when I reach multi-user.target during boot, I should also start devicehub-api."*

Those `*.target.wants/` directories you see (like `multi-user.target.wants/`, `sockets.target.wants/`) are full of exactly these symlinks — one per service that should activate at that stage.

---

## 7. `enable` vs `start` vs `--now` {#sec-7}

This trips everyone up, so here it is cleanly:

- **`enable`** = "start on **boot**" (creates the symlink, nothing more). Does **not** start it now.
- **`start`** = "start **right now**" (this instant). Does **not** survive a reboot.
- **`--now`** = "do **both**."

So this single command:

```bash
sudo systemctl enable --now devicehub-api.service
```

is just shorthand for:

```bash
sudo systemctl enable devicehub-api.service   # start on boot
sudo systemctl start  devicehub-api.service   # start right now
```

People use `enable --now` when setting up a new service for the first time and they want it running immediately **and** surviving reboots.

The reverse works too:

```bash
sudo systemctl disable --now devicehub-api.service   # stop now AND remove from boot
```

---

## 8. How this all ties together: the nginx reverse-proxy picture {#sec-8}

Here's what you actually set up, conceptually:

1. **Your FastAPI app (devicehub)** is a Python web server listening on `127.0.0.1:8000`. The `127.0.0.1` matters — it means *"only accept connections from this machine itself."* Nobody on the outside network can reach port 8000 directly.

2. **Nginx** is a separate service (also managed by systemd, from the package-installed `/usr/lib/systemd/system/nginx.service`). It listens on port **80/443** (standard HTTP/HTTPS), which *are* reachable from the outside. In your nginx config, a `proxy_pass` directive says *"forward incoming requests to `http://127.0.0.1:8000`."* Nginx is acting as a **reverse proxy** — a middleman.

The request flow:

```
Browser  →  nginx (port 80/443, public)  →  FastAPI app (port 8000, local only)
```

This is a standard deployment pattern because nginx handles things your Python app shouldn't worry about: SSL termination, serving static files efficiently, load balancing, rate limiting, and buffering slow clients.

Both nginx and devicehub are just **two background processes systemd babysits**: started at boot, restarted on crash, inspectable with `systemctl status`, logs in the journal (`journalctl`).

> The nginx side of this picture (how its package starts it, master and workers, `proxy_pass`) is the [Nginx series]({{ site.posts | where: "slug", "nginx-part-1" | first.url | relative_url }}).
{: .prompt-info}

---

## 9. Is creating a `.service` file "installing an application"? {#sec-9}

**No.** Creating a `.service` file does not install anything.

Your application code (the FastAPI project in `/home_ldap/user01/workspace/devicehub-backend/`) is already on disk. The `.service` file is *purely configuration* telling systemd how to run that code as a managed background process.

> **Analogy:** The `.service` file is a **recipe card**. The recipe card doesn't create the food — the food (your code) already exists. The card just tells the chef (systemd) how to prepare and serve it.
{: .prompt-tip}

When you `apt install nginx`, the package does **two things**:
1. Installs the nginx binary + config (the actual application).
2. Drops a `.service` file so systemd knows how to manage it.

For *your own* apps you do those two steps separately: put your code somewhere, then write a `.service` file to tell systemd about it.

> **Core insight:** systemd doesn't care what your app is, what language it's in, or how it works internally. It only cares about the command to start it, the user to run it as, and what to do if it fails. That's the entire contract between systemd and your application.
{: .prompt-tip}

---

## 10. Keeping your `.service` file in your own repo (the symlink trick) {#sec-10}

You can keep your `.service` file inside your project repository (so it's **version-controlled alongside your code**) and symlink it into `/etc/systemd/system/`.

```bash
# Your actual file lives in your project
/home_ldap/user01/workspace/devicehub-backend/devicehub-api.service

# Create a symlink where systemd expects to find it
sudo ln -s /home_ldap/user01/workspace/devicehub-backend/devicehub-api.service \
           /etc/systemd/system/devicehub-api.service

# Tell systemd to re-read
sudo systemctl daemon-reload
```

systemd follows the symlink and reads the file from your project directory. Update the file in your repo → `systemctl daemon-reload` → changes picked up. No copying.

**This pattern is already all over your machine.** These lines from `/etc/systemd/system/` are symlinks:

```
redis.service -> /usr/lib/systemd/system/redis-server.service
sshd.service  -> /usr/lib/systemd/system/ssh.service
chronyd.service -> /usr/lib/systemd/system/chrony.service
```

Same mechanism — here the package manager uses it to create aliases (e.g. making `sshd.service` point to `ssh.service`).

### Can you point systemd at arbitrary custom directories? {#sec-10-1}

**No.** systemd scans a *fixed* set of directories (`/etc/systemd/system/`, `/usr/lib/systemd/system/`, `/run/systemd/system/`, and a few others). There is no config option to add, say, `/home/user01/my-services/`. **The symlink approach is the intended solution** for keeping the file wherever you want while still having systemd see it.

Two related tools:

- **`systemctl link` makes that symlink for you:** `sudo systemctl link /home_ldap/user01/workspace/devicehub-backend/devicehub-api.service` puts the link into `/etc/systemd/system/`, and `disable` removes it again. Its man page states the same caveat as below: the file must be readable when systemd starts, so paths under `/home` are only safe if `/home` is on the root filesystem.
- **Per-user services** are the exception to "not from your home directory": unit files in `~/.config/systemd/user/` are found by your own user's systemd instance and managed with `systemctl --user start|enable|status <name>` (no `sudo`). They run as you and, by default, only while you're logged in (`loginctl enable-linger <user>` keeps them running after logout).

> **One caveat:** if the symlink target is on a network filesystem or inside an encrypted home directory that isn't mounted yet at early boot, systemd may fail to read it during startup. For a home dir on a local disk this is rarely an issue — but it explains the occasional "service not found after reboot" mystery.
{: .prompt-warning}

---

## 11. Drop-in overrides — customizing a package's service *without* editing its file {#sec-11}

This is one of the most useful systemd features. Example comes straight from Docker on your machine.

### The problem drop-ins solve {#sec-11-1}

Docker's service file lives at `/usr/lib/systemd/system/docker.service` and is **owned by the Docker package**. Every `apt upgrade` that updates Docker **overwrites** that file. So if you edited it directly to add proxy settings or change `ExecStart`, your changes get wiped on the next update.

You need a way to customize a package's service **without touching the package's own file.** That's what drop-ins are for.

### What a drop-in actually is {#sec-11-2}

A drop-in is a small `.conf` file in a specially-named directory next to the service, which systemd **automatically merges on top of** the original `.service` file.

**The directory naming convention is the rule, not arbitrary.** For a service called `docker.service`, the drop-in directory **must** be named:

```
docker.service.d
```

That is: take the full unit name (`docker.service`), append `.d`. The `.d` suffix is a common Linux convention meaning *"a directory of configuration fragments"* (you'll see it in `/etc/cron.d/`, `/etc/sudoers.d/`, etc.).

Inside that directory, **any file ending in `.conf`** gets picked up. The filenames themselves are free-form:

```
/etc/systemd/system/docker.service.d/
├── http-proxy.conf
└── override.conf
```

Both are merged on top of `/usr/lib/systemd/system/docker.service`.

### How does systemd know to look? Is it automatic? {#sec-11-3}

**Yes — completely automatic. There is no "register this drop-in" step.** When systemd loads a unit, it builds the final configuration by scanning a fixed set of locations **in order**, using the directory-naming convention to know what belongs to what. For `docker.service` it looks for `docker.service.d/` in each standard location:

```
/usr/lib/systemd/system/docker.service.d/   (package-provided drop-ins)
/run/systemd/system/docker.service.d/        (runtime)
/etc/systemd/system/docker.service.d/        (your admin overrides — highest priority)
```

It reads the main `.service` file first, then applies every `.conf` it finds in those `.d/` directories **on top**. The `.conf` files are applied in **alphanumeric order of filename**, regardless of which of these directories they are in (so `http-proxy.conf` before `override.conf`, because 'h' < 'o'). If the same filename exists in several of them, only the highest-priority copy is used (`/etc` beats `/run` beats `/usr/lib`). That order only matters when two drop-ins set the *same* directive — the later one wins.

The `Drop-In:` line in `systemctl status` is systemd literally telling you what it found and merged:

```
Drop-In: /etc/systemd/system/docker.service.d
         └─http-proxy.conf, override.conf
```

This merge happens every time the unit loads — at boot, and whenever you run `systemctl daemon-reload`.

### Merging vs overriding — the tricky part (`ExecStart`) {#sec-11-4}

Most directives are **replaceable**: if your drop-in sets a value, it replaces the original. (Set `Restart=on-failure` in a drop-in and it beats the original `Restart=always`.)

But some directives are **lists that append** rather than replace — and **`ExecStart` is the most important one.** If you just write a new `ExecStart=` in a drop-in, systemd tries to *add a second* startup command, which is an error for most service types. To genuinely **replace** it, you first **clear the list with an empty assignment**, then set your new value.

That's exactly what Docker's `override.conf` does:

```ini
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --bridge=none --host unix:///var/run/docker.sock --host tcp://0.0.0.0:2375
```

- The first line, `ExecStart=` with nothing after it, **resets/clears** the inherited `ExecStart`.
- The second line sets the real command you want.

Without that empty `ExecStart=` first line, you'd get an error. This **empty-then-set** pattern applies to all list-type directives (`ExecStart`, `ExecStartPre`, `Environment`, and a few others).

**Result:** the effective config of Docker = everything from the original `/usr/lib/systemd/system/docker.service`, **except** `ExecStart`, which is swapped for your custom one. That's why `systemctl status` shows Docker running with your flags (`--bridge=none`, `--host tcp://0.0.0.0:2375`) instead of the package default (`-H fd://`). The merge worked.

> **About `--host tcp://0.0.0.0:2375` itself:** that opens the Docker API **without any authentication** on every network interface. Anyone who can reach port 2375 can start containers, mount the host's filesystem, and so is effectively **root on this machine**. Keep it only on a trusted, firewalled network; otherwise bind it to `127.0.0.1`, or use port 2376 with TLS client certificates (`--tlsverify`).
{: .prompt-danger}

For reference, the package's original `docker.service` `[Service]` default was:

```ini
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
```

### The easy way to create a drop-in {#sec-11-5}

Don't hand-create the directory. systemd does it for you:

```bash
sudo systemctl edit docker.service
```

This automatically:
1. Creates `/etc/systemd/system/docker.service.d/override.conf` (that's where the default name `override.conf` comes from),
2. Opens it in an editor,
3. Runs `daemon-reload` for you on save.

A conventionally-named file like `http-proxy.conf` is usually created by hand or by a provisioning script, since that's the common name people give proxy-specific settings.

### Don't forget to apply it {#sec-11-6}

After adding/changing any drop-in **by hand**:

```bash
sudo systemctl daemon-reload      # re-read & re-merge the config
sudo systemctl restart docker     # apply the new ExecStart to the running process
```

- `daemon-reload` makes systemd re-read and re-merge.
- `restart` applies the new `ExecStart` to the actually-running daemon.

---

## 12. Service types (`Type=`) — simple, oneshot, notify, and the default rule {#sec-12}

Every `[Service]` has a `Type=`. It answers one question: **"How does systemd decide the service has finished starting?"** Different kinds of programs "become ready" in different ways, so systemd needs to know which readiness model to use. Get this wrong and systemd's idea of "started/active" won't match reality.

### What is the default if you omit `Type=`? {#sec-12-1}

A natural question: the devicehub and nginx files don't all spell out a `Type=`, so is the default `simple`? **Almost — but the real rule has a twist:**

- No `Type=` **and** you have an `ExecStart=` → defaults to **`simple`**.
- No `Type=` **and** you have **no** `ExecStart=` (only `ExecStartPre`/`ExecStartPost`) → defaults to **`oneshot`**.

So "no Type line = simple" is true *only* when there's an `ExecStart` (which is the usual case — that's why devicehub is effectively `simple`). But it isn't a universal law.

> **Don't rely on the default.** Write `Type=` explicitly. The file then documents its own intent and nobody has to remember these edge rules.
{: .prompt-tip}

> **Watch out — "no Type line" ≠ "always simple".** Your Docker unit sets `Type=notify` *explicitly*. It is neither simple nor defaulted. Always check for an explicit `Type=` before assuming.
{: .prompt-warning}

### The three types you'll actually meet {#sec-12-2}

| `Type=` | Shape of the program | systemd considers it "started" when… | Example |
|---|---|---|---|
| `simple` | Long-running daemon that **stays alive** in the foreground | …the instant `ExecStart` is launched (systemd does **not** check readiness) | devicehub API |
| `oneshot` | Runs, does its work, **exits** | …the process has **finished and exited** | a periodic sync/backup job fired by a timer |
| `notify` | Long-running daemon, but it **signals readiness** itself | …the app sends a `READY=1` message back to systemd | Docker |

(There are more — `forking`, `exec`, `dbus`, `idle` — but these three cover almost everything you'll touch.)

> **nginx is the `forking` case you'll meet.** Its packaged unit says `Type=forking`: nginx puts itself in the background (the started process forks and exits), and systemd then tracks the master through `PIDFile=`. The boot sequence step by step is in [Nginx Part 1, 4]({{ site.posts | where: "slug", "nginx-part-1" | first.url | relative_url }}#sec-4-5).
{: .prompt-info}

The key distinction between `simple` and `notify`: with `simple`, "active" just means "process launched." With `notify`, "active" means "the app told me it's genuinely ready to serve." That matters when other units depend on this one being truly up.

### Deep dive: how `Type=notify` actually works (the mechanism) {#sec-12-3}

With `notify`, systemd holds the service in an **"activating"** state and waits for the app to explicitly say *"I'm ready now"* before flipping it to **"active"** (and before starting anything that depends on it). So the app has to send a signal back. The wire protocol is simple and has **no magic**:

1. When `Type=notify`, systemd creates a **Unix-domain datagram socket** and passes its address to the process via an environment variable, **`NOTIFY_SOCKET`**.
2. Once the app finishes its startup work, it **sends a tiny datagram containing `READY=1`** to that socket. (The only value worth sending is `READY=1`; there is no "not ready" message.)
3. systemd receives it and marks the unit active. If it never arrives within the start timeout, the service is marked **failed**.

It's a stable, documented ABI that explicitly allows independent implementations — which is why some projects just write the datagram directly instead of linking a library. The **raw** version in Python (this is literally all a helper library does):

```python
import os, socket

addr = os.environ["NOTIFY_SOCKET"]
if addr.startswith("@"):          # "@" = abstract-namespace socket
    addr = "\0" + addr[1:]
sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
sock.sendto(b"READY=1\n", addr)
```

The **easy** version — use the small `sdnotify` library:

```python
import sdnotify
sdnotify.SystemdNotifier().notify("READY=1")
```

For shell/bash jobs there's even a wrapper: `systemd-notify --ready`.

### Wiring `notify` into a FastAPI app (devicehub example) {#sec-12-4}

Send `READY=1` **after** real startup is done (DB open, caches warm) — in FastAPI's lifespan startup hook. Uvicorn won't emit it for you:

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
import sdnotify

@asynccontextmanager
async def lifespan(app: FastAPI):
    # --- startup: connect DB, warm caches, etc. ---
    sdnotify.SystemdNotifier().notify("READY=1")   # NOW tell systemd we're ready
    yield
    # --- shutdown ---

app = FastAPI(lifespan=lifespan)
```

Unit file:

```ini
[Service]
Type=notify
NotifyAccess=all
ExecStart=/usr/local/bin/uv run uvicorn my_service.api.app:app --host 127.0.0.1 --port 8000
```

### ⚠️ The `NotifyAccess` gotcha (bites `uv run` / wrapper setups) {#sec-12-5}

Note that a wrapped launch has a **two-process tree**: the wrapper is the Main PID, the real app is its **child**:

```
├─ <MainPID>  /usr/local/bin/uv run uvicorn ...   ← Main PID (the wrapper, `uv`)
└─ <childPID> .../python .../uvicorn ...          ← the actual app (a CHILD)
```

By default **`NotifyAccess=main`** — systemd only accepts `READY=1` **from the Main PID**. But here the Main PID is the wrapper, while the thing that sends `READY=1` is the child. systemd ignores the child's message, never sees readiness, times out, and marks the service **failed** — the classic *"it's clearly running but systemd says failed"* trap. Two fixes:

- **Easiest:** `NotifyAccess=all` — accept the notification from any process in the service's cgroup (including the child).
- **Cleaner:** make the app the Main PID so the sender *is* the Main PID — run the venv's uvicorn directly (`ExecStart=/path/.venv/bin/uvicorn ...`) and drop the `uv run` wrapper, since the wrapper forks the app as a child rather than replacing itself.

### Should you bother with `notify`? {#sec-12-6}

For a single app behind nginx, **`Type=simple` is usually fine** — `notify` is extra moving parts. `notify` earns its keep when *something else depends on this service being truly ready*: e.g. another unit with `After=my-service.service` that must not start until the API can serve, or you want `systemctl restart` to block until the app is genuinely up. No such need → `simple` is the pragmatic choice.

---

## 13. Scheduled jobs — cron vs systemd timers (and what "migrated to systemd" means) {#sec-13}

So far every service has been a long-running process (devicehub API, nginx, Docker). But a lot of work is *periodic* instead — "run this every 5 minutes," "back up the DB at 3am." For that you need a **scheduler**, and Linux has **two different ones**.

### There are two separate schedulers on a Linux box {#sec-13-1}

**cron** is the old, traditional Unix scheduler. It's a daemon that wakes up every minute and checks a set of "crontab" files to see if any job is due. Each user can have their own crontab, stored at `/var/spool/cron/crontabs/<user>` (that's where files like `user02` and `root` live). A crontab line looks like this:

```
*/5 * * * *  cd /opt/... && make run_mgmt_cmd CMD='sync_inventory'
│   │ │ │ │
│   │ │ │ └─ day of week
│   │ │ └─── month
│   │ └───── day of month
│   └─────── hour
└─────────── minute   →  */5 = "every 5 minutes"
```

One line = **schedule + command**, all in one place. Simple, but limited.

**systemd timers** are the systemd-native way to schedule things. Here's the key mental shift: instead of one crontab line, a scheduled job becomes **two unit files** — the same `.service` idea you already know, plus a new `.timer` partner:

- The **`.service`** = *what to run* (the command).
- The **`.timer`** = *when to run it* (the schedule).

The timer "triggers" the service. That's the whole model.

> **Mental model:** cron and systemd timers are **two tools in the same category** — like two brands of alarm clock. A machine can run both at once. Many teams standardize on systemd and move jobs off cron.
{: .prompt-tip}

### What does "migrated to systemd" actually mean? {#sec-13-2}

It means **a human took the old cron line and recreated it as a `.timer` + `.service` pair**, then switched the cron line off. For a job called `my-service`, someone:

1. Created `/etc/systemd/system/my-service.service` — runs the command.
2. Created `/etc/systemd/system/my-service.timer` — fires every 5 minutes.
3. Enabled the timer: `sudo systemctl enable --now my-service.timer`.
4. **Commented out** the old cron line so cron stops running it.

That last step is why a migrated crontab line becomes dead text:

```
# MIGRATED-TO-SYSTEMD 2026-09-07: */5 * * * * cd /opt/... && make run_mgmt_cmd CMD='sync_inventory'
```

> **Important:** that `# MIGRATED-TO-SYSTEMD` prefix is **not a cron feature or a systemd feature — it's just a comment a person typed.** It's a breadcrumb convention a team uses so future-you can see "this used to run in cron, it's been moved, here's where it went." The leading `#` makes cron ignore the whole line. The job is no longer a cron job — it's a systemd timer now.
{: .prompt-info}

So, directly: **before the migration it *was* a cron job; after, it is *not* — it's a systemd timer+service.** "Moving it" means re-expressing the exact same schedule+command in systemd's format and turning off the cron version.

### Was any of this automatic? {#sec-13-3}

**No — none of it is automatic.** A person (or a deploy script a person wrote) created those two files, enabled the timer, and commented out the cron line. systemd does **not** "absorb" cron jobs on its own. The only automatic part happens *afterward*: once the timer is enabled, systemd fires it every 5 minutes forever — exactly like a service starts on boot.

### What the two files look like {#sec-13-4}

The **`.service`** (note `Type=oneshot` — this is the big difference from a long-running API):

```ini
[Unit]
Description=My service — periodic sync job

[Service]
Type=oneshot
WorkingDirectory=/opt/my-app/active_deployment
ExecStart=/usr/bin/make run_mgmt_cmd CMD=sync_inventory
```

The **`.timer`**:

```ini
[Unit]
Description=Run my-service every 5 minutes

[Timer]
# every 5 minutes
OnCalendar=*:0/5
# if the machine was off, run a catch-up on next boot
Persistent=true

[Install]
WantedBy=timers.target
```

### Two things to burn into memory {#sec-13-5}

**1. `Type=oneshot` vs `Type=simple`.** (Full type reference is in **Section 12**.)

| | `Type=simple` | `Type=oneshot` |
|---|---|---|
| Shape | Long-running daemon that **stays alive** | Runs, does its work, and **exits** |
| Example | devicehub API | a periodic sync/backup job |
| State most of the time | Active (running) | Inactive (dead) — the timer revives it on schedule |

A scheduled job is `Type=oneshot`: it's "dead" most of the time, and the timer brings it back to life every 5 minutes. That's the correct shape for a periodic task.

**2. The name pairing.** The timer and service share the **same base name** (`my-service.timer` ↔ `my-service.service`). That's how systemd knows they belong together — a `.timer` automatically triggers the `.service` with the identical name. (You *can* override this with a `Unit=` line in `[Timer]`, but by default it's name-matching.) This is also why you run `systemctl enable` on the **`.timer`**, not the service — you enable the *schedule*, and the schedule pulls the service.

### Where do `.timer` files live? {#sec-13-6}

**Exactly the same service-discovery paths as `.service` files** — nothing new to learn here. A `.timer` is just another unit type, so it obeys the same rules from Section 4:

```
/etc/systemd/system/      ← your timers & overrides (wins)      e.g. /etc/systemd/system/my-service.timer
/run/systemd/system/      ← runtime (ephemeral)
/usr/lib/systemd/system/  ← package-installed (never edit)
```

The only differences from a `.service`:
- The file ends in **`.timer`** instead of `.service` (that's how systemd knows it's a timer).
- Its `[Install] WantedBy=` is **`timers.target`** instead of `multi-user.target` — so `enable` wires it into the timer-activation stage rather than the normal boot stage. Same symlink mechanism (Section 6), different target directory (`timers.target.wants/`).

### Why teams bother moving cron → systemd {#sec-13-7}

The schedule is identical, so the payoff is everything *around* it:

- **Real logs.** `journalctl -u my-service.service` gives every run's output, exit code, and timestamp. With cron you'd get an email nobody reads, or you'd manually redirect to a log file.
- **Status at a glance.** `systemctl list-timers` shows next/last fire times; `systemctl status …service` tells you if the last run succeeded or failed.
- **Dependencies & ordering.** `After=`, `Requires=`, etc. — a timer can wait for the network or a database. Cron can't.
- **Catch-up runs.** `Persistent=true` reruns a missed job after downtime. Plain cron just skips it.
- **One management surface.** Your API, nginx, Docker, and scheduled jobs are all managed the same way with `systemctl` and `journalctl`.

### What you can do with it (the split: enable the timer, start the service) {#sec-13-8}

```bash
# See the exact definitions (schedule + command)
systemctl cat my-service.timer my-service.service

# Is the schedule live? next/last fire time?
systemctl list-timers --all | grep my-service
systemctl status my-service.timer

# Did the LAST run succeed or fail?
systemctl status my-service.service

# The per-run logs/failures — this is where a repeating error shows up
journalctl -u my-service.service --since today --no-pager

# Run it RIGHT NOW by hand (great for testing a fix) — start the .service, not the timer
sudo systemctl start my-service.service

# Stop the schedule entirely (e.g. while you fix something) — disable the .timer
sudo systemctl disable --now my-service.timer
```

> **Remember the split:**
> - You **enable/disable the `.timer`** → that controls the *schedule*.
> - You **start the `.service`** directly → that triggers *a single run on demand*.
> - You **read logs from the `.service`** → because that's the thing that actually runs and produces output.
{: .prompt-tip}

---

## 14. One-page cheat sheet {#sec-14}

**Concepts**
- **systemd** = PID 1, the init system / project manager. Starts & supervises everything.
- **service / daemon** = a long-running background process systemd manages.
- **`.service` file** = plain-text *recipe* telling systemd how to run something. Not an app, not a script.

**Where files live (priority high → low)**
```
/etc/systemd/system/      ← your files & overrides (wins)
/run/systemd/system/      ← runtime (ephemeral)
/usr/lib/systemd/system/  ← package-installed (never edit)
```

**Service file skeleton**
```ini
[Unit]
Description=...
After=network.target

[Service]
User=...
WorkingDirectory=...
ExecStart=...
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

**Everyday commands**
```bash
sudo systemctl start   <name>     # run now
sudo systemctl stop    <name>     # stop now
sudo systemctl enable  <name>     # start on boot (symlink)
sudo systemctl disable <name>     # don't start on boot
sudo systemctl enable --now  <name>   # boot + now
sudo systemctl disable --now <name>   # stop now + remove from boot
sudo systemctl restart <name>     # stop then start
systemctl status  <name>          # state, PID, memory, recent logs
sudo systemctl daemon-reload      # after editing any unit file / drop-in
journalctl -u <name> -f           # follow a service's logs
```

**Keep your service file in your repo**
```bash
sudo ln -s /path/in/your/repo/foo.service /etc/systemd/system/foo.service
sudo systemctl daemon-reload
```

**Override a package's service (drop-in)**
```bash
sudo systemctl edit <name>        # creates /etc/systemd/system/<name>.service.d/override.conf
# To replace ExecStart, clear it first:
#   [Service]
#   ExecStart=
#   ExecStart=/new/command --flags
sudo systemctl daemon-reload
sudo systemctl restart <name>
```

**Service types (`Type=`)**
```
simple   long-running, stays alive; "active" the moment ExecStart launches     (devicehub)
oneshot  runs → does work → exits; "active/done" once it finishes           (timer jobs)
notify   long-running, but the app sends READY=1 to systemd when truly ready   (Docker)

Default:  no Type + has ExecStart  → simple
          no Type + no  ExecStart  → oneshot
          (…but always check for an EXPLICIT Type= first — e.g. Docker sets Type=notify)
```
`Type=notify` mechanism:
```
systemd sets env NOTIFY_SOCKET  →  app sends datagram "READY=1" to it  →  systemd marks unit active
  Python:  sdnotify.SystemdNotifier().notify("READY=1")   (in FastAPI lifespan startup)
  Shell:   systemd-notify --ready
  Gotcha:  default NotifyAccess=main accepts READY=1 ONLY from the Main PID.
           With a `uv run ...` wrapper the app is a CHILD → use NotifyAccess=all
           (or run the app directly so it IS the Main PID).
```

**Scheduled jobs (cron vs systemd timers)**
```
cron            = old scheduler; one crontab line = schedule + command
                  files in /var/spool/cron/crontabs/<user>
                  format:  min hour day month weekday  command   (*/5 = every 5 min)

systemd timer   = two unit files, same discovery paths as .service:
                  <name>.service  → WHAT to run   (Type=oneshot, runs & exits)
                  <name>.timer    → WHEN to run   (WantedBy=timers.target)
                  same base name = auto-paired; timer triggers service

"migrated to systemd" = a HUMAN recreated the cron line as .timer + .service,
                        then commented out the cron line. Not automatic.
                        "# MIGRATED-TO-SYSTEMD ..." is just a human breadcrumb comment.
```
```bash
systemctl cat <name>.timer <name>.service     # schedule + command
systemctl list-timers --all | grep <name>     # next/last fire time
systemctl status <name>.service               # did the last run pass/fail?
journalctl -u <name>.service --since today     # per-run logs / repeating errors
sudo systemctl start <name>.service           # run ONE time now (test a fix)
sudo systemctl enable  --now <name>.timer     # turn the SCHEDULE on
sudo systemctl disable --now <name>.timer     # turn the SCHEDULE off
```

**Golden rules to remember**
- File must end in `.service` and live in a systemd dir (or be symlinked into one).
- Filename = unit name = unique identity; `/etc` shadows `/usr/lib`.
- `enable` ≠ `start`. `--now` = both.
- Drop-ins live in `<unit>.service.d/*.conf`, merged automatically, no registration.
- `ExecStart` needs empty-then-set to truly replace.
- Edited a unit or drop-in? → `daemon-reload` (+ `restart` to apply to the running process).
- **Types:** `Type=` tells systemd *how to know the service started*. `simple` = launched; `oneshot` = exited; `notify` = app sent `READY=1`. Default is `simple` (with `ExecStart`) / `oneshot` (without) — but **set it explicitly** and always check for an explicit `Type=`.
- **`Type=notify`:** app sends `READY=1` to `$NOTIFY_SOCKET`; with a `uv run` / wrapper setup use `NotifyAccess=all` or the child's signal is ignored.
- **Timers:** `.timer` + `.service` share a base name and the same discovery paths; periodic job = `Type=oneshot`; enable the `.timer`, start the `.service`, read logs from the `.service`.
- **Migration is a human act** — systemd never absorbs a cron job on its own; the `# MIGRATED-TO-SYSTEMD` line is just a comment.
