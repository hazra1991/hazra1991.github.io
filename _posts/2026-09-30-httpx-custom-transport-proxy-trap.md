---
layout: post
title: "httpx: A Custom Transport Quietly Turns Off Your Proxy"
date: 2026-09-30
description: "A service behind a proxy worked with a default httpx client and failed once a custom transport was added, or the other way round. Why passing transport= disables environment proxy detection, shown with a runnable experiment, and four ways to fix it."
categories: [Backend, APIs]
tags: [python, httpx, proxy, troubleshooting]
---

> **Series:** [1. HTTP Clients in Python]({{ site.posts | where: "slug", "python-http-clients-explained" | first.url | relative_url }}) · **2. The custom transport proxy trap**
{: .prompt-info}

Here's a bug that costs an afternoon. A service runs on a machine where outbound traffic must go through a proxy (`https_proxy` is set). It calls an API with `httpx`. Sometimes the call **goes through the proxy and fails**, sometimes it **goes direct and works**. The only difference between the two runs was one argument: `transport=`.

> **The trap, in one line:** passing `transport=` to an `httpx` client switches off its automatic proxy detection from environment variables. Even if you write `trust_env=True` everywhere.
{: .prompt-warning}

This post shows the experiment, finds the exact line responsible, and ends with four fixes. It builds on the [previous post]({{ site.posts | where: "slug", "python-http-clients-explained" | first.url | relative_url }}) (client = policy, transport = mechanics). If those words are new, read that first.

---

## **Seeing it** {#experiment}

To avoid needing a real proxy, I ran a tiny fake one locally and pointed `http_proxy` at it. The fake proxy answers *"PROXY"* to anything. The target name `app.test` doesn't exist, so a direct connection can only fail.

```python
async with httpx.AsyncClient(...) as c:
    await c.get("http://app.test/hello")
```

| How the client was built | Result |
|---|---|
| `AsyncClient()` | 200, **via proxy** |
| `AsyncClient(trust_env=True)` | 200, via proxy |
| `AsyncClient(transport=AsyncHTTPTransport(trust_env=True))` | **ConnectError** (went direct) |
| `AsyncClient(transport=AsyncHTTPTransport(proxy="http://proxy…"))` | 200, via proxy |
| `AsyncClient(mounts={"http://": AsyncHTTPTransport(proxy=…)})` | 200, via proxy |

Row 3 is the trap. Both objects say `trust_env=True`, and the environment variable is right there, yet the request went straight out.

---

## **Where the variable names come from** {#env-vars}

`http_proxy` and friends are a **convention that libraries agree to read**. Linux itself does not route anything because of them.

| Variable | Meaning |
|---|---|
| `HTTP_PROXY` / `http_proxy` | proxy for `http://` URLs |
| `HTTPS_PROXY` / `https_proxy` | proxy for `https://` URLs |
| `ALL_PROXY` | fallback for everything |
| `NO_PROXY` | hosts to skip the proxy for |
| `SSL_CERT_FILE` | CA bundle for TLS. **Not** proxy-related |

`httpx` doesn't parse these itself. It asks Python's standard library: `urllib.request.getproxies()`. You can ask the same question:

```python
from urllib.request import getproxies
print(getproxies())          # {'http': 'http://127.0.0.1:39777'}
```

Good for debugging. If upper and lower case disagree, the **lowercase** one wins (I set `HTTP_PROXY` to one value and `http_proxy` to another and got the lowercase one back).

---

## **The line responsible** {#the-line}

Inside `httpx.Client.__init__` (0.28.1):

```python
allow_env_proxies = trust_env and transport is None
proxy_map = self._get_proxy_map(proxy, allow_env_proxies)
```

If you pass a `transport`, `allow_env_proxies` is `False` and the client builds **no proxy routes at all**. It assumes you've taken charge of how bytes travel.

Why is it designed like that? Remember the split:

```
Client     →  chooses a transport for each URL (proxy detection and NO_PROXY live here)
Transport  →  does the connecting it was configured to do
```

Environment proxies can need *several* transports (one direct, one per proxy, plus bypass rules). A single `transport=` can't express that, so the client steps back and leaves it to you. It's defensible, but easy to trip over.

### **So what does `trust_env` on the transport do?** {#trust-env}

Only TLS: it tells `create_ssl_context()` to honour things like `SSL_CERT_FILE`. It does **not** fill in `proxy`. A transport built with `proxy=None` makes a plain direct connection pool, and that pool never looks at `https_proxy`.

> `AsyncClient(trust_env=True)` → detects proxies from the environment.
> `AsyncHTTPTransport(trust_env=True)` → only affects certificates. It's a different `trust_env`.
{: .prompt-tip}

### **Contrast: `requests` doesn't have this problem** {#requests}

I mounted a custom adapter on a `requests.Session` with the same fake proxy. The call still went through the proxy. In `requests`, the proxy decision is made by the **Session** and then handed to the adapter, so replacing the adapter doesn't switch it off. In `httpx` the decision is encoded in *which transport is chosen*, so replacing the default transport does.

---

## **Why people hit it** {#why-hit}

Nobody sets `transport=` to turn off proxies. They set it to add something **small**: retries, socket options, logging, a mock. The usual shape:

```python
httpx.AsyncClient(
    transport=RetryTransport(httpx.AsyncHTTPTransport(retries=3)),
)
```

Everything else about the client looks normal, but the proxy support is gone. Nothing warns you.

---

## **Four ways out** {#fixes}

**1. Keep the default transport.** If retries are the only reason, retry at the request level and leave `transport=` unset. You keep `httpx`'s proxy handling for free. Be careful retrying non-idempotent calls (`POST`).

**2. Say it explicitly, single proxy.**

```python
transport = httpx.AsyncHTTPTransport(proxy="http://proxy.example.com:8080")
client = httpx.AsyncClient(transport=transport)
```

Simple and visible. It does **not** honour `NO_PROXY`.

**3. Use `mounts` for several routes.**

```python
client = httpx.AsyncClient(
    transport=httpx.AsyncHTTPTransport(),                              # default: direct
    mounts={
        "http://":  httpx.AsyncHTTPTransport(proxy="http://proxy.example.com:8080"),
        "https://": httpx.AsyncHTTPTransport(proxy="http://proxy.example.com:8080"),
        "all://internal.example.com": None,                            # None → default (direct)
    },
)
```

A mount whose value is `None` means *"use the default transport"*, which is how bypass rules are written. This does not copy `HTTP_PROXY`/`NO_PROXY` for you; you list the routes yourself.

**4. Be deliberately direct.** If the service should bypass the proxy, `AsyncHTTPTransport(proxy=None)` is correct. Just write it down so the next person doesn't "fix" it.

> Avoid `httpx._utils.get_environment_proxies()` in your own code to rebuild the routes. The leading underscore means it's private and can change.
{: .prompt-warning}

---

## **A separate problem: TLS trust** {#tls}

When debugging, don't mix proxy trouble with certificate trouble.

- `curl -k` and `verify=False` skip certificate checks. A `200` with them only proves a response arrived, **not** that the certificate chain is trusted.
- `SSL_CERT_FILE` replaces the CA bundle. If it points to a file that lacks the API's issuing chain, verification fails even though routing is fine.
- To test properly, run once **without** `-k` / `verify=False` in the service's real environment.

---

## **Checking your own setup** {#checking}

```bash
env | grep -i proxy                                       # what the shell has
python -c 'from urllib.request import getproxies; print(getproxies())'   # what Python sees
systemctl show my-api -p Environment -p EnvironmentFiles  # what a service actually gets
curl -v https://api.example.com/                          # via proxy (uses the env)
curl -v --noproxy api.example.com https://api.example.com/   # direct, to compare
```

Note that a systemd service does **not** inherit your shell's variables. Compare what the unit has with what your shell has.

Then the two-case test: build the default client and your real client against the same URL. If only one works, you're looking at this trap.

---

## **Before adding a custom transport** {#checklist}

- [ ] Do I need `transport=`, or just retries around requests?
- [ ] Will the client still honour `HTTP_PROXY`, `HTTPS_PROXY` and `NO_PROXY`? (It won't.)
- [ ] Is "direct or proxied" an explicit, tested decision?
- [ ] Do both `http://` and `https://` routes exist?
- [ ] Does `verify=True` work with the right CA bundle?
- [ ] Have I tested it in the real deployed environment, not just my shell?

---

## **Summary** {#summary}

- The environment proxy variables are a convention; `httpx` reads them through `urllib`'s `getproxies()`.
- The **client** picks a transport per URL. The **transport** just connects the way it was built.
- The line `allow_env_proxies = trust_env and transport is None` is the whole trap: **any** `transport=` turns off automatic proxy detection.
- `trust_env` on a transport is about TLS, not proxies.
- Fixes: don't pass a transport, or give the proxy/mounts explicitly.
