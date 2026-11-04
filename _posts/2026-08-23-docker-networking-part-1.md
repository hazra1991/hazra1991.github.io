---
layout: post
title: "Docker Networking (Part 1): How a Request Reaches Your Container"
date: 2026-08-23
description: "Docker networking from scratch: how a container gets its own network and IP, how traffic gets out and in, why the app must bind 0.0.0.0, how to keep nginx in front, and what really changes between bridge and host networking."
categories: [Deployment, Docker]
tags: [docker, networking, nginx]
---

> **Docker series:** [1. Docker: A Practical Approach]({{ site.posts | where: "slug", "docker-a-practical-aproach" | first.url | relative_url }}) · [2. Deployment in Practice]({{ site.posts | where: "slug", "docker-deployment-in-practice" | first.url | relative_url }}) · **3. Networking Part 1** · [4. Networking Part 2: Subnets, IP Collisions and the Default Bridge]({{ site.posts | where: "slug", "docker-networking-part-2" | first.url | relative_url }})
{: .prompt-info}

<details>
<summary><strong>📑 Table of Contents</strong></summary>
<div markdown="1">

- [What problem Docker networking solves](#what-problem-docker-networking-solves)
- [1. A container has its own network](#1-a-container-has-its-own-network)
- [2. How the container is wired to the host: the bridge](#2-how-the-container-is-wired-to-the-host-the-bridge)
  - [Network modes at a glance](#network-modes-at-a-glance)
- [3. The way out: outbound NAT](#3-the-way-out-outbound-nat)
- [4. The way in: publishing ports](#4-the-way-in-publishing-ports)
  - [Which port does nginx point to?](#which-port-does-nginx-point-to)
- [5. Why the app inside MUST bind `0.0.0.0`](#5-why-the-app-inside-must-bind-0000)
  - [Isn't `0.0.0.0` insecure?](#isnt-0000-insecure)
  - [What if I run uvicorn without Docker?](#what-if-i-run-uvicorn-without-docker)
- [6. Putting it together: the full request chain](#6-putting-it-together-the-full-request-chain)
- [7. The other mode: host networking](#7-the-other-mode-host-networking)
  - [So is it 9090 or 8080 now?](#so-is-it-9090-or-8080-now)
  - [Why do people recommend `bridge` instead of just using `host`?](#why-do-people-recommend-bridge-instead-of-just-using-host)
  - [Does host networking harm the host?](#does-host-networking-harm-the-host)
- [8. Who manages what](#8-who-manages-what)
- [TL;DR](#tldr)

</div>
</details>

---

## **What problem Docker networking solves**

A container is just a process on the host, but Docker deliberately **isolates** it, and that includes its network. The container gets its own network interfaces, its own IP address and even its own `localhost`. That isolation is useful (containers can't trip over each other's ports), but it immediately raises three questions:

1. **What network does the container actually have?** What is its IP, and where does it come from?
2. **How does it get out?** Your app needs to call APIs, pull packages, go through the corporate proxy.
3. **How do requests get in?** Users, or nginx on the host, need to reach the app inside.

Everything in this post answers one of those three. The running example is a real setup: a **FastAPI app (uvicorn) in a container** on an Ubuntu server, with **nginx on the host** in front of it. By the end you'll be able to follow a request hop by hop from the browser to the app, and know why each hop behaves the way it does.

---

## **1. A container has its own network**

Linux has a feature called a **network namespace**: a separate, private copy of the network stack, with its own interfaces, IP addresses, routing table and ports. Docker puts every container (in the default mode) into its own namespace.

You can see it directly:

```bash
docker run --rm alpine ip addr
```

```text
1: lo: <LOOPBACK,UP> ...
    inet 127.0.0.1/8 scope host lo
2: eth0@if12: <BROADCAST,MULTICAST,UP> ...
    inet 172.17.0.3/16 brd 172.17.255.255 scope global eth0
```

So inside the container there are (at least) two interfaces:

- `lo`: `127.0.0.1`, reachable **only from inside the container**
- `eth0`: e.g. `172.17.0.3`, the container's address on the Docker network. **This is how Docker's port forwarding reaches it.**

> **The key idea of this whole post:** the container's `127.0.0.1` is *not* the host's `127.0.0.1`. There are two separate loopbacks. "localhost" inside a container means "this container only".
{: .prompt-tip}

---

## **2. How the container is wired to the host: the bridge**

A private network on its own is useless; it has to connect to something. By default Docker connects containers to a **bridge**, a virtual network switch living on the host:

```text
 Host
 ┌──────────────────────────────────────────────────────────┐
 │                                                          │
 │   ens192 (real NIC, host IP)                             │
 │      ▲                                                   │
 │      │ NAT                                               │
 │   docker0  172.17.0.1   ← virtual switch + gateway       │
 │      │            │                                      │
 │   vethA         vethB    ← virtual "cables"              │
 │      │            │                                      │
 │ ┌────┴─────┐ ┌────┴─────┐                                │
 │ │ eth0     │ │ eth0     │                                │
 │ │172.17.0.2│ │172.17.0.3│  ← each container's namespace  │
 │ └──────────┘ └──────────┘                                │
 └──────────────────────────────────────────────────────────┘
```

- `docker0` is the default bridge. It has an IP of its own (`172.17.0.1`), which is the **gateway** for the containers.
- Each container is plugged in with a **veth pair**: a virtual cable with one end inside the container (seen as `eth0`) and the other end on the host, attached to `docker0`.
- Each container gets an IP from the bridge's subnet (`172.17.0.0/16` by default).

You can see the host side of this with `ip -br addr`: `docker0`, plus one `veth...` per running container.

> Where that `172.17.0.0/16` subnet comes from, why Compose projects get *their own* bridges (`br-xxxx`) with other subnets, and how those subnets can collide with a corporate network, is the subject of [Part 2]({{ site.posts | where: "slug", "docker-networking-part-2" | first.url | relative_url }}).
{: .prompt-info}

### **Network modes at a glance**

The bridge is the default, but not the only option:

| Mode | What the container gets | Typical use |
|---|---|---|
| **bridge** (default) | Own namespace, own IP on a Docker bridge, NAT to the outside | Almost everything |
| **host** | **No** own namespace: shares the host's network stack directly | Workaround when bridging is broken; raw network performance |
| **none** | Own namespace with only `lo`; no connectivity at all | Fully isolated jobs |

(Compose projects use a *user-defined* bridge, which is the same idea with its own subnet and built-in DNS by service name. Overlay and macvlan networks also exist, for multi-host and special cases, and aren't needed here.)

Sections 3–6 are all about **bridge** mode. Host mode gets its own section at the end, because it changes almost every rule.

---

## **3. The way out: outbound NAT**

When the app calls an external API, the packet leaves `eth0` with source address `172.17.0.3`. Nobody outside knows that private address, so on its way out through the host's real NIC Docker **NATs** it (source NAT / "masquerade"): the source becomes the **host's own IP**. Replies come back to the host, and Linux translates them back to the container.

```text
container 172.17.0.3 ──▶ docker0 ──▶ NAT: source = host IP ──▶ ens192 ──▶ outside
```

Two consequences worth remembering:
- The outside world only ever sees the **host's IP**, never container IPs.
- Because addresses are translated at the host, bridge subnets are **local to each host**. Two servers can use the same container subnet without conflict.

Docker sets this up automatically with iptables rules. You don't configure anything for the way out.

---

## **4. The way in: publishing ports**

The way in is the opposite problem: a request arrives at the **host's** IP, and has to be forwarded to a container IP that nobody outside can see. That's what **publishing a port** does:

```bash
docker run -p 9090:8080 my-fastapi-image
```

`-p HOST:CONTAINER` → `-p 9090:8080` means "host port 9090 → container port 8080". Docker installs a forwarding rule (destination NAT): anything arriving at host port `9090` is rewritten to `172.17.0.3:8080` and delivered through the bridge.

```text
client ──▶ host:9090 ──▶ Docker forwards ──▶ 172.17.0.3:8080 (container eth0) ──▶ app
```

> Under the hood there are two forwarders: iptables NAT rules for traffic arriving from the network, and a small `docker-proxy` process for traffic from the host itself (e.g. `127.0.0.1:9090`). That's why `ss -tlnp` on the host shows `docker-proxy` listening on `9090`.
{: .prompt-info}

### **Which port does nginx point to?**

**nginx's `proxy_pass` uses the HOST port**, never the container port. nginx runs on the host, and on the host only `9090` exists. `8080` exists only inside the container's namespace.

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:9090;   # ← published HOST port
}
```
{: file="/etc/nginx/sites-enabled/my-app"}

---

## **5. Why the app inside MUST bind `0.0.0.0`**

Now the piece that trips everyone up. Docker forwards traffic to the **container's IP (`eth0`)**, not its loopback. So what the app listens on decides whether the forwarded traffic finds anyone:

- App binds `127.0.0.1:8080` → listens only on the container's loopback → forwarded traffic arrives on `eth0` → nobody listening → **connection refused**. The app looks "up" but is unreachable.
- App binds `0.0.0.0:8080` → listens on `lo` **and** `eth0` → forwarded traffic accepted ✅

```text
                     container network namespace
                 ┌──────────────────────────────────┐
 Docker NAT ───▶ │ eth0 172.17.0.3:8080             │
                 │                                  │
                 │ lo   127.0.0.1:8080  ◀── app bound here only?
                 └──────────────────────────────────┘    → eth0 has no listener → refused
```

```dockerfile
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```
{: file="Dockerfile"}

> **Classic symptom:** `docker logs` shows `Uvicorn running on http://127.0.0.1:8080`, `docker ps` shows the container as Up, and `curl localhost:9090` on the host gives `connection reset` or `empty reply`. The app is fine. It just listens on the wrong interface.
{: .prompt-warning}

`localhost` only makes sense for something that must **never** be reached from outside its own machine/namespace (e.g. a helper daemon).

### **Isn't `0.0.0.0` insecure?**

`0.0.0.0` inside the container is normal and safe. Binding it *inside* the container doesn't decide what's reachable from outside. That depends on:
- (a) the Docker **port mapping** (only published ports are exposed),
- (b) the **host firewall**,
- (c) **nginx** in front.

> The real exposure is on the **host** side. `-p 9090:8080` publishes on the host's `0.0.0.0:9090`, so it's reachable from the network **directly, bypassing nginx**. Docker's iptables rules can also bypass `ufw`: the forwarding from section 4 happens in rules that run before `ufw`'s, so a `ufw deny 9090` does **not** block a published port.
{: .prompt-danger}

To force all traffic through nginx, bind the published port to the host loopback:

```bash
docker run -p 127.0.0.1:9090:8080 my-fastapi-image
```

```yaml
ports:
  - "127.0.0.1:9090:8080"
```
{: file="docker-compose.yml"}

Now only nginx (on the same host) can reach it. Check what the host actually listens on:

```bash
ss -tlnp | grep 9090
# 0.0.0.0:9090    → reachable from the network
# 127.0.0.1:9090  → only from this host (nginx)
```

### **What if I run uvicorn without Docker?**

```bash
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Here `127.0.0.1` is actually the *better* choice: nginx is on the same machine, so it can reach loopback, and nobody else can bypass nginx.

> **The rule flips in a container**, because "same machine" for the container means "inside the container" (section 1: two separate loopbacks).
{: .prompt-tip}

| Where the app runs | Bind to | Why |
|---|---|---|
| Directly on the host, behind nginx | `127.0.0.1` | nginx shares the loopback; no one can bypass nginx |
| Inside a container (bridge) | `0.0.0.0` | Docker forwards to the container's `eth0`; restrict exposure with `127.0.0.1:` on the **published** port instead |

---

## **6. Putting it together: the full request chain**

Every hop is now explained, so here is the whole path in one picture:

```text
Internet / internal network
        │
        ▼
   ┌─────────────────────────────────┐
   │  Host machine (Ubuntu)          │
   │                                 │
   │  nginx (port 80)                │  ← systemd-managed, pre-installed
   │    │  proxy_pass to             │
   │    │  127.0.0.1:<host port>     │
   │    ▼                            │
   │  Docker published port          │  ← e.g. -p 127.0.0.1:9090:8080
   │    │  forwards to               │
   │    ▼                            │
   │  ┌─────────────────────────┐    │
   │  │ Container (172.17.0.3)  │    │
   │  │ FastAPI on 0.0.0.0:8080 │    │
   │  └─────────────────────────┘    │
   └─────────────────────────────────┘
```

1. Request arrives at host port 80 → nginx.
2. nginx matches `location /api/` → `proxy_pass http://127.0.0.1:9090` (the **published host port**, section 4).
3. Docker forwards host `9090` → container IP `172.17.0.3` port `8080` (section 4).
4. uvicorn inside the container, bound to `0.0.0.0:8080`, accepts it (section 5).
5. Response travels back: container → Docker → nginx → browser.

When something breaks, walk the same chain and check each hop: is nginx pointing at the right host port? Is the port published (`ss -tlnp`)? Is the app bound to `0.0.0.0` (`docker logs`)?

---

## **7. The other mode: host networking**

Everything above is **bridge** mode, Docker's default. You'll meet host mode too, usually as a workaround when bridge networking is broken on a host (see [Part 2]({{ site.posts | where: "slug", "docker-networking-part-2" | first.url | relative_url }})).

### **What `host` networking actually does**
`network_mode: host` (run) and `--network=host` (build) mean the same thing: the
container/build **shares the host's network stack directly**. No `docker0` bridge, no NAT,
no private `172.17.x` IP. The process uses the host's interfaces, IPs, and routing table as
if it were a normal process on the machine. In terms of section 1: there is **no separate namespace**.

```yaml
services:
  my-app:
    network_mode: host
```
{: file="docker-compose.yaml"}

### **So is it 9090 or 8080 now?**

This app's `uvicorn` binds **`8080` inside the container**. What the host sees depends on the mode:

| Mode | What happens | Reach the app at |
|---|---|---|
| **bridge** (default, `ports: "9090:8080"`) | Container has its own IP; Docker does **NAT** translating host `9090` → container `8080` | `http://<host>:9090` |
| **host** (`network_mode: host`) | No container IP, **no NAT**; app binds the host's real `8080` directly | `http://<host>:8080` |

So:
- **Bridge:** app on `8080` inside → Docker maps it → host exposes `9090`. The `9090:8080`
  line does that translation.
- **Host:** the `9090:8080` mapping is **ignored**; the app is on the host's `8080`.

This is official Docker behaviour. In host mode Docker even prints:
```text
WARNING: Published ports are discarded when using host network mode
```
> Docs: "if you run a container which binds to port 80 and you use `host` networking, the
> container's application is available on port 80 on the host's IP address … port mapping
> doesn't take effect, and the `-p`, `--publish`, `-P` … options are ignored."

**To expose a different external port in host mode** there is no mapping layer, so you must
change the port the **app itself** binds, i.e. edit the `uvicorn ... --port 8080` in the
Dockerfile `CMD` (e.g. to `--port 9090`). Remember to update nginx's `proxy_pass` to match.

> In host mode, section 5's rule flips back: the container's `127.0.0.1` **is** the host's loopback. Binding `127.0.0.1` works with nginx on the same host, and `0.0.0.0` now means *every host interface*.
{: .prompt-info}

### **Why do people recommend `bridge` instead of just using `host`?**
`host` is simpler and faster, but it removes the isolation that Docker exists to provide.
`bridge` is the default for good reasons:

- **Port isolation / no clashes.** On `bridge`, each container has its own IP, so ten
  containers can all listen on `8080` internally and you map them to different host ports
  (`9090:8080`, `9091:8080`, …). On `host`, they'd all fight over the host's real `8080`.
- **Network isolation / security.** A bridged container only sees what you expose. A
  host-networked container can see **all** host interfaces and loopback services (databases,
  admin ports) that were never meant to be reachable from a container → bigger attack surface.
- **Portability.** `bridge` behaves the same everywhere. `host` networking is a **Linux**
  feature: on Docker Desktop for Mac/Windows it is only available as an opt-in setting in
  recent versions (4.34+), so don't assume it behaves identically there.
- **Clean teardown.** Bridged containers have self-contained virtual interfaces that vanish
  with the container. Host mode leaks nothing but offers no boundary either.

> **Rule of thumb:** use `bridge` (the default) in normal operation; reach for `host` only as
> a workaround when the bridge is broken/disabled, or when you specifically need raw host
> network performance or access.
{: .prompt-tip}

### **Does host networking harm the host?**
No. It does **not** modify the host's networking or create the risky `docker0` subnet.
It simply lets the container *use* the host's existing, already-working network. That's why
it's the **safe** workaround when the bridge is disabled, unlike re-enabling the default bridge
(which recreates `172.17.0.0/16` and can collide with corporate routing, see
[Part 2]({{ site.posts | where: "slug", "docker-networking-part-2" | first.url | relative_url }})).
The only trade-offs are the **isolation losses** listed above (shared ports, broader visibility),
not host breakage.

---

## **8. Who manages what**

On a shared or company-provisioned server, it helps to know which pieces are yours:

| Thing | Managed by | My responsibility? |
|---|---|---|
| nginx install + unit file | platform/provisioning, systemd | no |
| nginx site config (`sites-enabled/my-app`) | me (with sudo) | yes |
| Docker container / uvicorn | me | yes |
| Port alignment (`proxy_pass` ↔ published port) | me | yes |
| `--host 0.0.0.0` in container | me | yes |

---

## **TL;DR**

- A bridged container has its **own network namespace**: its own `eth0` IP and its own `127.0.0.1`.
- **Out:** Docker NATs container traffic to the host's IP. **In:** a published port (`-p HOST:CONTAINER`) forwards host traffic to the container's `eth0`.
- nginx points at the **host** port. The app inside binds **`0.0.0.0`**; binding `127.0.0.1` makes it unreachable.
- Restrict exposure on the **published** port (`127.0.0.1:9090:8080`), not inside the container. Don't rely on `ufw` for published ports.
- Host mode: no namespace, no NAT, `ports:` ignored, the app's own port is the host port.
