---
layout: post  
title: "OpenTelemetry (OTel): Unified Observability, Simplified (Part 2)"
date: 2025-08-18
categories: ['tutorial','OpenTelemetry (OTel)']
tags: ['OTel','telemetry',tutorial]
slug: openTelemetry-unified-observability-part2
image:
  path: assets/images/covers/opentelemetry_banner.webp
  alt: OpenTelemetry (OTel) components
---

<details>
  <summary><strong>Table of Contents</strong></summary>

  <div markdown="1">

  - [Understanding OTel’s Schema, SDK Objects and OTel's components](#understanding-otels-schema-sdk-objects-and-otels-componets)
  - [Why Use OpenTelemetry SDKs?](#why-use-opentelemetry-sdks)
  - [OTEL Components and How Does OpenTelemetry Work?](#otel-components-and-how-does-opentelemetry-work)
    - [Specification — The Rulebook (Not the Schema Itself)](#specification--the-rulebook-not-the-schema-itself)
    - [Data Model — This Is the Schema](#data-model--this-is-the-schema)
    - [API — This Is the Interface (not the implementation)](#api-in-otel)
    - [SDK — Implements Interface + Handles Schema Generation](#sdk-in-otel)
    - [Instrumentation Libraries *(optional but common)*](#instrumentation-libraries-optional-but-common)
    - [Exporter in OpenTelemetry](#expoter-in-otel)
    - [Collector *(optional, but common)*](#collector-optional-but-common)
    - [Observability Backends](#backend-in-otel)
    - [OpenTelemetry Protocol (OTLP)](#opentelemetry-protocol-otlp)
  - [OTel’s Schema](#otels-schema)
    - [Some Questions About OTel’s Schema — Answered](#questions-about-otel)
  - [Mental Model of the schema](#mental-model-of-the-schema)
  - [Minimal Python code examples for getting the console output](#minimal-python-code-examples-for-getting-the-console-output)
  - [Trace Context Propagation Across Distributed Systems: How It Works](#trace-context-propagation-across-distributed-systems-how-it-works)
    - [Who Actually Handles Trace Context Propagation?](#who-actually-handles-trace-context-propagation)

  </div>
</details>



## Understanding OTel’s Schema, SDK Objects and OTel's componets 

### Why Use OpenTelemetry SDKs?

Sure, you *could* manually read the OTel spec, construct trace schemas field by field (trace IDs, span timings, nested attributes), serialize it in Protobuf, and push it over the wire...
😵‍💫 But why go through all that?
**OpenTelemetry SDKs do the heavy lifting for you:**

- Auto-generate valid telemetry data (`traces`, `metrics`, `logs`) ,Handle IDs, timestamps, and span relationships
- Follow OTel spec and ensure OTel-compliant, backend-ready data
- Expose simple APIs to add custom attributes and Work across languages.

Use pip to install the OpenTelemetry SDK, API, and a console exporter:

```shell
pip install opentelemetry-api
pip install opentelemetry-sdk
pip install opentelemetry-exporter-console
```
Think of SDKs as your **bridge** between application logic and observability infrastructure — **abstracting complexity** while **enforcing standards**. You focus on your app. The SDK handles the schema.

## OTEL Components and How Does OpenTelemetry Work?

OpenTelemetry is built from modular components that work together to collect, process, and export telemetry data (traces, metric  s, and logs). Let’s walk through the core components from left to right in the OpenTelemetry pipeline:

![image](assets/images/snaps/Otel.png)
*OpenTelemetry Components (Source: Based on [OpenTelemetry: beyond getting started](https://medium.com/opentelemetry/opentelemetry-beyond-getting-started-5ac43cd0fe26))*


[**API**](#api-in-otel) -> [**SDK**](#sdk-in-otel) -> [**Expoter**](#expoter-in-otel) -> [**Backend**](#backend-in-otel)

### Specification — The Rulebook (Not the Schema Itself)

The **OpenTelemetry Specification** is **not** a schema itself, but rather:

- A standardized description of **how telemetry should be structured and produced**  
  → **Kind of like an RFC or PEP guideline.**
- It defines: **Expected behaviors** ,**Interfaces**, **Exporting guidelines**, **Semantic conventions** (naming keys like `http.status_code`, `db.system`, etc.)
- Only the **OpenTelemetry specification committee** can modify these schemas  
  → This ensures **long-term stability** and **interoperability**.

👉 It ensures **cross-language consistency**, but does **not act as the schema** or implementation.

### Data Model — This Is the Schema

The **Data Model** is the actual **schema** for telemetry in OpenTelemetry.

It defines:

- ✅ What a **trace**, **span**, **metric**, or **log** looks like
- ✅ Required fields (e.g., `trace_id`, `span_id`, `start_time`)
- ✅ How signals relate (e.g., parent/child spans, metric resources)
- ✅ How to represent them in formats like **OTLP** (Protobuf / JSON)

✔️ **This is what SDKs and backends serialize and store**.  
It’s the canonical structure your telemetry data must follow.

***Examples***
[click here for exact schemas and understandings]({{ site.posts | where: "slug", "openTelemetry-unified-observability-part1" | first.url | relative_url }})

- **Span schema**: `trace_id`, `span_id`, `name`, `start_time`, `attributes[]`
- **Metric schema**: `instrumentation_scope`, `value`, `unit`, `timestamp`
- **Log schema**: `severity`, `message`, `trace_id`, `attributes[]`

### API — This Is the Interface (not the implementation) {#api-in-otel}

The **API** is the **language-specific interface** exposed to developers.

It defines:
- How your application interacts with OpenTelemetry (e.g., `start_span()`, `set_attribute()`)
- Does **not** contain logic for export, batching, or transport
- It’s defined in the spec but implemented per language

### SDK — Implements Interface + Handles Schema Generation {#sdk-in-otel}

The **SDK**:
- Implements the **API** (i.e., it’s the actual logic behind the interface)
- Generates telemetry data based on the **data mode**
- **Handles:** `Span lifecycle`, `Context propagation`, `Sampling decisions`, `Exporter communication`
- Encoding data per the OTEL data model and sending it via exporters (typically using OTLP)

>This is the **implementation layer** that uses the data model schema to build and emit the correct telemetry.
{: .prompt-tip}

### Instrumentation Libraries *(optional but common)*

Pre-built packages that auto-instrument popular frameworks and libraries (e.g., **Flask**, **Django**, HTTP clients, databases).  
They remove the need to manually write spans.

>🔌 **Plug-and-play observability** for common tools in your stack.
{: .prompt-tip}

### Exporter in OpenTelemetry {#expoter-in-otel}

An Exporter is a component within the SDK that:

- Takes the telemetry data generated by the SDK (spans, metrics, logs)
- Formats that data into a specific schema/encoding (e.g., OTLP, JSON, console)
- Sends (exports) it to:

  - A backend system (e.g., Jaeger, Prometheus, Tempo, Datadog)  
  - Or a user-readable output (e.g., terminal, file)

**Purpose**
```markdown
  AppCode -- API --> SDK --> Exporter --> Backend
```

How it works:
- SDK builds raw telemetry data objects (structured per the OTEL data model)
- The Exporter: 
  - **Parses these SDK objects** --> **Encodes them (Protobuf, JSON, etc.)** --> **Transmits them (over HTTP, gRPC, or prints to console)**

  
*Types of Exporters*

1. 🖥️ **Console / Debug Exporters**

- Output telemetry in human-readable format,Used for development/testing  
- Examples: `ConsoleSpanExporter`, `LoggingMetricExporter`  
- Output: JSON or plain text

2. 🛰️ **OTLP Exporters (Protobuf or JSON)**

- Use OTLP (OpenTelemetry Protocol), the official wire format, Preferred for production systems  
- Can transmit via gRPC or HTTP  
- Output: Strict schema, `binary (Protobuf) or JSON`  

Typically sent to:  
- OpenTelemetry Collector  
- Jaeger, Tempo, etc.

![Alt Text](assets/images/snaps/collector.png){: width="972" height="589" .w-50 .right}
### Collector *(optional, but common)*
A standalone service that acts as a **central telemetry hub**.
It receives telemetry (from SDKs or agents), optionally processes or transforms it, and then sends it to one or more backends. 
- Ingest from SDKs / Exporters, Apply filtering, enrichment, redaction, Forward to observability platforms,
- Exports to one or more backends (e.g., **Jaeger**, **Prometheus**, **Elasticsearch**, etc.)

### Observability Backends {#backend-in-otel}

This is where the telemetry data ends up — the final destination for **storage**, **analysis**, and **visualization**.

*Examples:*
- **Jaeger / Tempo** → Distributed tracing  
- **Prometheus / Grafana** → Metrics dashboards  
- **Loki / ELK** → Log search and analysis  
- **Datadog / New Relic / Dynatrace** → Commercial all-in-one platforms

### OpenTelemetry Protocol [(OTLP)]({{ site.posts | where: "slug", "openTelemetry-unified-observability-part1" | first.url | relative_url }}#as-a-protocol)

A standardized transport format used to transmit telemetry data between:

- **SDK/expoter ➝ backend**
- **SDK/Expoter ➝ Collector**  
- **Collector ➝ Backend**

Supports both **gRPC** and **HTTP**.

Efficient, binary, and supported by many major vendors like **Jaeger**, **Datadog**, **Tempo**, etc.
It’s the “language” OpenTelemetry speaks to move telemetry around.

## OTel’s Schema

In OpenTelemetry, “schemas” refer to the **official data structures** (formats, field names, and types) that telemetry data must conform to when exported or exchanged between components like SDKs, collectors, and backends.

They are **strictly defined and versioned** in the OpenTelemetry Protocol (OTLP) using **Protobuf files**.

###  These schemas define:
[For details on below refer here]({{ site.posts | where: "slug", "openTelemetry-unified-observability-part1" | first.url | relative_url }}#otels-three-pillars-traces-metrics-logs-with-schemas)
- The fields or keys, data types, and structure of:
  - **Traces** – spans, attributes, timing, status, etc.  
  - **Metrics** – gauges, counters, histograms  
  - **Logs** – timestamped records with severity, message, etc.
- What must be **included** (required fields)
- What is **optional or extensible** (like `attributes[]`)

**Where Are These Schemas Defined?**
The canonical source of truth is in the **opentelemetry-proto** repository:  
➡️ [https://github.com/open-telemetry/opentelemetry-proto](https://github.com/open-telemetry/opentelemetry-proto)

**Key Protobuf files:**
- `opentelemetry/proto/trace/v1/trace.proto` – Trace data (spans)  
- `opentelemetry/proto/metrics/v1/metrics.proto` – Metrics data  
- `opentelemetry/proto/logs/v1/logs.proto` – Log data  
- `opentelemetry/proto/common/v1/common.proto` – Shared types (e.g., attributes)  
- `opentelemetry/proto/resource/v1/resource.proto` – Telemetry resource data


### 🤔 Some Questions About OTel’s Schema — Answered {#questions-about-otel}

#### **What parts of the OTEL schema are fixed?**

The schema itself (the "shape" of the JSON/Protobuf message) is **fixed and standard**.  
That means:
- Top-level objects (`resourceSpans`, `scopeSpans`, `spans`, etc. for traces)
- Required fields like `traceId`, `spanId`, `name`, `startTimeUnixNano`, `endTimeUnixNano`
- Data types (`stringValue`, `intValue`, etc.)
You **cannot change these keys**.  
Every backend (Jaeger, Tempo, Honeycomb, Langfuse) expects **exactly this structure**.


####  **What parts are your custom data?**

- `name` → You set this.
    **Example:**
    - `"HTTP GET /users/:id"`
    - `"sub-step-1"`
    - `"generate-embedding"`

OTEL doesn’t decide this — you (or the SDK instrumentation) do.


- `attributes[]` → **This is the official "escape hatch" for custom metadata.**
  - **Example:**
    ```json
    "attributes": [
      { "key": "user.id", "value": { "stringValue": "alice" } },
      { "key": "langfuse.observation.input", "value": { "stringValue": "{\"x\": 5}" } }
    ]
    ```

>🔥 This is where Langfuse puts its extra stuff (langfuse.observation.input/output).
>🔥 You can add any key/value here, as long as the type is one of the allowed OTEL types (string, int, double, bool).
{: .prompt-info}

#### **What Parts Are Auto-Generated?**

- `traceId`, `spanId`, `parentSpanId` → Generated by the OTEL SDK (unless overridden)  
- `startTimeUnixNano`, `endTimeUnixNano` → Captured from system time by the SDK  
- `kind` → Defaults to `SPAN_KIND_INTERNAL`, but can be set (e.g., `SERVER`, `CLIENT`, `PRODUCER`, etc.)  
- `status` → Set by the SDK (`OK`, `UNSET`, `ERROR`), but can be overridden


<details>
  <summary><strong>Example: Your custom + auto-generated mix [click to expand]</strong></summary>

  <div markdown="1">

  ```json
    {
      "traceId": "4fd0c9e6e9c6bfb1a5f7d29d6c72b78f",   // auto
      "spanId": "6f9c2d7f8c4d1f32",                   // auto
      "parentSpanId": "0000000000000000",             // auto/unset
      "name": "generate-embedding",                   // YOU set
      "kind": "SPAN_KIND_INTERNAL",                   // default, can set
      "startTimeUnixNano": "1692288000000000000",     // auto
      "endTimeUnixNano": "1692288001000000000",       // auto
      "attributes": [                                 // YOU add custom metadata
        { "key": "user.id", "value": { "stringValue": "alice" } },
        { "key": "langfuse.observation.input", "value": { "stringValue": "{\"text\": \"hello\"}" } },
        { "key": "model.name", "value": { "stringValue": "gpt-4" } }
      ],
      "status": { "code": "STATUS_CODE_OK" }          // default, can set error
    }
  ```

  </div>
</details>


#### **Why do I see different outputs when printing telemetry data locally in the console?**

There are two different "shapes" of data you can see when working with OpenTelemetry in Python (or any language SDK):

before proceding lets clarify ,there are two exporters you can use with the official OpenTelemetry Python SDK:
- **ConsoleSpanExporter (debugging)** → prints a Python dict-like view, **not OTLP JSON**.  
  (This is the “not real one” . it will provide the debuging easy representation , its SDK based)
- **OTLPSpanExporter (real exporter)** → serializes spans to OTLP Protobuf (or OTLP JSON if configured).  
  (This is what actually goes on the wire to backends.)

**Python SDK internal span JSON (what you saw)**
<details>
  <summary>This is SDK’s debug object: [click to expand]</summary>

  <div markdown="1">

  ```json
    {
      "name": "sub-step-2",
      "context": {
        "trace_id": "0xd7600c1fd184882182df981dbcfe87dd",
        "span_id": "0x0f439fcbbe08d582",
        "trace_state": "[]"
      },
      "kind": "SpanKind.INTERNAL",
      "parent_id": "0xbcb606e5707fc548",
      "start_time": "2025-08-17T18:41:57.054572Z",
      "end_time": "2025-08-17T18:41:57.054848Z",
      "status": {
        "status_code": "UNSET"
      },
      "attributes": {
        "langfuse.observation.input": "{\"msg\": \"hello\"}",
        "langfuse.observation.type": "span",
        "langfuse.observation.output": "{\"msg\": \"world\"}"
      },
      "events": [],
      "links": [],
      "resource": {
        "attributes": {
          "telemetry.sdk.language": "python",
          "telemetry.sdk.name": "opentelemetry",
          "telemetry.sdk.version": "1.36.0",
          "service.name": "unknown_service"
        },
        "schema_url": ""
      }
    }
  ```
  </div>
</details>

>This is not the standard schema, just the SDK’s internal representation (Span + SpanContext). This will be showns if we use the debugging expoter `ConsoleSpanExporter`
{: .prompt-tip}

**OTLP JSON that actually gets sent on the wire**
When the OTLP exporter serializes, it must follow the `trace.proto` schema.  
The same span above looks like this (JSON view of Protobuf):

<details>
  <summary>The same span above looks like this (JSON view of Protobuf): [click to expand]</summary>

  <div markdown="1">

  ```json
  {
    "resourceSpans": [
      {
        "resource": {
          "attributes": [
            { "key": "telemetry.sdk.language", "value": { "stringValue": "python" } },
            { "key": "telemetry.sdk.name", "value": { "stringValue": "opentelemetry" } },
            { "key": "telemetry.sdk.version", "value": { "stringValue": "1.36.0" } },
            { "key": "service.name", "value": { "stringValue": "unknown_service" } }
          ]
        },
        "scopeSpans": [
          {
            "scope": {
              "name": "opentelemetry.sdk.trace"
            },
            "spans": [
              {
                "traceId": "d7600c1fd184882182df981dbcfe87dd",
                "spanId": "0f439fcbbe08d582",
                "parentSpanId": "bcb606e5707fc548",
                "name": "sub-step-2",
                "kind": "SPAN_KIND_INTERNAL",
                "startTimeUnixNano": "1692288117054572000",
                "endTimeUnixNano": "1692288117054848000",
                "attributes": [
                  { "key": "langfuse.observation.input", "value": { "stringValue": "{\"msg\": \"hello\"}" } },
                  { "key": "langfuse.observation.type", "value": { "stringValue": "span" } },
                  { "key": "langfuse.observation.output", "value": { "stringValue": "{\"msg\": \"world\"}" } }
                ],
                "status": {
                  "code": "STATUS_CODE_UNSET"
                }
              }
            ]
          }
        ]
      }
    ]
  }
  ```
  </div>
</details>

>This is the strict OTEL schema every backend understands
>This JSON structure follows the canonical `trace.proto` schema and is **exactly what every OpenTelemetry-compliant backend** expects — including **Jaeger**, **Tempo**, **Langfuse**, **Honeycomb**, and others.
Notice the key differences:

- `context.trace_id` → flattened into `"traceId"`  
- `parent_id` → becomes `"parentSpanId"`  
- `attributes` → always an **array of key/value pairs**, not a dictionary  
- `resource` → exists at the **resourceSpans level**, not inside each span  
- `Time fields` → represented in **Unix nanoseconds**, not ISO 8601 strings

This strict structure ensures consistent parsing, visualization, and correlation of spans across all OpenTelemetry tools and systems.

<details>
  <summary>How the OTLP Exporter Maps Internal Python Span → OTEL Schema: [click to expand]</summary>

  <div markdown="1">

  The OpenTelemetry Python SDK’s OTLP exporter performs a strict mapping from the internal `Span` objects to the wire-compatible OTEL schema (`trace.proto`).  
  This conversion happens in:

  - `opentelemetry-sdk/trace/export/__init__.py`
  - Generated Protobuf classes like `trace_pb2.py`

    🔁 Mapping Examples:

    | Python SDK Internal Field     | OTEL Exported Field         |
    |------------------------------|-----------------------------|
    | `span.context.trace_id`      | `"traceId"`                 |
    | `span.context.span_id`       | `"spanId"`                  |
    | `span.parent.span_id`        | `"parentSpanId"`            |
    | `span.name`                  | `"name"`                    |
    | `span.kind`                  | `"kind"`                    |
    | `span.start_time`            | `"startTimeUnixNano"`       |
    | `span.end_time`              | `"endTimeUnixNano"`         |
    | `span.attributes` (dict)     | `attributes[]` (array of `{ "key": ..., "value": ... }`) |
    | `span.status`                | `{ "code": "STATUS_CODE_UNSET" }` |
    | `span.resource`              | lifted to `resourceSpans[].resource` |

  </div>
</details>

>These mappings are **not optional** — they are required for the OTEL schema to be valid and for backend compatibility.
>All OTLP-compliant backends **rely on these mappings** to parse and process telemetry data correctly.
{: .prompt-tip}

### Mental Model of the schema

- **Schema shape (fixed)** → You cannot change the container structure  
- **Values inside (flexible)** → You set fields like `name`, `attributes`, `status`, and sometimes `parentSpanId`  
- **Some fields are auto-filled** → IDs, timestamps

>- The only place for custom app data = attributes[].
>- The values of standard fields (like name, status, etc.) you can set.
>- The rest (IDs, times) = handled automatically by the SDK.
{: .prompt-tip}

### Minimal `python`  code examples for getting the console output {#minimal-python-code-examples-for-getting-the-console-output}

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor, ConsoleSpanExporter

# ConsoleSpanExporter here = Python dict view (not OTLP schema)
provider = TracerProvider()
exporter = ConsoleSpanExporter()
provider.add_span_processor(SimpleSpanProcessor(exporter))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer("example")

with tracer.start_as_current_span("top-level-task") as parent:
    with tracer.start_as_current_span("sub-step-2") as child:
        child.set_attribute("foo", "bar")
        child.set_attribute("answer", 42)
```

### Trace Context Propagation Across Distributed Systems: How It Works 

**Distributed Tracing Across Services**
Imagine a typical request flow in a distributed system:

```text
Client ──> Server A ──> Database 1  
                   └─> Server B ──> Database 2  
Response <────────────

```
* Goal one trace across this entire journey.
* That means the traceId must be the same everywhere.
* Each service adds child spans.

This is easy if it were happening in the same system and could have been achived via nested span but here its a distributed system spread across network

How this happens:
 - 👉 The “secret sauce” is Context Propagation.(HTTP headers injection)
When the client makes a request, OTEL generates:

- `traceId` (shared by all spans in this request)
- `spanId` (unique per span)

The client injects this context into the HTTP headers.

The server extracts it, continues the trace, and adds child spans.and injects it again if it makes other child calls to different other servers (app oe db whatever)

**Standard = W3C Trace Context headers:**

```http
traceparent: 00-<traceId>-<spanId>-01
tracestate: ...
```
* **Example End-to-End in Action**

  + Imagine this flow:
    1. **Client app starts a trace** → `traceId=abc123`.
    2. **Makes HTTP call** → adds header: `traceparent: abc123/111`.
    3. **Server A extracts context** → continues trace with a **child span**.
    4. **Server A queries DB** → creates a **new child span** for the SQL query.
    5. **Server A calls Service B** → propagates `traceId` in headers.
    6. **Service B extracts** → creates its own **child spans**.
    7. **Response bubbles back** to the client.

>👉 **Result in Jaeger**:  
>You see a **waterfall of spans** across  
>**Client → Server A → Service B → DB** — all connected by the same `traceId`.
{: .prompt-info}


### Who Actually Handles Trace Context Propagation?

1. **Raw HTTP server (no OTel instrumentation)**  
A server (Flask without OTel, Node.js http.createServer(), Go net/http) does not know what `traceparent` means.  
It just treats it as a normal HTTP header.  
So:

```diff
- Client starts a trace → sends traceparent.
- Server ignores it → starts a new trace (or no trace at all).
- ❌ The two traces are disconnected.
```

2. **With OpenTelemetry Instrumentation**

OTel instruments your framework/middleware (Flask, Django, Express, Spring, gRPC).

- **On incoming requests:**  
  The instrumentation extracts the `traceparent` (and `tracestate`) header.  
  - If found → continue the trace with the same `traceId`.  
  - If not → create a fresh trace.

- **On outgoing requests:**  
  The instrumentation injects the current trace context into `traceparent` headers.

✅ This is how traces get stitched across services automatically.

3. **Manual Way (if no instrumentation exists)**

If you’re using a custom server or an unsupported protocol, you can handle tracing manually.

- [ ] Two steps:

  - [x] Extract from incoming headers:

      ```python
      from opentelemetry import trace, propagate
      from opentelemetry.trace import TracerProvider
      from opentelemetry.sdk.trace import TracerProvider
      from opentelemetry.sdk.trace.export import SimpleSpanProcessor, ConsoleSpanExporter

      trace.set_tracer_provider(TracerProvider())
      tracer = trace.get_tracer(__name__)

      def handle_request(request):
          # Extract trace context from incoming HTTP headers
          ctx = propagate.extract(request.headers)
          with tracer.start_as_current_span("server_span", context=ctx):
              # your handler code
              return "response"
      ```
  - [x] Inject into outgoing requests:

      ```python
      import requests
      from opentelemetry import propagate

      def call_downstream():
          headers = {}
          propagate.inject(headers)  # adds `traceparent` automatically
          response = requests.get("http://downstream-service", headers=headers)
            def handle_request(request):
                # Extract trace context from incoming HTTP headers
                ctx = propagate.extract(request.headers)
                with tracer.start_as_current_span("server_span", context=ctx):
                    # your handler code
                    return "response"
      ```

[nice read](https://medium.com/@kedarnath93/understanding-opentelemetry-with-demo-example-d7991a4fc237)

