---
layout: post
title: "WSGI, ASGI, Django & FastAPI: How Python Web Servers Actually Work"
date: 2026-10-08
description: "The practical half: what happens when you run gunicorn or uvicorn, workers vs event loops, sync vs async handlers in FastAPI, middleware, lifespan, dependency injection, and the deployment commands — with a worker-type cheat sheet."
categories: [Backend, Frameworks]
tags: [python, django, fastapi, asgi, uvicorn]
---

> **Server side mini-series:** [1. How a Request Reaches Your Code]({{ site.posts | where: "slug", "browser-to-route-function" | first.url | relative_url }}) · **2. WSGI, ASGI, Django & FastAPI in practice**
{: .prompt-info}

[Part 1]({{ site.posts | where: "slug", "browser-to-route-function" | first.url | relative_url }}) settled who speaks what: nginx at the edge, an app server translating HTTP into a Python call, and WSGI/ASGI as the calling conventions. This post is the practical half — what happens when you actually *run* these servers, how requests flow, where the event loop lives, and when sync vs async matters.

---

## **1. The two protocol standards** {#standards}

Python web applications talk to web servers through a **standard interface**. There are two:

### **WSGI (Web Server Gateway Interface) — PEP 3333 (2003)**

The original standard. Synchronous, simple, battle-tested.

```python
# What a WSGI app looks like under the hood:
def application(environ, start_response):
    """
    environ:        dict with HTTP request data (method, path, headers, body)
    start_response: callback to set status + headers
    Returns:        iterable of bytes (the response body)
    """
    start_response("200 OK", [("Content-Type", "text/plain")])
    return [b"Hello, World!"]
```

**One function call per request. Blocking. Returns when done.**

Used by: Django, Flask, Bottle, Pyramid, and most pre-2018 Python web frameworks.

### **ASGI (Asynchronous Server Gateway Interface) — 2018**

The async successor. Handles HTTP, WebSocket, and long-lived connections.

```python
# What an ASGI app looks like under the hood:
async def application(scope, receive, send):
    """
    scope:   dict describing the connection (type, path, headers)
    receive: awaitable — call to get incoming data
    send:    awaitable — call to send outgoing data
    """
    await send({
        "type": "http.response.start",
        "status": 200,
        "headers": [[b"content-type", b"text/plain"]],
    })
    await send({
        "type": "http.response.body",
        "body": b"Hello, World!",
    })
```

**Awaitable. Non-blocking. Can handle many concurrent connections on one thread.**

Used by: FastAPI, Starlette, Django 3.0+ (with `asgi.py`), Quart, Sanic.

### **Side-by-side**

| | WSGI | ASGI |
|---|---|---|
| Year | 2003 | 2018 |
| Spec | PEP 3333 | asgi.readthedocs.io (not a PEP) |
| Paradigm | Synchronous | Asynchronous (asyncio) |
| Request handling | One worker/thread per request | One event loop, many concurrent requests |
| WebSocket support | No | Yes |
| Streaming support | Limited (iterator) | Native (send chunks) |
| Server examples | gunicorn, uWSGI, mod_wsgi | uvicorn, daphne, hypercorn |
| Framework examples | Django, Flask | FastAPI, Starlette, Django 3.0+ |

---

## **2. How Django runs** {#django}

### **Development**

```bash
python manage.py runserver
```

This starts Django's **built-in development server** — a simple WSGI server for development only. It *is* multi-threaded by default (each request gets its own thread — I once proved it to myself with a `time.sleep(30)` view and two browsers: two requests, two thread IDs, handled in parallel). Still: never use it in production.

### **Production**

```bash
# gunicorn with sync workers (most common)
gunicorn myproject.wsgi:application --workers 4 --bind 0.0.0.0:8000

# gunicorn with async workers (for Django 4.1+ async views)
gunicorn myproject.asgi:application -k uvicorn.workers.UvicornWorker --workers 4
```

> Newer uvicorn versions deprecate `uvicorn.workers` in favour of the separate `uvicorn-worker` package (`-k uvicorn_worker.UvicornWorker`). The old path still works, with a warning.
{: .prompt-tip}

### **Django's process model**

```
gunicorn --workers 4 myproject.wsgi:application

       gunicorn (master process)
            │
    ┌───────┼───────┬───────┐
    │       │       │       │
 Worker1  Worker2  Worker3  Worker4
 (sync)   (sync)   (sync)   (sync)
    │       │       │       │
  1 req   1 req   1 req   1 req   ← one request at a time per worker
```

- 4 workers = 4 simultaneous requests max
- Each worker is a **full OS process** with its own memory
- If a request blocks for 30 seconds, that worker is stuck for 30 seconds
- To handle more concurrent requests, add more workers (but each costs ~50–100 MB RAM)

And remember from Part 1: **the server owns all of this**. Django never spawns a thread or process for a request — it's called, it answers, it's passive.

### **Django's entry files**

```python
# myproject/wsgi.py (auto-generated by django-admin startproject)
import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'myproject.settings')
application = get_wsgi_application()
# ^ this is the WSGI callable that gunicorn imports
```

```python
# myproject/asgi.py (Django 3.0+)
import os
from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'myproject.settings')
application = get_asgi_application()
# ^ the ASGI callable — used with uvicorn/daphne for async views
```

---

## **3. How FastAPI runs** {#fastapi}

### **Development**

```bash
uvicorn api.app:app --reload --host localhost --port 8000
# or in a uv-managed project:
uv run uvicorn api.app:app --reload
```

`--reload` watches for file changes and auto-restarts (like Django's runserver).

### **Production**

```bash
# Option 1: uvicorn directly with multiple workers
uvicorn api.app:app --workers 4 --host 0.0.0.0 --port 8080

# Option 2: gunicorn as process manager + uvicorn workers (recommended)
gunicorn api.app:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8080
```

Option 2 is preferred because gunicorn handles graceful worker restarts, auto-restart of crashed workers, pre-fork process management, and graceful shutdown on SIGTERM.

### **FastAPI's process model**

```
uvicorn api.app:app --workers 4

       uvicorn (master)
            │
    ┌───────┼───────┬───────┐
    │       │       │       │
 Worker1  Worker2  Worker3  Worker4
 (async)  (async)  (async)  (async)
    │       │       │       │
  event   event   event   event
  loop    loop    loop    loop
    │       │       │       │
  + thread pool (40 threads each)
    │       │       │       │
 100s of  100s of 100s of  100s of  ← concurrent connections per worker
 conns    conns   conns    conns
```

Each worker can handle hundreds of concurrent connections because:
- the event loop handles async I/O without blocking;
- a thread pool (default 40 threads) handles sync/blocking handlers;
- so one worker ≈ 40 concurrent blocking requests OR hundreds of async requests.

---

## **4. What happens when you type `uvicorn api.app:app`** {#startup}

```
uvicorn.main.run()
    │
    ▼
uvicorn.config.Config(app="api.app:app")
    │  Parses "api.app:app" into module="api.app", attr="app"
    │  Imports: from api.app import app
    ▼
uvicorn.server.Server(config)
    │
    ▼
asyncio.run(server.serve())          ← EVENT LOOP CREATED HERE
    │                                   (Python's standard asyncio loop)
    ▼
Inside serve():
    │
    ├─ await self.startup()
    │       │
    │       ├─ Open TCP socket on host:port
    │       ├─ Start listening for connections
    │       └─ Call your app's lifespan startup:
    │              your lifespan(app):
    │                  engine = Engine("configs/app.toml")
    │                  app.state.engine = engine
    │                  yield  ← startup complete, server ready
    │
    └─ Main loop: accept connections, dispatch to ASGI protocol handlers
         │
         ▼
    For each incoming HTTP request:
         │
         ├─ Parse raw TCP → HTTP request
         ├─ Build ASGI scope dict:
         │      scope = {"type": "http", "method": "GET",
         │               "path": "/health", "headers": [...]}
         ├─ Call: await app(scope, receive, send)
         │      │
         │      ▼
         │  FastAPI routing: path="/health" → @app.get("/health") → health()
         │      │
         │      ▼
         │  If handler is `async def`: run on the event loop directly
         │  If handler is `def`: run in the thread pool
         │      │
         │      ▼
         │  Handler returns dict → FastAPI serializes to JSON
         │      │
         │      ▼
         │  Response sent back via `send()` → uvicorn writes to the TCP socket
         │
         └─ Connection closed (or kept alive for HTTP/1.1 keep-alive)
```

---

## **5. Sync vs async handlers in FastAPI** {#sync-async}

FastAPI supports BOTH sync and async handlers in the same app.

### **How it decides**

```python
# ASYNC handler — runs directly on the event loop
@app.get("/health")
async def health():
    return {"status": "ok"}

# SYNC handler — FastAPI auto-runs it in the thread pool
@app.post("/reports/generate")
def generate(payload: ReportInputSchema):
    result = engine.reports.generate(...)   # blocks for 30 seconds — fine here
    return {"report": result}
```

FastAPI inspects the function at startup: `async def` → scheduled on the event loop; plain `def` → dispatched to the worker's thread pool so the loop stays free.

### **When to use which**

| Situation | Use | Why |
|---|---|---|
| Handler calls async I/O (`httpx.AsyncClient`, `asyncpg`, `aiofiles`) | `async def` | Direct event loop, no thread overhead |
| Handler does blocking I/O (sync DB driver, file reads, sync SDKs) | `def` | FastAPI auto-threads it, event loop stays free |
| Handler is pure CPU (math, parsing) | `def` | Thread pool takes it; loop stays responsive |
| Handler mixes async AND blocking I/O | `async def` + `await asyncio.to_thread(blocking_fn)` | Thread the blocking parts manually |

### **The critical mistake to avoid**

```python
# ❌ WRONG — blocks the entire event loop for 30 seconds
# ALL other requests on this worker are frozen during that time
@app.post("/reports/generate")
async def generate(payload):
    result = engine.reports.generate(...)   # BLOCKING call in an async handler!
    return {"report": result}

# ✅ CORRECT — plain def: runs in the thread pool, loop stays free
@app.post("/reports/generate")
def generate(payload):
    result = engine.reports.generate(...)
    return {"report": result}

# ✅ ALSO CORRECT — explicitly thread the blocking call
@app.post("/reports/generate")
async def generate(payload):
    result = await asyncio.to_thread(engine.reports.generate, ...)
    return {"report": result}
```

**Rule of thumb:** if your code uses `await`, use `async def`. If it doesn't, use `def`. FastAPI handles the rest.

---

## **6. The event loop — what it actually is** {#event-loop}

An event loop is a **single-threaded scheduler for I/O operations**:

```
Event Loop (single thread):
    ┌──────────────────────────────────────────┐
    │  time →                                  │
    │                                          │
    │  Request A: ████░░░░░░████  (await I/O)  │
    │  Request B:     ████░░░████              │
    │  Request C:         ████████             │
    │                                          │
    │  █ = CPU work (parsing, serializing)     │
    │  ░ = parked (awaiting network I/O)       │
    │      Other requests run during gaps      │
    └──────────────────────────────────────────┘
```

When Request A hits `await client.get("https://external-api.example.com/...")`:
1. the loop **parks** A (it's waiting for the network);
2. the loop **picks up** B or C and runs their code;
3. when A's response arrives, the loop **resumes** A.

That's why one thread can juggle hundreds of concurrent async requests — most of the time, handlers are waiting on I/O, not computing.

In uvicorn the loop is created by `asyncio.run(server.serve())` — one loop per worker, owned by the server, never by your code. If `uvloop` is installed, uvicorn automatically uses it instead: a C (Cython) drop-in replacement for asyncio's loop, 2–4x faster for I/O-heavy workloads, zero code changes.

---

## **7. Middleware — how it chains** {#middleware}

Same onion model in both worlds; the ASGI one is async.

```python
# Django (sync chain) — wraps the view
class TimingMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        start = time.time()
        response = self.get_response(request)   # next middleware or view
        response["X-Duration"] = str(time.time() - start)
        return response
```

```python
# FastAPI/Starlette (async chain) — wraps the ASGI app
@app.middleware("http")
async def timing_middleware(request: Request, call_next):
    start = time.time()
    response = await call_next(request)         # next middleware or route
    response.headers["X-Duration"] = str(time.time() - start)
    return response
```

```
Request → M1 → M2 → View → M2 → M1 → Response
```

---

## **8. Lifespan — startup and shutdown** {#lifespan}

```python
# Django: runs once at startup
class MyAppConfig(AppConfig):
    def ready(self):
        import myapp.signals        # register signal handlers
```

```python
# FastAPI: lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── STARTUP ──
    engine = Engine("configs/app.toml")
    app.state.engine = engine
    yield
    # ── SHUTDOWN ── cleanup goes here

app = FastAPI(lifespan=lifespan)
```

The `yield` is the hinge: everything before it runs at startup, everything after at shutdown — and the server only starts accepting requests once startup completes. Heavy one-time setup (DB pools, model loading, config parsing) belongs here, in `app.state`, not at import time.

---

## **9. Dependency injection — FastAPI's killer feature** {#depends}

```python
def get_engine(request: Request) -> Engine:
    return request.app.state.engine

@router.post("/reports/generate")
def generate(
    payload: ReportInputSchema,
    engine: Engine = Depends(get_engine),    # injected automatically
):
    return {"report": engine.reports.generate(...)}
```

FastAPI resolves the dependency tree before calling the handler. Dependencies can be `async def` or `def`, can depend on other dependencies, and can use `yield` for cleanup (DB session per request is the classic). Django's equivalent is manual — middleware or a custom decorator.

---

## **10. Deployment patterns** {#deploy}

```bash
# ─── Development ───
python manage.py runserver 0.0.0.0:8000                       # Django
uvicorn api.app:app --reload --host 0.0.0.0 --port 8000       # FastAPI

# ─── Production, single machine ───
gunicorn myproject.wsgi:application --workers 4 --bind 0.0.0.0:8000 --timeout 120   # Django
uvicorn api.app:app --workers 4 --host 0.0.0.0 --port 8080                          # FastAPI (A)
gunicorn api.app:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8080      # FastAPI (B, recommended)
```

```dockerfile
# ─── Docker ───
CMD ["uvicorn", "api.app:app", "--host", "0.0.0.0", "--port", "8080"]
```

```nginx
# ─── Behind nginx (same shape for Django and FastAPI) ───
upstream backend {
    server 127.0.0.1:8080;
}

server {
    listen 80;
    server_name myapp.example.com;

    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket support (ASGI apps):
    location /ws {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

Why nginx is there at all — TLS, static files, slow-client buffering, virtual hosts — is [Part 1's closing act]({{ site.posts | where: "slug", "browser-to-route-function" | first.url | relative_url }}#why-nginx).

---

## **11. Worker types cheat sheet** {#workers}

| Server / flag | Worker type | Protocol | Concurrency model |
|---|---|---|---|
| `gunicorn -k sync` | Sync | WSGI | 1 request per worker (process) |
| `gunicorn -k gthread` | Threaded | WSGI | N threads per worker |
| `gunicorn -k gevent` | Greenlet | WSGI | Cooperative multitasking (monkey-patched) |
| `gunicorn -k uvicorn.workers.UvicornWorker` | Async | ASGI | Event loop + thread pool per worker |
| `uvicorn --workers N` | Async | ASGI | Same, with built-in multiprocessing |
| `daphne` | Async | ASGI | Twisted event loop |
| `hypercorn` | Async | ASGI | Supports HTTP/2 and HTTP/3 |

---

## **12. Mental model summary** {#summary}

```
                    Django (WSGI)                    FastAPI (ASGI)
                    ─────────────                    ──────────────
Entry point:        manage.py runserver              uvicorn api.app:app
Prod server:        gunicorn wsgi:app                gunicorn -k UvicornWorker
Protocol:           WSGI (sync)                      ASGI (async)
Event loop:         None (thread per request)        asyncio (one per worker)
Blocking handler:   Normal — worker is busy          Auto-threaded by FastAPI
Async handler:      Django 4.1+ only                 Native — async def
WebSocket:          Django Channels (add-on)         Built-in
Auto docs:          None (use drf-spectacular)       Built-in (/docs, /redoc)
Dependency inject:  Manual (middleware/decorators)   Depends() — framework-native
Serialization:      Django REST Framework            Pydantic (built-in)
```

The core insight: **Django was built for the synchronous web (2005). FastAPI was built for the async web (2018).** Both work. Django brings the bigger ecosystem and its ORM; FastAPI brings async concurrency for I/O-heavy workloads (external API calls, LLM calls, many slow upstreams) and auto-generated docs. Pick by workload, not by fashion.
