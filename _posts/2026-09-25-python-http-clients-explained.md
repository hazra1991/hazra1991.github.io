---
layout: post
title: "HTTP Clients in Python: From .get() Down to the Socket"
date: 2026-09-25
description: "What actually happens when you call requests.get() or httpx.get(): sessions, adapters and transports, connection pools, the request-to-send chain, redirects, and where sync and async split. Verified with small experiments."
categories: [Backend, APIs]
tags: [python, httpx, requests, http-client]
---

You've written `requests.get(url)` a hundred times. It works, so you never looked under it. Then one day you need a retry, a proxy, a mock for tests, or you wonder why your service opens a new connection for every call.

At that point you meet the words **Session, Adapter, Transport, Pool, Mount**, and they feel disconnected. This post connects them, from the line you type down to the socket, using `requests` and `httpx` side by side. They're built the same way.

> **What we'll cover**
> 1. [The layers, in one picture](#layers)
> 2. [Why a client (session) beats one-shot calls](#why-client): an experiment
> 3. [Who does what](#policy-mechanics): client = policy, transport = mechanics
> 4. [Where connections live](#pool) (not where you'd guess)
> 5. [One `.get()` call, step by step](#one-call), including redirects
> 6. [Where sync and async split](#async)
>
> The next post, [the custom transport proxy trap]({{ site.posts | where: "slug", "httpx-custom-transport-proxy-trap" | first.url | relative_url }}), is a real bug that only makes sense once you've read this one.
{: .prompt-info}

*(Versions used for every experiment here: `requests` 2.34, `httpx` 0.28.)*

---

## **The layers in one picture** {#layers}

Every HTTP library, in any language, is built in the same layers. Once you know them, a new library is easy to read.

```
requests.get(url)           ← one-shot shortcut
        ↓
Session / Client            ← remembers headers, cookies, auth
        ↓
Adapter / Transport         ← knows how to send bytes
        ↓
Connection pool             ← keeps connections open for reuse
        ↓
Socket (TCP + TLS)          ← the actual wire
```

| Layer | The question it answers | `requests` | `httpx` |
|---|---|---|---|
| Shortcut | "Just fetch this once" | `requests.get()` | `httpx.get()` |
| Client | "Remember my settings between calls" | `Session` | `Client` / `AsyncClient` |
| Transport | "How do the bytes travel?" | `HTTPAdapter` | `HTTPTransport` / `AsyncHTTPTransport` |
| Pool | "Don't reconnect every time" | `urllib3` | `httpcore` |

Same stack, different names. Learn it once.

---

## **Why use a client at all?** {#why-client}

Let's measure it. A tiny local server counts how many TCP connections it sees.

```python
for _ in range(3):
    requests.get(url)               # three one-shot calls
```
```
3 TCP connections
```

```python
s = requests.Session()
for _ in range(3):
    s.get(url)                      # three calls on one session
```
```
1 TCP connection
```

Look at that. The shortcut is not magic. It builds a **temporary Session, uses it once, and throws it away**, so nothing is reused. (Its source is literally `with sessions.Session() as session: return session.request(...)`.) `httpx.get()` does the same.

A real connection costs a TCP handshake, and for HTTPS a TLS handshake on top. The **client keeps connections alive and reuses them**. That's the first reason to hold on to one. The second is that it carries your headers, auth and cookies for you:

```python
s = requests.Session()
s.headers["Authorization"] = "Bearer xyz"      # sent on every call
s.get("https://api.example.com/users")
s.post("https://api.example.com/posts", json={"title": "hi"})
```

With `httpx` it's the same idea, and it should be closed when you're done:

```python
with httpx.Client() as client:
    client.get("https://api.example.com/users")
```

---

## **Who does what: policy vs mechanics** {#policy-mechanics}

This is the one idea that organises everything else.

| | Job | Handles |
|---|---|---|
| **Client** (Session) | *Policy*: what to send | headers, cookies, auth, redirects, timeouts |
| **Transport** (Adapter) | *Mechanics*: how to send | connections, pooling, keep-alive, TLS |

The client prepares the request. The transport turns it into bytes and brings back a response. They meet at one small interface, which is why you can **swap the transport** for a mock in tests, a retrying one, a caching one, or one that goes through a proxy.

You plug a transport in by **mounting** it on a URL prefix:

```python
s = requests.Session()
print(list(s.adapters))             # ['https://', 'http://']  two defaults, already mounted
s.mount("https://", MyAdapter())    # https now goes through yours
```

```python
client = httpx.Client(mounts={"https://": MyTransport()})   # the httpx spelling
```

Think of mounts as a routing table: *"for URLs starting with this, use that transport."*

---

## **Where connections really live** {#pool}

A common guess: "the session holds a connection". Not quite.

```
Session
 └── Adapter / Transport (one per mount)
      └── Pool
           ├── api.example.com:443  → [conn, conn]   idle, reusable
           └── cdn.example.com:443  → [conn]
```

Two lookups happen, and they use different keys:

```
mount  →  matches the URL prefix  →  picks a transport     ("https://")
pool   →  matches host:port       →  picks a connection    ("api.example.com:443")
```

I checked both claims:

```python
s.get(url_a); s.get(url_a); s.get(url_b)
```
```
2 connections: one per host, each reused
```

```python
s1, s2 = requests.Session(), requests.Session()
# two requests on each, same host
```
```
2 connections: sessions do not share pools
```

So connections belong to the **pool inside the transport**, one set per `host:port`. And two sessions don't share them, which is one more reason to create a client once and reuse it, instead of one per request.

---

## **One call, step by step** {#one-call}

```python
s.get("https://api.example.com/users", params={"id": 5})
```

The verb methods are just sugar. `.get()` and `.post()` call one function, `.request()`, with the method name filled in. So these are identical:

```python
client.get("/users")
client.request("GET", "/users")      # handy when the method is a variable
```

`request()` still doesn't touch the network. It builds the request and hands it on. The chain looks like this in both libraries:

```
get()  →  request()  →  build the request  →  send()  →  transport  →  pool  →  socket
sugar     dispatcher    merge client config   the real
                        (headers, params,     machinery
                         auth, cookies)
```

| Stage | `requests` | `httpx` |
|---|---|---|
| Build | `prepare_request()` → `PreparedRequest` | `build_request()` → `Request` |
| Send | `send()` | `send()` |
| Pick transport | `get_adapter(url)` | `_transport_for_url(url)` |
| Redirects | loop around `send` | loop inside `send` |

### **Peeking at the final request** {#prepared}

Because *build* and *send* are separate, you can stop in the middle and inspect exactly what will go on the wire:

```python
req = requests.Request("GET", url, params={"id": 5}, headers={"X": "1"})
prepared = s.prepare_request(req)      # nothing sent yet
print(prepared.url, prepared.headers)  # final URL, session headers merged in
resp = s.send(prepared)                # NOW the network is used
```

One trap: `req.prepare()` (without the session) skips the session's headers. In my test it gave only `{'X': '1'}`, while `s.prepare_request(req)` also carried the session's own headers and the defaults. Prefer the session version.

`httpx` has the same split: `client.build_request(...)`, then `client.send(request)`.

### **Redirects pick the transport again** {#redirects}

The transport is chosen inside `send`, not before it, and that matters when a redirect jumps to another host. I mounted a spy transport on the second host and followed a redirect:

```
[default]      http://host-a/redir
[mount for B]  http://host-b/landed
```

The first hop used the default transport, the second hop was routed to the mount. Every request, including each redirect hop, is routed afresh.

---

## **Where sync and async split** {#async}

The chain is the same. Only the steps that touch the network become `await`:

| Step | `Client` | `AsyncClient` |
|---|---|---|
| `get()` / `request()` / `send()` | normal | `await` |
| `build_request()` | normal | **still normal** (no await) |
| picking the transport | normal | **still normal** |
| the transport's send | sync pool | async pool |

Two things that surprise people, both confirmed:

- `build_request()` stays plain even on `AsyncClient`. It only assembles an object; there's nothing to wait for.
- **Module-level `httpx.get()` is sync only.** There's no `await httpx.get(...)`. For async you need an `AsyncClient`.

And a `requests` adapter can't be async. `Session` is synchronous from top to bottom and never awaits anything. That's the main reason `httpx` exists: sync and async transports are both first-class there.

---

## **The pattern is everywhere** {#everywhere}

| Language | Client | Transport / pool |
|---|---|---|
| Python `requests` | `Session` | `HTTPAdapter` + `urllib3` |
| Python `httpx` | `Client` / `AsyncClient` | `HTTPTransport` + `httpcore` |
| Go | `http.Client` | `http.Transport` |
| Java | `HttpClient` | its connection pool |

Once you see *client = policy, transport = mechanics*, any HTTP library is readable.

---

## **Summary** {#summary}

- `requests.get()` and `httpx.get()` create a throwaway client each time. Nothing is reused.
- A **client** holds your settings and decides *what* to send; a **transport** decides *how* it goes out.
- **Mounts** map URL prefixes to transports. The **pool** inside each transport maps `host:port` to open connections.
- Verbs → `request()` → build → `send()`. The transport is chosen inside `send`, so every redirect hop is routed again.
- Sync vs async is only about which steps `await`. Building the request never does.

Next: what happens when you give an `httpx` client your own transport, and a proxy setting quietly stops working → [the custom transport proxy trap]({{ site.posts | where: "slug", "httpx-custom-transport-proxy-trap" | first.url | relative_url }}).
