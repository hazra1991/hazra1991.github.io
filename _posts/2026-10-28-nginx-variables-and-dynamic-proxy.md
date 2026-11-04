---
layout: post
title: "Nginx (Extra): Variables, set and a Dynamic Proxy"
date: 2026-10-28
description: "One real config dissected: a location that proxies to whatever URL the request names. Directives vs built-in vs user-defined variables, $arg_*, set, proxy_pass with a variable, resolver and DNS at request time, Host and SNI towards the remote server, and SSRF."
categories: [Deployment, Nginx]
tags: [nginx, proxy_pass, variables, dns, security]
---

> **Nginx series:** [1. How Nginx Runs]({{ site.posts | where: "slug", "nginx-part-1" | first.url | relative_url }}) · [2. Routing Requests]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}) · [3. Internal Requests & Auth]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}) · [4. Gateway Auth in Practice]({{ site.posts | where: "slug", "nginx-part-4" | first.url | relative_url }}) · **Extra: Variables & Dynamic Proxy** · [Refresher & Quick Reference]({{ site.posts | where: "slug", "nginx-quick-reference" | first.url | relative_url }})
{: .prompt-info}

Every `proxy_pass` in this series points at a **fixed** backend. This post takes apart one config where the destination is chosen **per request**, from the request's own query string. Reading it line by line teaches what nginx variables are, how `set` creates your own, and what changes once the destination isn't known in advance: DNS at request time, `Host` and SNI towards the remote server, and a serious security risk.

It builds on [Part 2]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}): `proxy_pass` ([9.5]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-5)), the path rule ([9.6.1]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-6-1)), the `Host` header ([9.9]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-9)) and the [phases]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#phases).

<details>
<summary><strong>📑 Table of Contents</strong></summary>
<div markdown="1">

- [21. A Dynamic Proxy, Line by Line](#sec-21)
  - [21.1 What does this configuration do?](#sec-21-1)
  - [21.2 Directives vs. built-in variables vs. user-defined variables](#sec-21-2)
  - [21.3 Built-in variables: `$arg_*` and friends](#sec-21-3)
  - [21.4 `set` — your own variables](#sec-21-4)
  - [21.5 `proxy_pass $upstream` — the destination comes from the request](#sec-21-5)
  - [21.6 `resolver` — DNS at request time](#sec-21-6)
  - [21.7 `$proxy_host` and `proxy_ssl_server_name` — talking to the remote server](#sec-21-7)
  - [21.8 `add_header` — the other direction](#sec-21-8)
  - [21.9 ⚠️ Security: SSRF](#sec-21-9)
  - [21.10 Final mental model](#sec-21-10)

</div>
</details>

---

## **21. A Dynamic Proxy, Line by Line** {#sec-21}

The config:

```nginx
location /__catalog-fetch {
    #resolver 8.8.8.8 valid=30s;
    resolver 10.20.0.2 valid=60s;

    set $upstream $arg_url;

    proxy_pass $upstream;

    proxy_set_header Host $proxy_host;

    proxy_ssl_server_name on;
}
```

> Everything below was checked against the official docs and on a test nginx (1.30). Where a behaviour is easy to get wrong, the test result is shown.
{: .prompt-info}

### **21.1 What does this configuration do?** {#sec-21-1}

Unlike a fixed proxy such as:

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:8000;
}
```

the `/__catalog-fetch` location dynamically determines the destination from the incoming request's `url` query parameter.

For example:

```http
GET /__catalog-fetch?url=https://example.com/api/catalog
```

Conceptually, Nginx:

1. Matches the `/__catalog-fetch` location.
2. Extracts the `url` query parameter.
3. Assigns that value to `$upstream`.
4. Resolves the destination hostname using the configured DNS resolver if necessary.
5. Proxies the request to the evaluated destination.
6. Sets the outgoing HTTP `Host` header.
7. Enables TLS Server Name Indication (SNI) for HTTPS upstreams.
8. Relays the upstream response to the client.

**This is a dynamic reverse proxy.** The destination is selected at request time, not fixed in the configuration.

A typical reason for such a location: the frontend needs data from a URL it can't fetch itself (another origin without CORS headers, or a host the user's network can't reach), so it asks its own nginx to fetch it ([who can reach what: Part 4, 20.2]({{ site.posts | where: "slug", "nginx-part-4" | first.url | relative_url }}#sec-20-2)).

### **21.2 Directives vs. built-in variables vs. user-defined variables** {#sec-21-2}

Three kinds of words appear in this config. Telling them apart is what makes it readable.

**A. Directives** tell Nginx how to configure or process requests:

```nginx
resolver 10.20.0.2;
proxy_pass $upstream;
set $upstream $arg_url;
```

**B. Built-in variables** expose request and Nginx state:

```nginx
$host
$remote_addr
$arg_url
$proxy_host
```

**C. User-defined variables** are defined using supported Nginx configuration mechanisms:

```nginx
set $upstream $arg_url;
set $my_name "abhishek";
```

Therefore:

```nginx
set $upstream $arg_url;
```

means:

> Use the built-in `set` directive to assign the value of the built-in `$arg_url` variable to the user-defined `$upstream` variable.

And:

```nginx
proxy_pass $upstream;
```

means:

> Proxy the request to the destination represented by that variable.

(Variables also come from other directives: `auth_request_set` in [Part 3]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-14-7) and `map` in [21.9](#sec-21-9) create them too.)

### **21.3 Built-in variables: `$arg_*` and friends** {#sec-21-3}

**Is `$arg_url` predefined?** Yes. Nginx exposes query parameters using the built-in variable family:

```nginx
$arg_name
```

For this request:

```http
GET /search?name=abhishek&page=2&limit=10
```

The variables are:

```text
$arg_name  = abhishek
$arg_page  = 2
$arg_limit = 10
```

You do not declare these variables. Nginx derives them from the query string.

Compare:

```nginx
set $username $arg_name;
```

- `$arg_name` is built in.
- `$username` is user defined.

> **Two traps with `$arg_*` (tested):**
> - The value is **not URL-decoded**. `?url=https%3A%2F%2Fexample.com%2Fcatalog` gives `$arg_url = https%3A%2F%2Fexample.com%2Fcatalog`, and `proxy_pass` fails with `invalid URL prefix` → **500**. The caller must send the URL unencoded.
> - An `&` inside the value **ends it**. `?url=https://example.com/a?b=1&c=2` gives `$arg_url = https://example.com/a?b=1`; `c=2` becomes a separate argument. A missing `url` gives an empty string → `invalid URL prefix in ""` → **500**.
{: .prompt-warning}

The same naming patterns work for headers and cookies:

```nginx
$http_authorization      # the incoming HTTP header named Authorization
$http_x_custom_header    # the incoming HTTP header named X-Custom-Header
$cookie_session          # the cookie named session
```

Nginx's incoming-header variables use lowercase names with hyphens represented as underscores. (The full set of header families, including the backend's response headers `$upstream_http_*`: [Part 3, 16.4]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-16-4).)

**Common built-in Nginx variables:**

| Variable | Meaning |
|---|---|
| `$host` | Requested hostname, with fallback behavior ([Part 2, 8.2]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#host-variables)) |
| `$http_host` | Incoming `Host` header |
| `$remote_addr` | IP of the client connection to Nginx |
| `$remote_port` | Client connection port |
| `$server_addr` | Local IP address receiving the connection |
| `$server_port` | Local listening port |
| `$scheme` | Request scheme, such as HTTP or HTTPS |
| `$request_uri` | Original URI including the query string |
| `$uri` | Current normalized URI |
| `$args` | Query-string arguments |
| `$arg_name` | Value of query parameter `name` |
| `$request_method` | HTTP request method |
| `$http_user_agent` | Incoming `User-Agent` header |
| `$http_authorization` | Incoming `Authorization` header |
| `$proxy_host` | Host and port of the proxied destination |
| `$upstream_addr` | Address of the upstream server used for the request |
| `$status` | Response status code |

### **21.4 `set` — your own variables** {#sec-21-4}

```nginx
set $upstream $arg_url;
```

`set` is a built-in Nginx directive from the rewrite module. Its syntax is:

```nginx
set $variable value;
```

For example:

```nginx
set $my_name "abhishek";
```

The variable `$my_name` then has the value `abhishek` in the applicable request-processing context.

In the original line:

- **`$upstream`** is a user-defined variable assigned by `set`.
- **`$arg_url`** is a built-in Nginx variable containing the incoming `url` query parameter.

Given:

```http
GET /__catalog-fetch?url=https://example.com/catalog
```

Nginx evaluates:

```text
$arg_url = https://example.com/catalog
$upstream = https://example.com/catalog
```

This is Nginx configuration processing, not JavaScript execution.

> **When it runs:** `set` belongs to the rewrite module, so it runs in the **rewrite phase**, before access checks and long before `proxy_pass` (content phase) uses the value. Line order doesn't matter; the [phases]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#phases) do.
{: .prompt-info}

### **21.5 `proxy_pass $upstream` — the destination comes from the request** {#sec-21-5}

Compare:

```nginx
proxy_pass http://127.0.0.1:8000;
```

This sends matching requests to a fixed backend.

But:

```nginx
proxy_pass $upstream;
```

uses a destination evaluated from the variable.

Example A:

```http
GET /__catalog-fetch?url=https://example.com/catalog
```

```text
$upstream = https://example.com/catalog
```

Example B:

```http
GET /__catalog-fetch?url=https://another.example.org/data
```

```text
$upstream = https://another.example.org/data
```

Thus the same Nginx location can contact different upstream hosts.

**Which path does the remote server receive?** With variables, the normal path rule ([Part 2, 9.6.1]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-6-1)) no longer replaces a prefix. Tested:

| `$upstream` evaluates to | Remote server receives | Why |
|---|---|---|
| `http://remote:8081/catalog` (has a path) | `/catalog` | the URL is used **as is**; the client's path and its `?url=...` are not added |
| `http://remote:8081` (no path) | `/__catalog-fetch?url=http://remote:8081` | no path → the **original request URI** is sent, like any `proxy_pass` without a path |

So the caller must always pass a full URL including the path.

### **21.6 `resolver` — DNS at request time** {#sec-21-6}

```nginx
resolver 10.20.0.2 valid=60s;
```

`resolver` is a built-in Nginx directive that configures DNS servers for applicable runtime hostname resolution.

- `10.20.0.2` is the DNS server Nginx will query.
- `valid=60s` overrides the cached validity period of DNS answers to 60 seconds.

Why is this useful here?

```nginx
proxy_pass $upstream;
```

The destination hostname may change for each request. If `$upstream` evaluates to an HTTPS URL containing `example.com`, Nginx must resolve `example.com` to an IP address at runtime. The configured `resolver` supports that lookup.

Contrast a static proxy:

```nginx
proxy_pass http://backend.example.com;
```

Static upstream hostnames can be resolved during configuration loading, while variable-based upstream destinations can require Nginx's runtime resolver.

The line:

```nginx
#resolver 8.8.8.8 valid=30s;
```

is commented out and has no effect. The active resolver is `10.20.0.2`.

**What "resolved during configuration loading" means in practice (tested):**

| Situation | What happens |
|---|---|
| Fixed name, `proxy_pass http://backend.example.com;` | looked up **once**, at start / reload. Name doesn't resolve → `nginx -t` fails: `host not found in upstream`. Its IP changes later → nginx keeps using the **old** IP until the next reload. |
| Variable with a hostname, **no** `resolver` | every request → **502**, error log: `no resolver defined to resolve <name>` |
| Variable with a hostname, with `resolver` | looked up at request time, cached for `valid=` |
| Variable with an **IP** (`http://10.1.1.1:8000/...`) | no DNS needed; works without `resolver` |

> **Fixed backend, but its IP changes** (a cloud load balancer, a container that gets re-created)? You don't need variables for that: since nginx **1.27.3** the free version supports `resolve` on upstream servers, which re-resolves the name while running:
>
> ```nginx
> resolver 10.20.0.2;
> upstream catalog {
>     zone catalog 64k;                       # required: the group lives in shared memory
>     server catalog.example.com resolve;     # re-resolved as DNS changes, no reload
> }
> ```
>
> Inside Docker, the resolver for container names is Docker's embedded DNS at `127.0.0.11` ([Docker Networking Part 1]({{ site.posts | where: "slug", "docker-networking-part-1" | first.url | relative_url }})).
{: .prompt-tip}

### **21.7 `$proxy_host` and `proxy_ssl_server_name` — talking to the remote server** {#sec-21-7}

**What is `$proxy_host`?**

```nginx
proxy_set_header Host $proxy_host;
```

`$proxy_host` is a built-in Nginx variable representing the hostname and port of the proxied destination as specified by `proxy_pass`.

Suppose the browser sends:

```http
GET /__catalog-fetch?url=https://example.com/catalog HTTP/1.1
Host: 10.20.30.185
```

Then, conceptually:

```text
$host       = 10.20.30.185
$proxy_host = example.com
```

- `$host` refers to the hostname requested by the browser, with Nginx fallback rules.
- `$proxy_host` refers to the host of the upstream destination (including the port if it isn't the default one, e.g. `example.com:8443`).

Therefore:

```nginx
proxy_set_header Host $proxy_host;
```

causes the proxied HTTP request to contain:

```http
Host: example.com
```

This matters because an upstream HTTP server may host several applications on one IP and use the `Host` header to select the correct one.

> `Host $proxy_host` is already nginx's **default** ([Part 2, 9.9]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sec-9-9)), so this line only makes it explicit. The real mistake is the opposite one: copying the usual `proxy_set_header Host $host;` into a location like this would send *our* name (`10.20.30.185`) to `example.com`, which then can't find the right site.
{: .prompt-warning}

**What does `proxy_ssl_server_name on` mean?**

```nginx
proxy_ssl_server_name on;
```

This enables **Server Name Indication (SNI)** when Nginx makes a TLS connection to an HTTPS upstream. (SNI from the browser's side: [Part 2, HTTPS]({{ site.posts | where: "slug", "nginx-part-2" | first.url | relative_url }}#sni).)

For example, when connecting to `https://example.com`, Nginx can indicate the intended hostname during the TLS handshake. This allows an HTTPS server hosting multiple names to select the appropriate certificate.

The default SNI name is derived from `$proxy_host` unless `proxy_ssl_name` overrides it. The directive itself is **off by default**, which is why it has to be written: without it, servers hosting many names (CDNs, shared hosting) can't tell which site is meant and fail the handshake or present the wrong certificate.

These two directives operate at different layers:

```nginx
proxy_set_header Host $proxy_host;
```

Sets the HTTP request's `Host` header.

```nginx
proxy_ssl_server_name on;
```

Enables sending the upstream server name in the TLS handshake.

**Important:** Enabling SNI does not itself enable upstream certificate verification. That is configured separately with `proxy_ssl_verify` and appropriate trust settings. `proxy_ssl_verify` is **off by default**: nginx accepts *any* certificate from the remote server. To check it (tested against a public site):

```nginx
proxy_ssl_verify              on;
proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;   # CA bundle (path on Debian/Ubuntu/Alpine)
proxy_ssl_verify_depth        2;    # default 1 fails on usual public chains: "unable to get local issuer certificate"
```

### **21.8 `add_header` — the other direction** {#sec-21-8}

`add_header` is a built-in Nginx directive that adds **response headers** sent to the client. Compare the two directions.

**`proxy_set_header`: request direction**

```nginx
proxy_set_header X-Real-IP $remote_addr;
```

```text
Browser -> Nginx -> Upstream
```

This sets a header on the HTTP request Nginx sends to the upstream.

**`add_header`: response direction**

```nginx
add_header X-App-Name "devicehub";
```

```text
Upstream -> Nginx -> Browser
```

The browser can receive:

```http
HTTP/1.1 200 OK
X-App-Name: devicehub
Content-Type: application/json
```

By default, `add_header` applies only to certain response status codes. To add it regardless of status:

```nginx
add_header X-App-Name "devicehub" always;
```

(All four messages of a proxied request and which directive changes which: [Part 3, 16]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-16).)

### **21.9 ⚠️ Security: SSRF** {#sec-21-9}

Accepting an arbitrary client-controlled destination in:

```nginx
set $upstream $arg_url;
proxy_pass $upstream;
```

can expose a **server-side request forgery (SSRF)** vulnerability. Untrusted clients may try to make Nginx connect to internal services, loopback addresses, cloud metadata endpoints, or other unintended destinations.

For production, consider:

- Allowlisting approved upstream hosts.
- Restricting URL schemes and ports.
- Blocking inappropriate private, loopback, and link-local destinations.
- Accounting for DNS changes, redirects, and other bypass paths.
- Applying authentication and network access controls.

Do not expose this as an unrestricted URL proxy.

**An allowlist in nginx itself** with `map`, which sets a variable from a pattern match (defined in `http {}`; tested):

```nginx
map $arg_url $catalog_allowed {
    default 0;
    "~^https://(catalog\.example\.com|data\.example\.org)(:\d+)?/" 1;   # scheme + exact host + optional port + "/"
}

server {
    ...
    location /__catalog-fetch {
        if ($catalog_allowed = 0) { return 403; }    # rewrite phase: refused before any connection is made
        resolver 10.20.0.2 valid=60s;
        set $upstream $arg_url;
        proxy_pass $upstream;
        proxy_set_header Host $proxy_host;
        proxy_ssl_server_name on;
    }
}
```

The pattern requires the host to be followed by `/` or `:port/`, so look-alikes are refused: `https://catalog.example.com.evil.com/` and `https://catalog.example.com@evil.com/` both get 403. Add `auth_request` ([Part 3, 14.5]({{ site.posts | where: "slug", "nginx-part-3" | first.url | relative_url }}#sec-14-5)) if only logged-in users should use it.

### **21.10 Final mental model** {#sec-21-10}

```text
Browser request:
/__catalog-fetch?url=https://example.com/catalog
         |
         v
Nginx matches location /__catalog-fetch
         |
         v
$arg_url is read from the query string
         |
         v
set $upstream $arg_url
         |
         v
proxy_pass $upstream
         |
         +--> resolver looks up destination hostname if needed
         |
         +--> Host header is set from $proxy_host
         |
         +--> SNI is enabled for HTTPS upstreams
         |
         v
Remote upstream responds
         |
         v
Nginx relays response to browser
```

> **Key takeaway:** Nginx directives define behavior; built-in variables expose request/runtime information; user-defined variables let you reuse calculated values. Here, a request parameter controls the upstream destination, which is powerful but must be carefully secured.
{: .prompt-tip}

A table of common directives, including every one used here, is in the [quick reference]({{ site.posts | where: "slug", "nginx-quick-reference" | first.url | relative_url }}#ref-directives).
