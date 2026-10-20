---
layout: post
title: "CORS and the OPTIONS Request You Never Sent"
date: 2026-10-20
description: "DevTools shows an OPTIONS request your code never made, answered with methods your path doesn't even have. Who sends it, who answers it, and why the allowed-methods list comes from CORS configuration, not from your routes — the same story in every stack, from Django to Express to nginx."
categories: [Backend, Web Fundamentals]
tags: [http, cors, browser, fundamentals]
---

You open DevTools to debug an API call and there it is: an `OPTIONS` request **you never wrote**, status `204 No Content`, and a response header proudly listing `DELETE` on a path that has no delete at all.

Three questions, then: *who sent that request? who answered it? and why is the list wrong?* None of this is a Django thing, a FastAPI thing or an Express thing. It's a **browser** thing — the frameworks only show up at the very end, as interchangeable extras.

> **What we'll cover**
> 1. [Origins, and the browser's suspicion](#origin)
> 2. [The preflight conversation](#preflight)
> 3. [Who answers it (not your code)](#who-answers) — with proof
> 4. [Then where does the *real* method list live?](#allow)
> 5. [What blocking actually looks like](#blocked)
{: .prompt-info}

---

## **Origins, and the browser's suspicion** {#origin}

An **origin** is scheme + host + port: `https://frontend-app.com` and `https://api.example.com` are two different origins, even if one page talks to the other all day.

Browsers are suspicious of cross-origin calls by design — any random page you visit could otherwise script requests to your bank. So when JavaScript on origin A calls origin B, the browser demands that **B explicitly says A is welcome**. That whole permission dance is **CORS** (Cross-Origin Resource Sharing), and it's defined for the web as a whole; every server stack merely answers its part.

---

## **The preflight conversation** {#preflight}

For anything beyond a plain request, the browser doesn't fire your `POST` straight away. It first sends a little scout — **that's the OPTIONS request you never wrote**:

```http
OPTIONS /api/files/ HTTP/1.1
Origin: https://frontend-app.com
Access-Control-Request-Method: POST
Access-Control-Request-Headers: authorization
```

In words: *"I'm a page from `frontend-app.com`, about to send a `POST` with an `Authorization` header. Are you okay with that?"* If the server approves:

```http
HTTP/1.1 200 OK
Access-Control-Allow-Origin: https://frontend-app.com
Access-Control-Allow-Methods: DELETE, GET, OPTIONS, PATCH, POST, PUT
Access-Control-Allow-Headers: accept, authorization, content-type, ...
```

…the real `POST` follows. This is the **CORS preflight**. `OPTIONS` itself is just an ordinary HTTP method like `GET` or `POST` — but it carries no data; its whole job is negotiating what's allowed.

Not every cross-origin request gets one: a simple `GET`, or a form-style `POST` with no special headers, goes out directly (the response still needs `Access-Control-Allow-Origin`). The moment you add an `Authorization` header or send JSON, the preflight appears. That header in the scout above is exactly why mine showed up.

---

## **Who answers it — not your code** {#who-answers}

Here's the part that answers the mystery, and it's the same design in every stack. You never write a view for `OPTIONS`. Instead you enable some **CORS layer** and hand it a configuration — which origins, which methods, which headers:

```text
Django   →  corsheaders middleware   +  CORS_ALLOWED_ORIGINS = [...]
FastAPI  →  CORSMiddleware           +  allow_origins=[...]
Express  →  app.use(cors({...}))
nginx    →  add_header Access-Control-Allow-* (answering preflights itself)
```

That layer sits **in front of your routes** and intercepts every preflight before routing even happens. I proved it to myself on one of these stacks by defining only these endpoints:

```text
GET  /files/          POST /files/
GET  /files/{name}    DELETE /files/{name}
```

and then preflighting a URL that **doesn't exist at all**:

```
OPTIONS /api/no/such/route   (Origin + Access-Control-Request-Method set)

200 OK
Access-Control-Allow-Methods: DELETE, GET, OPTIONS, PATCH, POST, PUT
```

A dead URL "allows" six methods. Nobody checked, because nobody *could* check — your routes were never consulted. The methods list is simply the CORS layer reciting its configured (or default) allow-list.

So when DevTools shows `DELETE` as "allowed" on a path with no delete handler: the preflight answer means *"requests of this shape may be attempted"*, not *"this endpoint supports them"*. Send that `DELETE` for real and the route still returns `405`. And if your allow-list looks different from your framework's default, that's your own config — or a proxy in front adding CORS headers — not anybody introspecting routes.

---

## **Then where does the real method list live?** {#allow}

With the routes — and HTTP already has a header for it: **`Allow`**. Strip the `Origin` header (so the request no longer looks like a preflight) and the same `OPTIONS` sails past the CORS layer into the framework, which finally checks the path:

```
OPTIONS /api/files/      → 405,  Allow: POST, GET
OPTIONS /api/files/abc   → 405,  Allow: DELETE, GET
```

That `Allow` header is the truth, built per path from what was actually defined. The two lists serve different masters:

```
Access-Control-Allow-Methods  →  CORS config      ("what cross-origin traffic may try")
Allow                         →  your routes      ("what this path really supports")
```

How politely a framework answers the routed `OPTIONS` varies — some reply `405` with `Allow`, some implement `OPTIONS` and auto-expose `HEAD` alongside every `GET` (the HTTP spec expects GET-capable resources to handle `HEAD`). House manners. The split above is the universal part.

---

## **What blocking actually looks like** {#blocked}

One last test: a preflight from an origin *not* in the allowlist. The server still answered `200` — but with **none** of the `Access-Control-Allow-*` headers. That's the whole trick:

> The server never blocks anything. It just withholds the welcome headers, and the **browser** refuses to proceed. CORS protects people in browsers; `curl` and server-to-server calls ignore it entirely.
{: .prompt-warning}

Which also explains the error you've seen a hundred times — *"No 'Access-Control-Allow-Origin' header is present"* — the browser telling you the welcome never came.

---

## **Summary** {#summary}

- `OPTIONS` is a normal HTTP method used for asking, not for data. The browser sends it automatically as a **CORS preflight** before non-simple cross-origin requests (an `Authorization` header or JSON body is enough to trigger it).
- Preflights are answered by whatever **CORS layer** you enabled — middleware, proxy, anything — **from its configuration, before routing**. Proof: a nonexistent URL returns the same allow-list.
- So `Access-Control-Allow-Methods` describes your **config**; the per-path truth is the **`Allow`** header. Two lists, two jobs.
- CORS is enforced by the **browser**, not the server — the server only decides whether to send the welcome headers.
- Django, FastAPI, Express, nginx: same conversation, different spelling of the config.
