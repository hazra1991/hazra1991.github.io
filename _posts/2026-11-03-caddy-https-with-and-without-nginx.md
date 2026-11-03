---
layout: post
title: "Caddy: Easy HTTPS, With and Without Nginx"
date: 2026-11-03
description: "What Caddy is, why you'd put it in front of Nginx for internal HTTPS, and when Caddy alone is enough. Short Caddyfiles for both setups, how to trust its internal certificate, and what to check when it won't start."
categories: [Deployment, Nginx]
tags: [caddy, nginx, https, reverse-proxy]
---

You have an app behind Nginx and now you need **HTTPS**. Certificates, renewals, redirects: Nginx can do it all, but you wire up every piece yourself.

**Caddy** is a web server that does the HTTPS part for you. This post is short: what it gives you, the two ways to use it (**in front of Nginx**, or **instead of it**), and how to choose.

> **What we'll cover**
> 1. [Why Caddy](#why)
> 2. [Caddy in front of Nginx](#in-front)
> 3. [Making browsers trust internal HTTPS](#trust)
> 4. [Caddy alone, no Nginx](#alone)
> 5. [With or without Nginx?](#choose)
> 6. [When Caddy won't start](#debug)
{: .prompt-info}

*(Tried with Caddy 2.11 in Docker. If you know Nginx from the [nginx series]({{ site.posts | where: "slug", "nginx-part-1" | first.url | relative_url }}), the ideas map one to one.)*

---

## **Why Caddy** {#why}

It turns HTTPS on **by default**:

- Gets and **renews certificates** by itself (from Let's Encrypt for a real domain).
- Redirects HTTP to HTTPS.
- For private networks, `tls internal` makes it act as its own small certificate authority.
- The config is tiny. Compare the whole file for an HTTPS reverse proxy:

```caddyfile
192.168.1.50 {
    tls internal
    reverse_proxy 127.0.0.1:8080
}
```

With Nginx alone, the same needs a `listen 443 ssl` block, certificate paths, a redirect server and a renewal job.

---

## **Caddy in front of Nginx** {#in-front}

A good fit when Nginx is already doing the work (serving the frontend, routing `/api/`) and you just want HTTPS added on top.

```
Browser ── HTTPS :443 ──► Caddy ── HTTP 127.0.0.1:8080 ──► Nginx
                                                            ├─ React build files
                                                            └─ /api/ ──► FastAPI :8000
```

Caddy **terminates TLS**: it handles the encrypted part and talks plain HTTP to Nginx on the same machine. Nginx stays as it was, except it now listens only on loopback.

**Caddy**, in `/etc/caddy/Caddyfile`:

```caddyfile
192.168.1.50 {
    tls internal
    reverse_proxy 127.0.0.1:8080
}
```

**Nginx**, in the `server` block:

```nginx
server {
    listen 127.0.0.1:8080;          # only Caddy (same machine) can reach it
    server_name 192.168.1.50;

    root /var/www/app/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
    }
}
```

Two small details:

- `listen 127.0.0.1:8080` means nobody can bypass HTTPS by hitting Nginx on the server's network address.
- Caddy adds the forwarding headers itself. I printed what the upstream received:

```
Host: 192.168.1.50
X-Forwarded-For: <client ip>
X-Forwarded-Proto: https
Via: 2.0 Caddy
```

That's why `$http_x_forwarded_proto` in Nginx has a value (`https`) to hand on to FastAPI.

---

## **Making browsers trust it** {#trust}

`tls internal` means Caddy signs the certificate with **its own CA**, which nobody trusts yet. So a client sees an error:

```bash
curl https://192.168.1.50/
# curl: (60) SSL certificate problem: unable to get local issuer certificate
```

Fix it properly: give clients Caddy's **root certificate**. It lives in Caddy's data directory under `pki/authorities/local/root.crt`. Copy it out and trust it:

```bash
curl --cacert root.crt https://192.168.1.50/        # 200, certificate verified
```

On a machine running Caddy, `caddy trust` installs it into the local trust store. For browsers on other devices, import `root.crt` there.

> `curl -k` skips certificate checking. Use it to see whether the pipe works, never as the fix.
{: .prompt-warning}

---

## **Caddy alone, no Nginx** {#alone}

If Nginx is only there to serve files and forward `/api/`, Caddy can do both. This file replaces everything above:

```caddyfile
192.168.1.50 {
    tls internal
    encode gzip

    handle /api/* {
        reverse_proxy 127.0.0.1:8000
    }

    handle {
        root * /var/www/app/dist
        try_files {path} /index.html      # single-page app fallback
        file_server
    }
}
```

I checked the three behaviours: `/` serves the page, an unknown route like `/some/spa/route` falls back to `index.html`, and `/api/...` reaches the backend.

---

## **With or without Nginx?** {#choose}

| | Caddy + Nginx | Caddy alone |
|---|---|---|
| Moving parts | two services | one |
| Config | Caddyfile + Nginx files | one Caddyfile |
| Good when | Nginx config already exists, or you need its extras (rate limits, caching tuned by hand, Lua/njs, many existing `location` rules) | simple setups: static frontend + one or two backends |
| HTTPS | Caddy | Caddy |
| Downside | more to keep in sync, an extra hop | you lose your existing Nginx tuning |

My rule: **new and simple → Caddy alone. Already running Nginx and only missing HTTPS → put Caddy in front** and leave Nginx alone.

---

## **When Caddy won't start** {#debug}

`systemctl status caddy` only shows "exit code 1", not why. Look at the real reason:

```bash
sudo journalctl -u caddy -n 80 --no-pager       # the actual error
sudo caddy validate --config /etc/caddy/Caddyfile   # is the file valid?
sudo ss -lntp | grep -E ':(80|443|8080)\b'      # is another service on these ports?
```

The usual suspects are a port already taken (often Nginx on 80 or 443), a typo in the Caddyfile, or permissions on Caddy's data directory. `validate` prints the line of a mistake, for example `syntax error: unexpected token 'reverse_proxy', expecting '}' … Caddyfile:2`.

Apply and test:

```bash
sudo nginx -t && sudo systemctl reload nginx     # only if Nginx is in the picture
curl -I http://127.0.0.1:8080/                   # Nginx answers directly
sudo systemctl restart caddy
curl -I --cacert root.crt https://192.168.1.50/  # HTTPS through Caddy
```

---

## **Summary** {#summary}

- **Caddy = web server with HTTPS built in**: certificates, renewal and redirects are automatic; `tls internal` covers private networks.
- **In front of Nginx**: Caddy handles TLS, Nginx stays on `127.0.0.1` doing what it did before.
- **Instead of Nginx**: one Caddyfile with `reverse_proxy`, `file_server` and `try_files` covers a typical frontend + API.
- Internal certificates need the client to trust Caddy's root certificate; `-k` is only for testing.
- Debugging starts with `journalctl`, `caddy validate` and `ss`, not `systemctl status`.
