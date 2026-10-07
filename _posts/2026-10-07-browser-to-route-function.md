---
layout: post
title: "How a Request Reaches Your Code: nginx, WSGI, ASGI and the Full Server Stack"
date: 2026-10-07
description: "nginx, gunicorn, uvicorn, WSGI, ASGI, uWSGI — the server-side alphabet soup untangled into one chain. What a port really is, why a Python function can't read HTTP bytes, what the translators do, why nginx stays in front, the uwsgi name collision, and how Spring/Tomcat, Node/Express and PHP-FPM fill the same seats — each step proven with a small experiment."
categories: [Backend, Web Fundamentals]
tags: [http, wsgi, asgi, nginx]
---

> **Server side mini-series:** **1. How a Request Reaches Your Code** · [2. WSGI, ASGI, Django & FastAPI in practice]({{ site.posts | where: "slug", "wsgi-asgi-django-fastapi-guide" | first.url | relative_url }})
{: .prompt-info}

Every deployment diagram has the same cast: nginx in front, then something called gunicorn or uvicorn, then your framework, then finally *your* function with `@app.get("/orders")` on it. And sprinkled over the diagram, the alphabet soup: WSGI, ASGI, uWSGI, reverse proxy, app server.

The pieces feel disconnected until you ask one question at every arrow: **what language is being spoken here?** Follow that question from the browser to your route function and the whole stack snaps into one straight line. Every claim below was run for real.

> **The chain we'll build**
> 1. [A port is just a door](#port) — TCP is not HTTP
> 2. [nginx at the edge](#nginx) — the HTTP and TLS specialist
> 3. [The gap](#gap) — HTTP bytes vs a Python function, and [CGI, the ancestor](#cgi)
> 4. [WSGI: the handshake that is just a function call](#wsgi)
> 5. [ASGI: the same handshake, async](#asgi)
> 6. [The app servers](#app-servers) — who runs what
> 7. [The same play in every language](#other-languages) — Spring, Node, PHP
> 8. [Why keep nginx in front at all?](#why-nginx)
> 9. [The name collision: WSGI vs uWSGI vs uwsgi](#uwsgi) — with wire proof
> 10. [What `proxy_pass` actually sends](#proxy-wire) · [inventing your own protocol](#own-protocol)
> 11. [The whole chain](#recap)
{: .prompt-info}

---

## **A port is just a door** {#port}

When a browser hits `https://example.com`, the first thing that happens has nothing to do with HTTP: a **TCP connection** is made to port 443 (80 for plain HTTP). TCP guarantees the bytes arrive in order — and says absolutely nothing about what the bytes *mean*.

Meaning comes from both ends implementing the same protocol — the HTTP RFCs: request line, verbs, headers, blank line, body. Anyone can open a port; speaking HTTP is separate work. I proved it with a 7-line Python server that accepts TCP on a port and replies nonsense:

```console
$ curl http://127.0.0.1:9001/hello
curl: (1) Received HTTP/0.9 when not allowed
```

And on the server side, look what arrived — curl spoke perfect HTTP into the void:

```
received bytes: b'GET /hello HTTP/1.1\r\nHost: 127.0.0.1:9001\r\nUser-Agent: curl/8.5.0...'
```

The connection *worked*. The conversation failed. **An open port means someone's listening, not that they understand you.** HTTPS adds one more layer: TLS encrypts the conversation, so the listener must also implement certificate handshakes and decryption before it even sees the HTTP inside.

---

## **nginx at the edge** {#nginx}

nginx is a program that implements all of that edge work, per RFC, in battle-tested C: it accepts the TCP connection, does the **TLS handshake and decryption**, and parses the bytes into a structured HTTP request it fully understands.

And because it genuinely *speaks* HTTP, it doesn't have to forward anything. Ask it for a static file and nginx builds the HTTP response itself — that's just a program writing protocol-correct bytes to a socket. This is exactly how your React build or images are served with no backend involved.

But nginx has no idea what `/api/orders/42` means to your business. For that, the request must reach *your code* — and here the interesting problem starts.

---

## **The gap** {#gap}

Your code is something like:

```python
def list_orders(request):
    return {"orders": [...]}
```

A Python function. It takes objects, returns objects. It cannot read `GET /api/orders HTTP/1.1\r\nHost:...` off a socket — and it shouldn't have to; parsing HTTP correctly is a career, not a helper function.

So someone must stand in the middle and **translate**: on one side speak HTTP over the network, on the other side *call your Python code* with nice objects.

### **The ancestor: CGI** {#cgi}

The first translator (1993) was brutally simple. **CGI** meant: for every request, the web server **launches your script as a brand-new OS process**, hands the request over as **environment variables**, and whatever the script prints to stdout becomes the response. I rebuilt it in miniature — a toy server that forks a shell script per request:

```bash
#!/bin/bash
# hello.cgi — reads the request from ENV VARS, prints the response on STDOUT
echo "Content-Type: text/plain"
echo ""
echo "CGI script here, running as process $$"
echo "you did a $REQUEST_METHOD to $PATH_INFO with query '$QUERY_STRING'"
```

```console
$ curl "http://127.0.0.1:9009/hello?user=abhi"
CGI script here, running as process 290963
you did a GET to /hello with query 'user=abhi'
$ curl "http://127.0.0.1:9009/hello?user=abhi"
CGI script here, running as process 290965      ← different PID: a NEW process per request
```

It works — and a fresh process per request is exactly why it died. But remember those names: `REQUEST_METHOD`, `PATH_INFO`, `QUERY_STRING`. **CGI's vocabulary outlived CGI.** Everything that replaced it kept the same variables and only changed the delivery: FastCGI and the uwsgi protocol ship them over a socket to a *long-running* process instead of forking; and Python's standards hand them over as a dict in a *function call*:

- **WSGI** (2003, PEP 333 — later refreshed as PEP 3333) — the synchronous contract
- **ASGI** (2018) — the asynchronous successor

And here's the sentence that unlocks everything: **WSGI and ASGI are not network protocols. Nothing "WSGI" ever travels on a wire. They are calling conventions — an agreement about a Python function's signature.**

---

## **WSGI: the handshake that is just a function call** {#wsgi}

The whole WSGI contract: *be a callable that takes a dict and a callback, return the body as bytes.*

```python
# myapp.py — a complete WSGI application, no framework
def application(environ, start_response):
    body = f"Hello from path {environ['PATH_INFO']}".encode()
    start_response("200 OK", [("Content-Type", "text/plain")])
    return [body]
```

If it's just a function call, I should be able to be the "server" myself — hand it a dict, no network anywhere:

```pycon
>>> fake_request = {"REQUEST_METHOD": "GET", "PATH_INFO": "/by-hand"}
>>> application(fake_request, lambda status, headers: print(status, headers))
200 OK [('Content-Type', 'text/plain')]
[b'Hello from path /by-hand']
```

It ran. **No server, no socket, no HTTP** — because WSGI lives entirely inside Python. A real WSGI server is "just" a program that parses HTTP off the socket, builds that `environ` dict (`REQUEST_METHOD`, `PATH_INFO`, headers as `HTTP_*` keys...), calls your callable, and writes what comes back as an HTTP response.

The payoff of standardizing this is **portability** — the same function, unchanged, behind two different servers:

```console
$ python -m wsgiref...          # stdlib toy server
Hello from path /via-wsgiref
$ gunicorn myapp:application    # production server, 2 workers
Hello from path /via-gunicorn
```

Django and Flask are, at their outermost skin, exactly this: `application = get_wsgi_application()` hands gunicorn one WSGI callable, and *everything* — middleware, routing, your views — happens inside that one function call.

---

## **ASGI: the same handshake, async** {#asgi}

WSGI's contract is one blocking call per request — fine until you want `async def`, WebSockets, or ten thousand idle connections. ASGI reshapes the same idea for the async world:

```python
# asgiapp.py — a complete ASGI application, no framework
async def application(scope, receive, send):
    body = f"ASGI says hi from {scope['path']}".encode()
    await send({"type": "http.response.start", "status": 200,
                "headers": [[b"content-type", b"text/plain"]]})
    await send({"type": "http.response.body", "body": body})
```

Same trio of ideas — a dict describing the request (`scope`), and now two awaitable channels instead of a return value, which is what makes long-lived, two-way connections (WebSockets) expressible. I served this bare function with uvicorn and curl got `ASGI says hi from /raw-asgi`.

And your shiny framework? Ask Python what a FastAPI app really is:

```pycon
>>> import inspect
>>> from fastapi import FastAPI
>>> inspect.signature(FastAPI().__call__)
(scope, receive, send)        # (trimmed) — and it's a coroutine
```

**FastAPI *is* an ASGI application.** So is Starlette, so is Django's `get_asgi_application()`. The decorators and dependency injection are sugar around that one async callable.

---

## **The app servers** {#app-servers}

The translators have names. Each one speaks HTTP on the wire and one calling convention toward Python:

| Server | Wire side | Python side |
|---|---|---|
| **gunicorn** | HTTP | WSGI (ASGI via uvicorn worker class) |
| **uvicorn** | HTTP | ASGI (can also wrap a WSGI app — interop, not its main job) |
| **uWSGI** | HTTP *and* its own `uwsgi` protocol | WSGI |
| **daphne / hypercorn** | HTTP | ASGI |

One more thing they own: **concurrency**. The app server — not Django, not FastAPI — decides whether there are 4 worker processes, threads in each, or one event loop per worker juggling hundreds of connections. Your framework is passive; it answers when called. (The next post digs into exactly that: workers, event loops and sync-vs-async handlers.)

---

## **The same play in every language** {#other-languages}

Here's the part that stops WSGI and ASGI feeling like Python trivia: **the roles are universal; only the names are Python's.** Every ecosystem needs the same three seats filled — something speaking HTTP on the wire, an agreed way to hand the parsed request to code, and a framework routing it to your function. Each language just cast the play differently:

| | Convention ("how code is called") | Translator / app server | Framework |
|---|---|---|---|
| **Python** | WSGI / ASGI | gunicorn, uvicorn, uWSGI | Django, FastAPI, Flask |
| **Java** | Servlet API | Tomcat, Jetty ("servlet containers") | Spring |
| **Node.js** | *built into the runtime* | Node's own `http` module | Express, Fastify |
| **PHP** | SAPI, fed over FastCGI | PHP-FPM | Laravel, Symfony |

Three casting choices worth noticing:

- **Java split it exactly like Python did.** The Servlet API is their WSGI — a calling convention your code implements — and **Tomcat** is their gunicorn: a server that speaks HTTP and calls your servlets. Spring is the framework on top. The modern twist is that Spring Boot *embeds* Tomcat inside the jar, which is why nobody "installs Tomcat" anymore — the translator didn't disappear, it moved into the box.
- **Node merged the seats.** The runtime itself ships the HTTP server — I ran this with zero packages installed:

  ```javascript
  const http = require("node:http");
  http.createServer((req, res) => {
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end(`Node itself answered ${req.url}\n`);
  }).listen(9006);
  ```

  ```console
  $ curl http://127.0.0.1:9006/no-framework-here
  Node itself answered /no-framework-here
  ```

  That's why Express tutorials never mention a gunicorn-equivalent: **Express is routing sugar directly on `http.createServer`** — the translator is built into the platform. The jobs don't vanish, though: the multi-worker job gunicorn does is handled by `pm2` or Node's cluster module, and production Node still sits behind nginx.
- **PHP kept the wire-protocol style.** nginx speaks **FastCGI** (`fastcgi_pass`) to PHP-FPM — the exact same trick as `uwsgi_pass`, a sibling binary protocol instead of HTTP.

So when someone asks "where is Spring's WSGI?" or "why doesn't Express need uvicorn?" — same answer: every stack fills the same seats; some languages gave the seats separate programs and names, some built them in.

---

## **Why keep nginx in front at all?** {#why-nginx}

Fair question — uvicorn speaks real HTTP; you *can* point the world at it, and on an internal network people do. But the edge jobs are a different trade from running Python:

- **TLS** — terminate HTTPS once, in one place, with certificates managed there.
- **Static files** — nginx answers these itself; no reason to wake Python for a logo.
- **One door, many apps** — one port 443, routed by hostname/path to several backends.
- **Slow clients** — nginx buffers a dribbling mobile upload and hands the app server a complete request, so your precious Python workers aren't held hostage by slow networks (gunicorn's own docs insist on a buffering proxy for exactly this).
- **The usual edge toolkit** — load balancing, compression, caching, rate limiting, request size limits.

Notice this isn't a Python argument at all — the same reasons park nginx in front of Node and Tomcat deployments. The edge seat stays, whoever sits behind it.

So the division of labour your diagram shows is real: **nginx handles TCP, TLS and raw HTTP at the edge; the app server translates HTTP into function calls; the framework routes the call to your code.**

---

## **The name collision: WSGI vs uWSGI vs uwsgi** {#uwsgi}

Now the fuzziest corner, where three nearly identical names mean three different things:

| Name | What it is |
|---|---|
| **WSGI** | The Python *calling convention* (PEP 3333). Never on a wire. |
| **uWSGI** | A *program* — an application server that runs WSGI apps. |
| **uwsgi** (lowercase) | A *binary wire protocol* invented by that program — an alternative to HTTP between nginx and the app server. |

So can nginx "speak WSGI or ASGI directly"? **No — and not because of a missing feature.** There is nothing to speak: WSGI/ASGI are in-process function calls, and nginx runs no Python. What nginx *does* speak, besides HTTP, is the lowercase **uwsgi wire protocol** — that's the `uwsgi_pass` directive (FastCGI and SCGI are siblings).

I didn't take the docs' word for it. I pointed nginx's `uwsgi_pass` at a fake "uWSGI" of my own — 30 lines of Python that just prints what arrives:

```
uwsgi packet header: modifier1=0 datasize=352 modifier2=0
first raw bytes: b'\x00`\x01\x00\x0c\x00QUERY_STRING\x00\x00\x0e\x00REQUEST_METHOD\x03\x00GE'
  REQUEST_METHOD = GET
  PATH_INFO = /orders/42
  HTTP_HOST = 127.0.0.1:9080
```

Look at that: **binary**, length-prefixed key-value pairs — visibly not HTTP. And the keys are old friends: `REQUEST_METHOD`, `PATH_INFO`... the very vocabulary of the WSGI `environ` dict (inherited from CGI). The pipeline makes itself visible: *nginx packs the request's variables into a uwsgi packet → the uWSGI server unpacks them into `environ` → and calls your Python per the WSGI convention.* The wire protocol carries the dict's ingredients; the function call happens only inside Python.

### **So what does `proxy_pass` actually send?** {#proxy-wire}

With uvicorn or gunicorn there's no special protocol — nginx forwards HTTP. But *which* HTTP? Does it tunnel the client's bytes through untouched? I put a byte-printer behind `proxy_pass` and compared. The client (curl) sent `GET /orders/42 HTTP/1.1` with `Host: 127.0.0.1:9081`. The upstream received:

```
GET /orders/42 HTTP/1.0          ← downgraded (nginx's upstream default)
Host: 127.0.0.1:9007             ← rewritten to the upstream's address
Connection: close                ← added by nginx
User-Agent: curl/8.5.0           ← carried over
X-Client-Note: hello-from-curl   ← carried over
```

Not the same bytes. **nginx fully parses the client's request, then composes a fresh HTTP request of its own** — version downgraded unless you set `proxy_http_version 1.1`, hop-by-hop headers replaced, Host rewritten unless you `proxy_set_header Host $host` (now you know why every proxy config carries those lines!). And yes: the app server on the far end **parses HTTP all over again** to build `environ`/`scope`.

So the full answer to "does nginx send parsed, serialized stuff like uwsgi does?":

```
                     parse HTTP ──► re-serialize as HTTP text  ──► upstream parses AGAIN     (proxy_pass)
client bytes ──► nginx
                     parse HTTP ──► re-serialize as binary K/V ──► upstream just unpacks     (uwsgi_pass,
                                                                                              fastcgi_pass)
```

**nginx always parses. The only choice is the output encoding of the second leg** — HTTP text again, or a binary key-value packet carrying the CGI vocabulary. (Java has the same split: Apache/nginx can reach Tomcat over plain HTTP *or* over **AJP**, Tomcat's binary sibling of uwsgi.) On the same machine, either kind of pipe often runs over a **Unix socket** instead of a TCP port — faster, and nothing is exposed on the network.

### **Could nginx speak a protocol *you* invent?** {#own-protocol}

Last doubt, and it rounds off the whole story. I invented a protocol: send `POTATO <word>\n`, get `FRIES <word>\n` back. Can nginx sit in front of it?

Two very different answers, both tested:

- **As a dumb pipe — yes, today.** nginx's `stream {}` module (a sibling of the `http {}` block) proxies **raw TCP without parsing a byte**:

  ```nginx
  stream {
      server {
          listen 9083;
          proxy_pass 127.0.0.1:9010;    # bytes in, bytes out — no understanding
      }
  }
  ```

  My client sent `POTATO golden` through nginx and got `FRIES golden`. nginx balanced and forwarded a protocol it has never heard of — because at this layer it's just moving bytes, like any TCP relay.

- **As a speaker — only if someone writes the code.** Routed through the normal `http {}` `proxy_pass` instead, the same backend made nginx log `upstream sent no valid HTTP/1.0 header` — in the HTTP world nginx *demands* HTTP on both legs. For nginx to genuinely **speak** POTATO (parse it, route on its fields, rewrite it), someone would have to implement the protocol inside nginx as a **C module** — which is precisely what `uwsgi_pass` and `fastcgi_pass` are: modules somebody wrote for protocols nginx wasn't born with. A protocol is never a config line; it's code on both ends implementing the same agreement — exactly the RFC point from [the first section](#port), come full circle.

---

## **The whole chain** {#recap}

```
Browser
  │  TCP connect :443, TLS handshake, HTTP request        (wire: HTTPS)
  ▼
nginx — decrypts, parses, answers static itself
  │  forwards the rest                                    (wire: HTTP via proxy_pass,
  ▼                                                        or uwsgi protocol via uwsgi_pass)
app server — gunicorn / uvicorn / uWSGI
  │  parses the wire, builds environ / scope
  ▼
framework — Django / FastAPI = one giant WSGI/ASGI callable   (no wire: a function call)
  │  routing, middleware, validation
  ▼
your route function
```

- A **port** is a door; a **protocol** is a language. Both ends must implement it (that's what the RFCs are for) — an open port alone understands nothing.
- **nginx** speaks HTTP/TLS natively: it can answer by itself (static files) or forward.
- **WSGI/ASGI are calling conventions, not wire protocols** — I called a WSGI app with a hand-made dict, serverless.
- **App servers are translators**: HTTP on one side, `application(environ, start_response)` or `await application(scope, receive, send)` on the other. They also own all concurrency.
- **uWSGI** is a server, **uwsgi** is its binary wire protocol (which nginx speaks via `uwsgi_pass`), **WSGI** is the Python contract. Three names, three layers.
- **nginx always parses, never tunnels** (in the HTTP world): `proxy_pass` composes a *fresh* HTTP request (version, Host and Connection rewritten — hence all those `proxy_set_header` lines) that the app server parses again; `uwsgi_pass`/`fastcgi_pass` re-serialize the same parsed request as binary key-values instead. For a protocol nginx doesn't know, `stream {}` can pipe raw bytes blindly — but *speaking* a new protocol means someone writes it as a module, the way uwsgi support was written.
- **CGI is the ancestor**: one new process per request, request passed as environment variables, stdout as response. Its variable names (`REQUEST_METHOD`, `PATH_INFO`...) live on inside FastCGI, the uwsgi packet and the WSGI `environ` dict.
- The pattern is language-agnostic: Java fills the same seats with the Servlet API + Tomcat + Spring, PHP with FastCGI + PHP-FPM, and Node builds the translator into the runtime itself (which is why Express needs no gunicorn). WSGI/ASGI are just Python's names for universal roles.
- nginx stays in front for TLS, static files, virtual hosts, slow-client buffering and the rest of the edge toolkit — not because uvicorn can't speak HTTP.

*Next: what the translators do inside — workers, event loops, and when `async def` helps →* [WSGI, ASGI, Django & FastAPI in practice]({{ site.posts | where: "slug", "wsgi-asgi-django-fastapi-guide" | first.url | relative_url }}).
