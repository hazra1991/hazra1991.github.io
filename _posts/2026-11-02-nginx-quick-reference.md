---
layout: post
title: "Nginx Refresher and Quick Reference"
date: 2026-11-02
description: "The whole nginx series on one page: every concept as short points with one annotated config each, in learning order, linked to the full explanations. Then the lookup tables: phases, directives, variables, commands and error-to-cause troubleshooting."
categories: [Deployment, Nginx]
tags: [nginx, cheatsheet, troubleshooting]
---

> **Nginx series:** [1. How Nginx Runs]({{ site.posts | where: "slug", "nginx-part-1" | first.url | relative_url }}) · [2. Routing Requests]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}) · [3. Internal Requests & Auth]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}) · [4. Gateway Auth in Practice]({{ site.posts | where: "slug", "nginx-part-4" | first.url | relative_url }}) · [Extra: Variables & Dynamic Proxy]({{ site.posts | where: "slug", "nginx-variables-and-dynamic-proxy" | first.url | relative_url }}) · **Refresher & Quick Reference**
{: .prompt-info}

Two pages in one:

- **The refresher** — the whole series, read top to bottom in about 15 minutes. Every concept is here as short points, with at most one small config, in the same order as the parts. Each heading links to the full explanation: open it only when a point no longer makes sense.
- **The lookup** — phases, directives, variables, commands, and error → cause, for when you know what you're looking for.

<details>
<summary><strong>📑 Table of Contents</strong></summary>
<div markdown="1">

- [The whole series in one picture](#r-picture)
- [Part 1 — How nginx runs](#r-part-1)
  - [Linux foundations](#r-linux) · [Two packages](#r-packages) · [systemd](#r-systemd) · [Master and workers](#r-workers) · [nginx.conf](#r-conf) · [include](#r-include)
- [Part 2 — Routing requests](#r-part-2)
  - [Which server block](#r-server-block) · [Phases](#r-phases) · [Locations](#r-location) · [Serving files](#r-files) · [Path rule](#r-path-rule) · [upstream](#r-upstream) · [Headers](#r-headers) · [Two deployments](#r-deployments) · [Browser and CORS](#r-browser) · [Docker](#r-docker) · [HTTPS](#r-https)
- [Part 3 — Internal requests and auth](#r-part-3)
  - [Internal requests](#r-internal) · [auth_request](#r-auth-request) · [Who checks](#r-who-checks) · [The flow](#r-auth-flow) · [Cookies and caching](#r-auth-cookies) · [Trust boundary](#r-trust) · [When it fits](#r-fits) · [Four messages](#r-messages)
- [Part 4 — Gateway auth in practice](#r-part-4)
  - [Design](#r-design) · [One session](#r-session) · [External services](#r-external)
- [Extra — Variables and a dynamic proxy](#r-extra)
- [Lookup](#lookup)
  - [Phases](#ref-phases) · [Directives](#ref-directives) · [Variables](#ref-variables) · [Commands](#ref-processes-service) · [Troubleshooting](#ref-troubleshooting)

</div>
</details>

---

## **The whole series in one picture** {#r-picture}

```
Browser ── DNS: name → IP ── TCP to IP:80/443 ── [HTTPS: TLS handshake, SNI picks the certificate]
   │
   ▼  HTTP request: method + path + Host header (+ Cookie, Authorization, ...)
nginx worker (forked by the root master, started by systemd)
   ├─ 1. server block   listen (IP:port), then server_name ← Host           Part 2 §8
   ├─ 2. location       exact / longest prefix / regex on the path          Part 2 §9.2
   ├─ 3. phases         rewrite (return, set) → access (auth_request)
   │                    → try_files → content                               Part 2, Part 3 §15.3
   └─ 4. content        file from disk (root / alias)
                        or proxy_pass / uwsgi_pass → a NEW request to a backend   Part 2 §9.3–9.9
   ▼
Response back the same way; nginx can add / hide headers on the way out     Part 3 §16
```

---

## **Part 1 — How nginx runs** {#r-part-1}

### **Linux foundations → [Part 1, 2]({{ site.posts | where: "slug", "nginx-part-1" | first.url | relative_url }}#sec-2)** {#r-linux}

- A process has a **PID**, a **PPID** (its parent) and an **owner**. The tree starts at systemd (PID 1). `fork()` copies a process — that's how the master creates workers. A daemon has no terminal (`?` in `ps`).
- `ps -ef | grep nginx` matches the **whole line**, including the user column. Real nginx only: `pgrep -a nginx`, `ps -C nginx -f`, `systemctl status nginx`.
  - *Q: why did it show uwsgi, celery, python on server 14?* They run as the **user** `nginx`; separate Django apps, not the web server.
- Signals: `HUP` reload · `QUIT` graceful stop · `TERM`/`INT` fast stop · `KILL` can't be caught. The PID file (`/run/nginx.pid`) says which process to signal.
- Workers run as a **service account**: `www-data` (Debian package) or `nginx` (nginx.org package). Ports < 1024 need root → the master starts as root.
- To serve a file, the worker user needs **read** on it and **`x` on every parent directory**, else 403. Check: `namei -l <path>`.
- `127.0.0.1` = this machine only · the real IP = the network · `0.0.0.0` = bind on all interfaces (never an address you connect to).
- TCP socket (`127.0.0.1:8000`) vs Unix socket (a **file**, access by file permissions — server 14's uwsgi apps).

### **One program, two packages → [Part 1, 3]({{ site.posts | where: "slug", "nginx-part-1" | first.url | relative_url }}#sec-3)** {#r-packages}

- One binary, `/usr/sbin/nginx`. The **package** decides the rest: unit file, default config, worker user, directories.
- **Debian/Ubuntu** (server 85): `www-data`, `conf.d/` + `sites-available/` → `sites-enabled/` (symlinks), `modules-enabled/`. **nginx.org** (server 14): user `nginx`, only `conf.d/`, modules compiled in.
- Which one is installed: `nginx -v`, `apt-cache policy nginx`, `dpkg -S /usr/lib/systemd/system/nginx.service`.
- *Q: why do my two servers run nginx differently?* Different packages, chosen when the machine was provisioned. Same program, same behaviour.

### **systemd starts it → [Part 1, 4]({{ site.posts | where: "slug", "nginx-part-1" | first.url | relative_url }}#sec-4)** {#r-systemd}

- Unit files: from the package in `/usr/lib/systemd/system/`, admin overrides in `/etc/systemd/system/` (they win). `systemctl cat nginx` shows the one in effect.
- Debian's unit tests first (`ExecStartPre nginx -t`), passes `-g 'daemon on; master_process on;'` (global directives on the command line), stops gracefully via `start-stop-daemon` (QUIT, then TERM, then KILL). nginx.org's passes `-c ${CONFFILE}` and reloads/stops with raw `kill -s HUP` / `TERM`.
- Both load the same `/etc/nginx/nginx.conf`: implicitly (compiled-in `--conf-path`, see `nginx -V`) or explicitly (`-c`).
- Boot (`Type=forking`): systemd → (config test) → `ExecStart` → nginx binds 80/443 as root → forks, the parent exits → the master writes its PID file → systemd watches that PID → the master forks the workers.
- *Q: did I install or start nginx?* No. It's an OS service set up by provisioning, `enabled` → started at every boot.
- systemd in general (unit files, `enable` vs `start`, drop-ins, `Type=`, timers): [systemd, systemctl and Service Files]({{ site.posts | where: "slug", "systemd-systemctl-and-service-files" | first.url | relative_url }}).

### **Master and workers → [Part 1, 5]({{ site.posts | where: "slug", "nginx-part-1" | first.url | relative_url }}#sec-5)** {#r-workers}

- **Master** (root): binds the ports, reads the config, forks and replaces workers, never handles a request. **Workers** (low-privilege user): handle every request.
- `worker_processes auto;` = one worker per CPU core (8 on server 85, 4 on server 14). Each worker is a single-threaded `epoll` event loop handling thousands of connections.
- `worker_connections` is per worker; a proxied request uses two connections → client capacity ≈ workers × connections ÷ 2.
- Workers drop root so that a bug exploited in HTTP handling only gets `www-data` permissions.
- **Reload** = master validates the new config → starts new workers → old ones finish and exit. Zero downtime, same master PID; a broken config is refused and the old one keeps running. Always `sudo nginx -t && sudo systemctl reload nginx`. (`restart` = full stop and start.)

### **nginx.conf and contexts → [Part 1, 6]({{ site.posts | where: "slug", "nginx-part-1" | first.url | relative_url }}#sec-6)** {#r-conf}

```nginx
user www-data;                  # main context: worker user, worker count, pid
worker_processes auto;
events { worker_connections 768; }

http {                          # everything HTTP; inherited by every server below
    include /etc/nginx/conf.d/*.conf;          # the sites live in included files
    server {                    # one site = one virtual server
        listen 80;
        server_name example.com;
        location /api/ { proxy_pass http://127.0.0.1:8000; }   # one rule for one path
    }
}
```

- Settings inherit downward (`http` → `server` → `location`) unless overridden. ⚠️ `proxy_set_header` and `add_header` inherit **only if the inner block sets none of its own** ([Part 2, 9.9]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-9)).
- The two packages' `nginx.conf` differ only in packager defaults: worker user, `worker_connections` (768 vs 1024), Debian's extra `sites-enabled/` and `modules-enabled/`. Sites are added as files in `conf.d/` (or `sites-enabled/`), not by editing `nginx.conf`.

### **include = copy-paste → [Part 1, 7]({{ site.posts | where: "slug", "nginx-part-1" | first.url | relative_url }}#sec-7)** {#r-include}

- `include` pastes the file(s) in place **before** parsing; a glob expands in **alphabetical** order. nginx then parses one big config.
- So: one syntax error in any file → `nginx -t` fails, reload refused · the same `server_name` twice on a port → warning, the second is ignored · `upstream` names are shared by all files · a file must contain what's allowed where it's pasted (`conf.d/` files go inside `http {}`).
- `sudo nginx -T` prints the fully expanded config (the proof); `sudo nginx -T | grep -n server_name` lists every site.

---

## **Part 2 — Routing requests** {#r-part-2}

### **Which server block answers → [Part 2, 8]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-8)** {#r-server-block}

- One `server {}` block = one **virtual server**. Many share one IP and port; the **`Host` header** tells them apart. DNS only gets the browser to the right machine.
- The browser always sends `Host`: a domain URL → DNS lookup, `Host` = the domain; an IP URL → `Host` = the IP.
- Selection: **`listen`** first (a specific IP beats `0.0.0.0`), then **`server_name`**: exact → `*.wildcard` → `~regex`.
- No match → that port's **`default_server`**; none marked → the **first** block for that port in include order ("why am I seeing the wrong site?").
- The client writes `Host` (`curl -H "Host: x"` fakes it) → use it for routing, never for security.
- A request lands in exactly **one** block and stays there; to share behaviour, point blocks at the same upstream or `include` the same snippet.
- `$host` = lowercased, port stripped, falls back to `server_name` · `$http_host` = exactly as sent, with port · `$server_name` = from the config.

```nginx
server {
    listen 80 default_server;   # catch-all for port 80: unknown names, bots scanning IPs
    server_name _;              # "_" never matches; default_server is what makes it the catch-all
    return 444;                 # nginx-special: close the connection without a response
}
```

- Test without a browser: `curl --resolve name:443:IP https://name/` (sets Host **and** SNI) or `curl -H "Host: name" http://IP/`.
- *Q: many blocks — different IPs or ports?* Neither: same IP and port, different `Host`. *Q: all `*.example.com` names have the same IP — what differs?* Only the name, carried in `Host` (and in SNI for HTTPS).

### **Phases: nginx doesn't run lines in order → [Part 2]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#phases), [Part 3, 15.3]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-15-3)** {#r-phases}

- The config is **declarative**: each directive belongs to a phase, and the phases run in a fixed order for every request, whatever the order of the lines.
- Simplified order: server-level `return`/`rewrite`/`set`/`if` → **find the location** → location-level `return`/`rewrite`/`set`/`if` → **access** (`allow`/`deny`, `auth_basic`, `auth_request`) → `try_files` → **content** (`proxy_pass`, static files) → log. All 11: [phases table](#ref-phases).
- `proxy_pass` always runs **last** (it installs the content handler). `return` runs **before** access → it bypasses auth, and it wins over `proxy_pass`.
- The `try_files` fallback and `rewrite` are **internal redirects**: location matching starts again with the new URI.
- *Q: does it matter whether `auth_request` or `proxy_pass` is written first?* No.

### **Picking a location → [Part 2, 9.1–9.2]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-2)** {#r-location}

- Locations only exist inside their own server block → several files can all have `location /`.
- Matching: `=` exact → use it · otherwise remember the **longest prefix** · if it has `^~` → use it · else regexes (`~`, `~*`) **in file order**, first match wins · no regex matched → the longest prefix. `location /` matches everything, so it's the fallback.
- ⚠️ `location /docs` also matches `/docsXYZ`; use `/docs/` or `= /docs` to be strict.
- `location @name` = a named location, only reachable by internal redirects.

### **Serving files: root, alias, try_files → [Part 2, 9.3–9.4]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-3)** {#r-files}

```nginx
location / {
    root /var/www/app/dist;             # file = root + full URI:  /assets/a.js → dist/assets/a.js
    try_files $uri $uri/ /index.html;   # a file? a directory? else internal redirect to the SPA's index.html
}
location /static {
    alias /opt/app/collected_static;    # file = alias + URI minus "/static":  /static/x.css → .../x.css
    expires 10m;                        # caching headers for the browser
}
```

- Without the `try_files` fallback, refreshing a React route like `/devices/5` gives 404: no such file on disk.

### **proxy_pass and the path rule → [Part 2, 9.5–9.6]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-6)** {#r-path-rule}

- `proxy_pass` makes nginx send a **new** request to the backend, and nginx decides that request's **path** and **headers**.
- **The rule:** `proxy_pass` **without** a path → the path is sent unchanged. **With** a path (even a lone `/`) → the part that **matched the location** is replaced by it, and the remainder is appended. Plain text replacement.

| location | proxy_pass | `/api/devices/5` arrives as |
|---|---|---|
| `/api/` | `http://b:8000` | `/api/devices/5` |
| `/api/` | `http://b:8000/` | `/devices/5` |
| `/api/` | `http://b:8000/v2/` | `/v2/devices/5` |
| `/api/` | `http://b:8000/v2` | `/v2devices/5` ⚠️ |
| `/api` | `http://b:8000/` | `//devices/5` ⚠️ |

- Rule of thumb: the location ends with `/` → the `proxy_pass` path ends with `/` too.
- Exact match: `location = /__auth_qaview` + `proxy_pass http://127.0.0.1:8000/api/auth/verify;` → the backend gets `/api/auth/verify` (the whole path matched; nothing remains).
- Exceptions: regex or named location → `proxy_pass` may not have a path (`nginx -t` fails) · after `rewrite ... break` → the full rewritten URI is sent · with variables → the URL is used as written ([Extra]({{ site.posts | where: "slug", "nginx-variables-and-dynamic-proxy" | first.url | relative_url }}#sec-21-5)).
- Backend has the same paths as the public URL (server 85: FastAPI routes start with `/api`) → no path. Another team's service under our prefix → `location /integrations/qaview/ { proxy_pass http://10.1.1.1:8000/; }` strips the prefix; their server needs no `/integrations/...` routes.
- A whole UI under a sub-path breaks: its absolute asset paths (`/static/app.js`) land in **our** `location /`. Give it a subdomain instead.
- *Q: does `proxy_pass http://b:8000/;` replace the whole path?* No, only the matched prefix.

### **upstream and uwsgi_pass → [Part 2, 9.7]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-7)** {#r-upstream}

```nginx
upstream api_pool {                     # a named group of backends; round-robin by default
    server 10.0.0.11:8000;
    server 10.0.0.12:8000;
    server 10.0.0.13:8000 backup;       # only used when the others are down
}
upstream tool2 { server unix:///run/uwsgi/tool2_autodeploy.sock; }    # a Unix socket file

location /api/ { proxy_pass http://api_pool; }
location /     { uwsgi_pass tool2; include uwsgi_params; uwsgi_read_timeout 600s; }   # uwsgi protocol, not HTTP
```

- Server 85: FastAPI under uvicorn via `proxy_pass` (HTTP over TCP). Server 14: Django under uwsgi via `uwsgi_pass` (a socket file).

### **Headers to the backend → [Part 2, 9.9]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-9)** {#r-headers}

- The client's headers (Cookie, Authorization, ...) are copied into the new request, except two nginx sets itself: `Host $proxy_host` (→ `127.0.0.1:8000`) and `Connection close`.
- With `Host: 127.0.0.1:8000` the backend builds redirects and links to `127.0.0.1:8000`, and Django rejects it (400 `ALLOWED_HOSTS`, CSRF "Origin checking failed").

```nginx
proxy_set_header Host              $host;                       # the name the user typed
proxy_set_header X-Real-IP         $remote_addr;                # the real client IP (else 127.0.0.1)
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;  # client IP + any proxies before nginx
proxy_set_header X-Forwarded-Proto $scheme;                     # "https" when nginx terminated TLS
```

- Proxying to an **external** virtual-hosted service: send *its* name (the default `$proxy_host` already is), never `$host`; add `proxy_ssl_server_name on;` for HTTPS.
- nginx talks HTTP/1.0 to backends before version 1.29.7 (including Ubuntu's builds), 1.1 from then on; set `proxy_http_version 1.1;` for keepalive or WebSockets.
- ⚠️ Inheritance is all-or-nothing → each location on server 85 repeats its `proxy_set_header` lines.
- See exactly what nginx sends: point a location at `nc -l 127.0.0.1 9999`.

### **Two real deployments → [Part 2, 10–11]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-11-1)** {#r-deployments}

| | Server 14 | Server 85 |
|---|---|---|
| Routing by | domain (`server_name`), a block per app | path (`location`), one block |
| Frontend / API | `tool1-dev.example.com` / `tool1-api-dev.example.com` | `10.20.30.185/` / `10.20.30.185/api/` |
| Same origin? | no → CORS headers needed | yes → no CORS |
| Backend | Django via uwsgi sockets | FastAPI on `127.0.0.1:8000` |
| HTTPS | yes, one wildcard cert | no, plain HTTP |

- Server 14's `default.conf`: port 80 → 308 redirect to HTTPS; port 443 with an unknown `Host` → 404. Each app has a port-80 redirect block plus a 443 block; `alias` serves Django's `/static`.
- Server 85 reached by hostname instead of IP → no `server_name` matches → Debian's `sites-enabled/default` ("Welcome to nginx").
- Both styles use the same mechanisms; the choice is organisational.

### **Browser flow and CORS → [Part 2, 12]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-12)** {#r-browser}

- A page load is many requests: `index.html` → the JS/CSS it names → the app now runs **in the browser** → every `fetch('/api/...')` is a new request, routed by Host + path. A relative URL uses the page's own origin.
- Origin = scheme + host + port. A different origin → the browser requires `Access-Control-Allow-*` headers and sends `OPTIONS` preflights; nginx can answer them itself (`if ($request_method = OPTIONS) { add_header ...; return 204; }`).
- CORS is enforced only by browsers (`curl` ignores it). Cookies across origins → a specific origin + `Access-Control-Allow-Credentials: true`, never `*`.

### **Docker → [Part 2, 13]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-13)** {#r-docker}

- An app in a container must listen on `0.0.0.0`: its `127.0.0.1` is its own, and Docker forwards to the container's IP.
- `proxy_pass` uses the **host-side** port (left of `-p HOST:CONTAINER`). Publish as `-p 127.0.0.1:HOST:CONTAINER` so nobody reaches it around nginx. More: [Docker Networking Part 1]({{ site.posts | where: "slug", "docker-networking-part-1" | first.url | relative_url }}).

### **HTTPS → [Part 2, HTTPS]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#https)** {#r-https}

- TLS is negotiated **before** the HTTP request → the browser sends the name in the handshake (**SNI**), and nginx uses it to pick the block and certificate.
- Two files: `ssl_certificate` (cert + chain, public) and `ssl_certificate_key` (secret, root-only; the master reads it while still root).
- Where certs come from: Let's Encrypt (`certbot --nginx -d name`) for public names · the company CA (often a wildcard like `*.example.com`) internally · self-signed for local tests.

```nginx
server {
    listen 80;
    server_name app.example.com;
    return 308 https://$host$request_uri;   # the HTTP → HTTPS pattern; 308 keeps POST as POST
}
```

- HSTS (`add_header Strict-Transport-Security "max-age=31536000" always;`) only once HTTPS is reliable — browsers remember it.
- Which cert is served: `openssl s_client -connect host:443 -servername host </dev/null | openssl x509 -noout -subject -issuer -dates`.

---

## **Part 3 — Internal requests and auth** {#r-part-3}

### **Requests nginx makes to itself → [Part 3, 14]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-14)** {#r-internal}

| Feature | Starts an internal request when | Typical use |
|---|---|---|
| `try_files ... /index.html` | the file isn't found | SPA routing |
| `error_page 401 = @login` | a response has that code | error pages, login redirect, a JSON 401 |
| `auth_request /x` | before every request in that location | central authentication |
| `X-Accel-Redirect` (a backend response header) | the backend sends it | protected downloads |
| `internal;` | — marks a location internal-only (clients get 404) | auth endpoints, protected files |
| `@name` | — always internal | fallback handlers |

### **auth_request and `/__whoami` → [Part 3, 14.5–14.8]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-14-5)** {#r-auth-request}

```nginx
location /api/ {
    auth_request /__whoami;                              # access phase: ask first
    auth_request_set $auth_user $upstream_http_x_user;   # copy X-User from the auth response
    proxy_set_header X-User $auth_user;                  # hand the identity to the backend
    proxy_pass http://127.0.0.1:8000;
}

location = /__whoami {          # "=" exact, highest priority · "__" can't clash with app routes
    internal;                   # clients can't call it
    proxy_pass http://127.0.0.1:8000/api/auth/whoami;   # whole path replaced → backend gets /api/auth/whoami
    proxy_pass_request_body off;                         # no request body to the auth check
    proxy_set_header Content-Length "";
    proxy_set_header X-Original-URI $request_uri;        # tell it what was requested
}
```

- The verdict is the **status only**: 2xx allow · 401/403 deny (catch with `error_page`) · anything else → 500. The body is ignored.
- The client's headers (Cookie, Authorization) go to the subrequest by default — that's how the check sees the session.
- It runs on **every** protected request. Module present? `nginx -V 2>&1 | grep -o with-http_auth_request_module`.
- The login page and the auth API stay public (`location /api/auth/ { ... }` without `auth_request`).

### **Who actually checks credentials → [Part 3, 15.1–15.2]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-15-1)** {#r-who-checks}

- **Authentication** (who are you?) can live at the gateway; **authorization** (may this user do this?) stays in the app.
- *Q: "Authentication" on the API-gateway box of a diagram — valid?* Yes: reject requests without valid credentials before any backend. Standard gateway feature.
- *Q: does nginx authenticate with `auth_request`?* No. The auth service checks; nginx only enforces its verdict.
- nginx checks credentials itself only with: `auth_basic` (password file via `htpasswd`; HTTPS only), mTLS (`ssl_verify_client on`), `auth_jwt` (NGINX Plus only), and `allow`/`deny` (by IP — access, not identity). `satisfy any` = office network **or** password.

### **The auth_request flow, exactly → [Part 3, 15.3]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-15-3)** {#r-auth-flow}

- Main request: server block → location → rewrite → **access: subrequest to `/__auth`** (the main request waits) → 2xx → `try_files` → **content: `proxy_pass`** to the backend with the same method, path and body, plus the added headers.
- ⚠️ The subrequest is resolved **in the same server block**. `internal` doesn't make it global: every block that uses `auth_request /__auth` needs its own `location = /__auth` → write it once in `snippets/auth.conf` and `include` it in each block. The auth **service** can live anywhere.
- ⚠️ `return` inside a protected location is served to everyone (rewrite runs before access). Useful only for CORS preflights, which never carry credentials.

### **Cookies from the auth service, caching → [Part 3, 15.4–15.5]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-15-4)** {#r-auth-cookies}

- The auth subrequest's body is discarded and its headers never reach the browser. To forward one cookie on purpose: `auth_request_set $c $upstream_http_set_cookie;` + `add_header Set-Cookie $c always;`.
- Normal design: login, refresh and logout are ordinary **public** locations, so their `Set-Cookie` reaches the browser by itself.
- Caching the verdict (`proxy_cache` on `/__auth`, keyed on `$http_authorization$cookie_session`, e.g. 30 s) saves subrequests, but a cached "allowed" can outlive a logout.

### **The trust boundary → [Part 3, 15.6]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-15-6)** {#r-trust}

- Backends trust `X-User` blindly → **nothing but nginx may reach them**: loopback, firewall, a Docker internal network, a gateway secret header, or mTLS.
- *Q: must all services be on the same machine?* No — they must be **unreachable except via nginx**; loopback is just the easiest way.
- In locations **without** auth that proxy to the same backends, blank the identity headers: `proxy_set_header X-User "";` (empty = not sent). Protected locations overwrite them anyway.
- No `return` in protected locations.

### **When gateway auth fits; external services (nginx side) → [Part 3, 15.7–15.9]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-15-7)** {#r-fits}

- Fits: **many internal services, one user base**. One self-contained product → auth in the app. External callers → API keys or OAuth, never gateway headers.
- nginx can only change requests whose URL points at **our** nginx. To add a partner's key, route the call through us:

```nginx
location /partner/ {
    auth_request /__auth;                              # caller must be logged in with us
    proxy_pass https://partner.example.com/;           # "/" strips /partner/
    proxy_set_header Host partner.example.com;         # THEIR name, not $host
    proxy_ssl_server_name on;                          # SNI to their HTTPS server
    proxy_set_header Authorization "Bearer <partner-api-key>";
    proxy_set_header Cookie "";                        # don't leak our session cookie
}
```

- Checklist of everything that can go wrong: [15.9]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-15-9).

### **Four messages: request vs response → [Part 3, 16]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-16)** {#r-messages}

```
           ① request                  ② request (a NEW one)
 Browser ───────────►   nginx   ───────────────►   Backend
         ◄───────────           ◄───────────────
           ④ response                 ③ response
```

- `proxy_set_header` changes ② (to the backend). `add_header` changes ④ (to the browser; 2xx/3xx only unless `always`). `proxy_hide_header`, `proxy_pass_header`, `proxy_cookie_*`, `proxy_redirect` also change ④.
- `Cookie` = request header, browser → server. `Set-Cookie` = response header, server → browser, so it only means something on ④. *Q: `add_header Set-Cookie` — backend or browser?* The **browser**; the backend never sees it.
- Cookies are scoped by domain + path, **not port**. *Q: will the browser distrust a cookie set by the auth service on another port?* No — it only sees nginx, so the cookie comes from the host in the URL bar.
- Header variables: `$http_x` (①), `$cookie_x` (①), `$upstream_http_x` (③, also the auth response), `$sent_http_x` (④). Lowercase, `-` → `_`.
- A backend's cookies scoped wrong behind a prefix → `proxy_cookie_path / /app/;`, `proxy_cookie_domain`, `proxy_cookie_flags`.

---

## **Part 4 — Gateway auth in practice** {#r-part-4}

### **Where auth belongs, who holds what → [Part 4, 17–18]({{ site.posts | where: "slug", "nginx-part-4" | first.url | relative_url }}#sec-17)** {#r-design}

- One product (UI + backend): auth **in the app**, BFF style — the browser holds only an `HttpOnly` session cookie, tokens stay server-side. Access + refresh tokens in the browser earn their place with mobile apps, third-party clients, cross-domain setups, stateless microservices.
- A product for many customers: built-in auth **plus** an optional proxy-header mode (Grafana's `[auth.proxy]`, trusting the header only from the gateway's address). Defense in depth is normal.
- *Q: do all backends need the JWT secret, a user DB, refresh tokens?* Not with gateway trust: the auth service holds all of it; backends read `X-User`/`X-Roles`. The alternatives are asymmetric JWT (backends verify with the **public** key) or opaque tokens + introspection — never a shared symmetric secret.
- **Central identity, local permissions:** company-wide roles arrive as `X-Roles`; "may delete *this* session" lives in each app's own DB, keyed by `X-User`.
- A backend can additionally insist on a gateway secret header (`X-Gateway-Token`).

### **One session → [Part 4, 19]({{ site.posts | where: "slug", "nginx-part-4" | first.url | relative_url }}#sec-19)** {#r-session}

- Login, refresh, logout: **public** endpoints (`/auth/...`), so their `Set-Cookie` reaches the browser. The verify endpoint is internal and answers only 2xx / 401 / 403.
- Cookie rules: no `Domain` = host-only · `Domain=.example.com` = shared by all subdomains · `HttpOnly` for sessions · `Secure` needs HTTPS (so not on server 85) · set `SameSite` explicitly · cookies cross-origin = `credentials: 'include'` + a specific origin + `Allow-Credentials`.
- **Two whoamis:** the internal verify (`internal;`, nginx reads the status + `X-User`) and the public whoami (the SPA calls it on load: 200 JSON, or 401 → go to `/login`). One backend route can serve both.
- The public whoami returns **401, not a 302** — `fetch()` can act on a 401; a redirect hands the JS a chunk of HTML.
- *Q: for one UI + backend product, should auth be at the gateway?* No — in the app; gateway auth is for many services sharing one user base.

### **External services → [Part 4, 20]({{ site.posts | where: "slug", "nginx-part-4" | first.url | relative_url }}#sec-20)** {#r-external}

- **Who sends the request decides everything:** `<iframe src="https://their.site/">` or `fetch("https://their.api/")` go straight to them, so we can't add a key; URLs under our nginx (`/integrations/...`) we can.
- Three options: (a) nginx injects a static key (one service account, secret in `/etc/nginx`, no logic) · (b) **a backend integration layer** calling them with `httpx` (per-user checks, reshaping, retries — usually right) · (c) per-user delegation (OAuth2, token exchange).
- **Token injection in one browser request:** access phase — our verify endpoint checks the user and returns *their* key in a header (`X-Target` says which service) · content phase — `proxy_pass` with `Authorization: Bearer $ext_token` and `Cookie ""`. The key never reaches the browser.
- Their iframe: (1) an embed token (short-lived JWT in the iframe URL; Metabase/Grafana style) · (2) shared SSO · (3) their UI proxied through our nginx on a **subdomain**, with key injection. Watch `frame-ancestors` / `X-Frame-Options` and cross-site cookie blocking (login loops).
- *Q: can our nginx inject an API key into an iframe pointing at their domain?* No — use one of the three approaches.
- Secrets stay server-side; the browser only ever holds our own session cookie.

---

## **Extra — Variables and a dynamic proxy → [Extra, 21]({{ site.posts | where: "slug", "nginx-variables-and-dynamic-proxy" | first.url | relative_url }}#sec-21)** {#r-extra}

```nginx
location /__catalog-fetch {
    resolver 10.20.0.2 valid=60s;        # DNS server for names only known at request time
    set $upstream $arg_url;              # rewrite phase: my variable ← the ?url= query parameter
    proxy_pass $upstream;                # the destination is chosen per request
    proxy_set_header Host $proxy_host;   # the REMOTE's name (already the default; never $host here)
    proxy_ssl_server_name on;            # SNI to the remote HTTPS server (off by default)
}
```

- Three kinds of words: **directives** (`set`, `proxy_pass`), **built-in variables** (`$host`, `$arg_url`), **your own variables** (`$upstream`, also from `map` and `auth_request_set`). Families: `$arg_x`, `$http_x`, `$cookie_x`, `$upstream_http_x`.
- `$arg_*` is **not URL-decoded**, and an `&` inside the value ends it. A missing parameter → empty → 500 `invalid URL prefix`.
- With a variable, a URL that has a path is sent as is; one without a path gets the original request URI.
- A **fixed** hostname in `proxy_pass` is resolved **once**, at start/reload (unresolvable → `nginx -t` fails; its IP changes → stale until reload). A variable hostname without `resolver` → 502. Fixed but changing backend → `upstream { zone ...; server name resolve; }` (free nginx since 1.27.3).
- Upstream certificates are **not verified** by default: `proxy_ssl_verify on;` + `proxy_ssl_trusted_certificate <CA bundle>;` + `proxy_ssl_verify_depth 2;`.
- ⚠️ **SSRF:** a client-chosen destination can reach internal services. Allowlist it: `map $arg_url $ok { default 0; "~^https://(allowed\.example\.com)(:\d+)?/" 1; }` and `if ($ok = 0) { return 403; }`.

---

## **Lookup** {#lookup}

### **Phases at a glance** {#ref-phases}

| # | Phase | Typical directives |
|---|---|---|
| 1 | POST_READ | realip (`set_real_ip_from`, `real_ip_header`) |
| 2 | SERVER_REWRITE | `return`, `rewrite`, `set`, `if` at server level |
| 3 | FIND_CONFIG | `location` matching; `internal` check |
| 4 | REWRITE | `return`, `rewrite`, `set`, `if` inside the location |
| 5 | POST_REWRITE | *(internal)* re-run location search after a rewrite |
| 6 | PREACCESS | `limit_req`, `limit_conn` |
| 7 | ACCESS | `allow` / `deny`, `auth_basic`, `auth_request`, `auth_jwt` |
| 8 | POST_ACCESS | *(internal)* applies `satisfy` |
| 9 | PRECONTENT | `try_files`, `mirror` |
| 10 | CONTENT | `proxy_pass`, `uwsgi_pass`, `fastcgi_pass`, static files |
| 11 | LOG | `access_log` |

Consequences: `return` (2/4) runs **before** auth (7); `proxy_pass` (10) always runs **last**, whatever its line position. Details in [15.3]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-15-3).

### **Directives at a glance — what it does, when it runs** {#ref-directives}

**Routing and structure**

| Directive | What it does | When |
|---|---|---|
| `listen` | IP:port a server block accepts (`default_server`, `ssl`) | server selection |
| `server_name` | names matched against the `Host` header | server selection |
| `location` | path match inside a server block | 3 FIND_CONFIG |
| `internal` | location only nginx itself may use (clients get 404) | 3 FIND_CONFIG |
| `include` | paste other files into the config | config load |
| `upstream` | named group of backends (simple load balancing; `server name resolve` re-resolves DNS) | config; used by `*_pass` in 10 |
| `resolver` | DNS servers nginx asks at run time (`valid=` caching) | when a `proxy_pass` with variables or a `resolve` server needs a name |

**Rewrite and variables**

| Directive | What it does | When |
|---|---|---|
| `return` | answer immediately: status, text or redirect | 2 / 4 REWRITE |
| `rewrite` | change the URI with a regex | 2 / 4 REWRITE |
| `set` | set a variable | 2 / 4 REWRITE |
| `if` | conditional block (keep it to `return` / `set` / `add_header`) | 2 / 4 REWRITE |
| `map` | define a variable from another by value or regex (in `http {}`) | evaluated when the variable is used |

**Limits and access**

| Directive | What it does | When |
|---|---|---|
| `limit_req` / `limit_conn` | rate / connection limits (zones defined in `http` via `limit_req_zone` / `limit_conn_zone`) | 6 PREACCESS |
| `allow` / `deny` | IP-based access control | 7 ACCESS |
| `auth_basic` + `auth_basic_user_file` | username/password check by nginx | 7 ACCESS |
| `auth_request` | subrequest to an auth endpoint; 2xx allow, 401/403 deny | 7 ACCESS |
| `auth_request_set` | copy a header of the auth response into a variable | 7 ACCESS (when the subrequest finishes) |
| <code>satisfy any &#124; all</code> | combine the access checks | 8 POST_ACCESS |
| `client_max_body_size` | max request body; larger → 413 | after location selection |

**Files and content**

| Directive | What it does | When |
|---|---|---|
| `try_files` | try files in order, else fallback (internal redirect or code) | 9 PRECONTENT |
| `root` / `alias` | map the URI to a filesystem path | used in 9–10 |
| `index` | file served for a directory request | 10 CONTENT |
| `proxy_pass` | forward to an HTTP backend | 10 CONTENT |
| `uwsgi_pass` / `fastcgi_pass` | forward using the uwsgi / FastCGI protocol | 10 CONTENT |

**Shaping the request to the backend (②)** — applied when `proxy_pass` builds the request, phase 10

| Directive | What it does |
|---|---|
| `proxy_set_header` | add / override / remove (empty value) a header sent to the backend |
| `proxy_pass_request_body` / `proxy_pass_request_headers` | send the client's body / headers, or not |
| `proxy_http_version` | HTTP version to the backend (1.1 for keepalive and WebSockets) |
| `proxy_connect_timeout` / `proxy_read_timeout` | backend timeouts (504 when exceeded) |
| `proxy_ssl_server_name` | send SNI to an HTTPS backend (default off) |
| `proxy_ssl_name` | the name used for SNI and certificate checks (default `$proxy_host`) |
| `proxy_ssl_verify` + `proxy_ssl_trusted_certificate` + `proxy_ssl_verify_depth` | verify the backend's certificate (default off; depth 2 for usual public chains) |
| `proxy_cache` (+ `proxy_cache_path`, `proxy_cache_key`, `proxy_cache_valid`) | cache backend responses |

**Shaping the response to the browser (④)** — applied as the response goes out

| Directive | What it does |
|---|---|
| `add_header` | add a response header (2xx/3xx only, unless `always`) |
| `proxy_hide_header` / `proxy_pass_header` | drop / allow a header from the backend |
| `proxy_cookie_path` / `proxy_cookie_domain` / `proxy_cookie_flags` | rewrite the backend's `Set-Cookie` attributes |
| `proxy_redirect` | rewrite the backend's `Location` header |
| `expires` | caching headers |
| `gzip` | compress the response |

**Errors and internal redirects**

| Directive | What it does | When |
|---|---|---|
| `error_page` | on a status code, internal redirect to a URI or `@name` | whenever that code is produced |
| `X-Accel-Redirect` *(backend response header)* | backend asks nginx for an internal redirect | after the backend responds |

**Global, TLS and logging**

| Directive | What it does | When |
|---|---|---|
| `user`, `worker_processes`, `worker_connections`, `pid` | process model | startup |
| `ssl_certificate` / `ssl_certificate_key` / `ssl_verify_client` | server cert / client-cert check | TLS handshake, before HTTP |
| `sendfile`, `keepalive_timeout` | connection / file-sending behaviour | connection handling |
| `access_log` / `log_format` | request log and its format | 11 LOG |
| `error_log` | error log | any time |

### **Variables at a glance** {#ref-variables}

| Variable | Value | Notes |
|---|---|---|
| `$request_method` | `GET`, `POST`, ... | |
| `$scheme` | `http` / `https` | used for `X-Forwarded-Proto` |
| `$request_uri` | original URI **with** the query string | never changes during processing |
| `$uri` | current normalized URI, no query string | changes after `rewrite` / internal redirects |
| `$args` | the whole query string | |
| `$arg_name` | query parameter `name` | not URL-decoded ([Extra]({{ site.posts | where: "slug", "nginx-variables-and-dynamic-proxy" | first.url | relative_url }}#sec-21-3)) |
| `$host` | `Host` lowercased, port stripped | falls back to `server_name` ([8.2]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#host-variables)) |
| `$http_host` | `Host` exactly as sent, with port | |
| `$server_name` | first name in the matched block's `server_name` | from config |
| `$proxy_host` | host:port of the `proxy_pass` URL | default `Host` sent to backends |
| `$remote_addr` / `$remote_port` | client's IP / port | for `X-Real-IP` |
| `$server_addr` / `$server_port` | local address / port that received the connection | |
| `$proxy_add_x_forwarded_for` | the client's `X-Forwarded-For` + `$remote_addr` | for `X-Forwarded-For` |
| `$remote_user` | username after `auth_basic` | |
| `$ssl_client_s_dn` | client certificate's subject (mTLS) | |
| `$http_<name>` | a client request header (①) | `$http_authorization`, `$http_user_agent` |
| `$cookie_<name>` | one cookie from the client (①) | `$cookie_session` |
| `$upstream_http_<name>` | a header of the backend / auth response (③) | `$upstream_http_x_user` |
| `$sent_http_<name>` | a header of the response to the client (④) | `$sent_http_content_type` |
| `$upstream_addr` | address of the backend actually used | |
| `$status` | response status code | |
| *your own* | `set $x ...;` · `map $a $x {...}` · `auth_request_set $x ...;` | |

Header and cookie names: lowercase, `-` → `_` (`X-User` → `$http_x_user`).

### **Processes & service** {#ref-processes-service}

```bash
systemctl status nginx              # is it running, since when, master + workers (CGroup)
systemctl cat nginx                 # unit file in effect (incl. overrides)
cat /usr/lib/systemd/system/nginx.service
systemctl is-enabled nginx          # starts at boot?
sudo systemctl reload nginx         # graceful config reload (master stays)
sudo systemctl restart nginx        # full stop + start
sudo journalctl -u nginx -n 50      # service logs
pgrep -a nginx                      # real nginx processes only
ps -ef | grep "[n]ginx:"            # same, without matching the grep itself
ps -ef --forest | less              # process tree (see PPIDs)
cat /run/nginx.pid                  # master PID
nproc                               # CPU cores → number of workers with "auto"
```

### **Config** {#ref-config}

```bash
sudo nginx -t                       # test config syntax
sudo nginx -T                       # test + dump the FULL expanded config (proof of include = paste)
sudo nginx -T | grep -n server_name # list all virtual hosts
sudo nginx -t && sudo systemctl reload nginx   # safe reload
ls -l /etc/nginx/conf.d/ /etc/nginx/sites-enabled/
grep -E "worker_processes|^user" /etc/nginx/nginx.conf
```

### **Package / build** {#ref-package-build}

```bash
nginx -v ; nginx -V 2>&1 | tr ' ' '\n'
apt-cache policy nginx
dpkg -S /usr/lib/systemd/system/nginx.service
```

### **Network** {#ref-network}

```bash
ip addr                             # my interfaces and IPs
ss -tlnp                            # who listens on which address:port
sudo ss -tlnp | grep nginx
getent hosts tool2-dev.example.com
dig +short tool2-dev.example.com
curl -v http://10.20.30.185/api/
curl -v --resolve tool2-dev.example.com:443:10.20.30.14 https://tool2-dev.example.com/
curl -vk -H "Host: tool2-dev.example.com" https://10.20.30.14/
curl -v http://127.0.0.1:8000/api/  # hit the backend directly, skipping nginx
```

### **Logs** {#ref-logs}

```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log      # FIRST place to look for 502/403/404 causes
```

### **Docker** {#ref-docker}

```bash
docker ps                                  # see PORTS column, e.g. 127.0.0.1:9090->8080/tcp
docker port <container>
docker logs -f <container>
```

### **Permissions** {#ref-permissions}

```bash
namei -l /home_ldap/user01/workspace/devicehub_frontend/dist/index.html
sudo -u www-data cat /home_ldap/user01/workspace/devicehub_frontend/dist/index.html
```

### **Troubleshooting — error → cause** {#ref-troubleshooting}

| Symptom | Likely cause | Check |
|---|---|---|
| **502 Bad Gateway** | backend not running / wrong port in `proxy_pass` / app bound to `127.0.0.1` inside container | `error.log` ("connect() failed ... Connection refused"), `ss -tlnp`, `curl 127.0.0.1:PORT` |
| **504 Gateway Timeout** | backend too slow | raise `proxy_read_timeout` / `uwsgi_read_timeout` |
| **403 Forbidden** on static files | `www-data` can't traverse a parent dir / read the file | `namei -l <path>`, `error.log` "Permission denied" |
| **404 on refresh** of a React route | missing `try_files ... /index.html` | config |
| **404 from FastAPI** for `/api/...` | `proxy_pass` trailing-slash mismatch vs FastAPI route prefix | [9.6]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-6), `curl 127.0.0.1:8000/api/...` |
| **Wrong site / "Welcome to nginx"** | Host didn't match any `server_name` → default server used | <code>nginx -T &#124; grep -n server_name</code>, `sites-enabled/default` |
| **413 Request Entity Too Large** | upload larger than `client_max_body_size` | raise it in that server block |
| **CORS error in browser console** | cross-origin call without `Access-Control-Allow-*` headers | [12.3]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-12-3); or switch to same-origin path routing |
| **Config change has no effect** | not reloaded, or reload failed due to syntax error | `sudo nginx -t`, then reload |
| **Backend reachable from network, bypassing nginx** | Docker published on `0.0.0.0` | publish as `127.0.0.1:HOST:CONTAINER` |
| **500 on every protected request** | auth_request endpoint returned something other than 2xx/401/403 (e.g. 404 because the path is wrong) | `error.log`, `curl` the auth endpoint directly |
| **400 Bad Request / "Invalid HTTP_HOST header"** (Django) | Host sent to backend not in `ALLOWED_HOSTS` (often missing `proxy_set_header Host $host;`) | [9.9]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-9) |
| **Redirect sends browser to `127.0.0.1:8000`** | backend saw `Host: 127.0.0.1:8000` | add `proxy_set_header Host $host;` ([9.9]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-9)) |
| **CSRF "Origin checking failed"** | Host / `X-Forwarded-Proto` don't match what the browser used | [9.9]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-9) |
| **Protected location served without login** | `return` inside it (runs before auth), or identity header passed through from client | [15.3]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-15-3), [15.6]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-15-6) |
| **Cookie from auth service never reaches browser** | subrequest headers are dropped | `auth_request_set` + `add_header ... always`, or make login a normal endpoint ([15.4]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-15-4)) |
| **Session cookie not stored on server 85** | `Secure` cookie over plain HTTP | [16.2]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-16-2) |
| **Security headers disappear in one location** | `add_header`/`proxy_set_header` inheritance is all-or-nothing | [9.9]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-9), [15.4]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-15-4) |
| **500 + `invalid URL prefix`** in `error.log` | `proxy_pass $variable` got an empty or URL-encoded value | [Extra, 21.3]({{ site.posts | where: "slug", "nginx-variables-and-dynamic-proxy" | first.url | relative_url }}#sec-21-3) |
| **502 + `no resolver defined to resolve ...`** | hostname inside a `proxy_pass` variable, no `resolver` | add `resolver` ([Extra, 21.6]({{ site.posts | where: "slug", "nginx-variables-and-dynamic-proxy" | first.url | relative_url }}#sec-21-6)) |
| **`nginx -t`: `host not found in upstream`** | a fixed hostname in `proxy_pass` / `upstream` can't be resolved at load time | DNS, or `server ... resolve` ([Extra, 21.6]({{ site.posts | where: "slug", "nginx-variables-and-dynamic-proxy" | first.url | relative_url }}#sec-21-6)) |
| **Backend's new IP ignored until reload** | fixed hostnames are resolved once, at start / reload | `upstream` + `resolve` ([Extra, 21.6]({{ site.posts | where: "slug", "nginx-variables-and-dynamic-proxy" | first.url | relative_url }}#sec-21-6)) |
| **502 + `upstream SSL certificate verify error`** | `proxy_ssl_verify on` without a CA bundle, or verify depth too low | [Extra, 21.7]({{ site.posts | where: "slug", "nginx-variables-and-dynamic-proxy" | first.url | relative_url }}#sec-21-7) |
| **Remote HTTPS site fails / wrong certificate via nginx** | no SNI sent (`proxy_ssl_server_name` is off by default) | `proxy_ssl_server_name on;` ([Extra, 21.7]({{ site.posts | where: "slug", "nginx-variables-and-dynamic-proxy" | first.url | relative_url }}#sec-21-7)) |
| **Frontend gets HTML instead of JSON from whoami** | the endpoint redirects (302) to the login page | return 401 JSON ([Part 4, 19.3]({{ site.posts | where: "slug", "nginx-part-4" | first.url | relative_url }}#sec-19-3)) |
| **Login loop inside an embedded iframe** | browser blocks cookies in cross-site iframes | same-site subdomain, embed token or SSO ([Part 4, 20.6]({{ site.posts | where: "slug", "nginx-part-4" | first.url | relative_url }}#sec-20-6)) |

---

*If something new confuses me: find the box in [the big picture]({{ site.posts | where: "slug", "nginx-part-1" | first.url | relative_url }}#sec-1) it belongs to, then jump to that section.*
