---
layout: post  
title: "Langfuse: Why It Matters and How to Get Started"
date: 2025-08-26
categories: ['Tutorial','Telemetry']
tags: ['langfuse','telemetry',tutorial]
slug: langfuse-why-it-matters-getting-started
image:
  path: assets/images/covers/langfuse.png
  alt: Langfuse
---

<div align="center">

  <a href="{{ site.posts | where: "slug", "openTelemetry-unified-observability-part1" | first.url | relative_url }}" target = "_blank">[OpenTelemetry part 1]</a>

  <a href="{{ site.posts | where: "slug", "openTelemetry-unified-observability-part2" | first.url | relative_url }}" target = "_blank">[OpenTelemetry part 2]</a>

</div>
<div align="center">

  <a href="https://langfuse.com/docs/observability/data-model" target = "_blank">[Observability datamodel]</a>

  <a href="https://langfuse.com/docs" target = "_blank">[offitial doc]</a>

</div>

<details>
  <summary><strong>📑 Table of Contents</strong></summary>

  <div markdown="1">

  - [What is Langfuse?](#what-is-langfuse)
  - [The Idea Behind Langfuse](#so-whats-the-idea-behind-creating-langfuse)
    - [Tracing LLM Applications](#how-do-you-trace-that)
    - [How Langfuse Solves It](#how_langfuse-solves-it)


  - [Inside Langfuse](#inside-langfuse-what-it-tracks-and-how-it-works)
  - [Core Concepts in Langfuse](#core-concepts-in-langfuse-trace-span-generation)
  - [Instrumentation in Langfuse](#instrumentation-in-langfuse)

  - [Scoring, Feedback & Events](#Scoring-events-firstclass)
  - [Reminder: Manual Instrumentation](#reminder-instrumentation-is-manual-by-design)

  - [Practicals and Examples](#practicals-and-examples)
  - [🚫 What You Cannot Do](#what-you-cannot-do)


  </div>
</details>


## What is Langfuse?

Langfuse is an open-source observability platform designed specifically for LLM-based applications.At its core, it is: **A backend + dashboard for LLM observability**.Think of it like Jaeger, Grafana, or DataDog, but tailored for LLMs.
It provides deep tracing and analytics for: **Prompts & responses**,**Nested function/tool calls**,**Latency & token usage**,**API costs**,**Scoring**, **metadata**, and more.So that you can understand, debug, and improve your LLM-powered workflows with full visibility.

>**NOTE:** Langfuse is not limited to instrumenting only LLM flows. It is fundamentally an instrumentation tool. It just happens to be tailored for LLM flows and accommodates its naming and concepts accordingly.
{: .prompt-info}


**Langfuse has two components**  

* 🖥️ **Dashboard (Backend + UI)**

  - Focuses on LLM-specific data: token usage, prompts, responses, retries, tool-calling, costs, etc.
  - Powered by ClickHouse (for fast analytics), Redis, and S3 (for large trace payloads).

* 🧰 **Langfuse SDK**

  - This is what you integrate into your app (available in Python, JS/TS, etc).
  - It wraps the OTel SDK and:
    - Provides simplified classes and APIs to create and track LLM spans (e.g. Trace, Span, Score)
    - Sends this data to the Langfuse backend using standard OTel transport mechanisms

 It’s basically a developer-friendly layer over OpenTelemetry with LLM semantics.

<span style="color: #4A90E2;"><strong>**Langfuse = [Jaeger for LLMs] + [OTel wrapper SDK] + [LLM-specific dashboarding & tooling]**</strong></span>


## So, What’s the idea behind creating Langfuse?

Langfuse is built primarily for telemetry in LLM- and AI-agent-driven applications.But here’s the nuance — while you *can* use it to record any kind of data, the UI and backend are so focused on LLM concepts, it feels like it was made exclusively for AI workflows.

***
Let's start simple you make an LLM call — prompt in, response out. Maybe you log token usage, model, cost. All good.

But then reality kicks in: Outputs vary across calls , One call can trigger others — tools, APIs, DB queries , It’s all part of a bigger flow: a session, task, or conversation

>**Think about it** — An application starts with a **user question**. It calls an **LLM**, maybe queries a **database**, then calls another **LLM** again, possibly invoking a **tool** in between... and so on. Eventually, the whole thing **concludes**.But this entire journey — from that **initial user input** to all the **hops in between** —
>
><kbd>User Question or Prompts</kbd> → <kbd>LLM #1</kbd> → <kbd>DB Query</kbd> → <kbd>LLM #2</kbd> → <kbd>Tool Call</kbd> → <kbd>Final Response</kbd>
> also Same LLm and prompt can yield different responses as well 
{: .prompt-tip}



##### **How do you trace that?**

First Thought: Let’s Build an Instrumentation Layer

You figure: **let’s create a system that lets developers define and track these flows** — like manual logging, but structured and traceable. Every step in the flow is recorded and sent to a dashboard where you can **replay the journey**, **understand the behavior**, and **debug when things go wrong**.

Sounds great, right?

🤔 **But wait a second... isn't there already something that does this? [<kbd>OpenTelemetry (OTEL)</kbd>]({{ site.posts | where: "slug", "openTelemetry-unified-observability-part1" | first.url | relative_url }})?** it’s battle-tested and robust

**Yes OTEL already gives you:**

- ✅ A solid **trace data model**
- ✅ Standardized **spans and context propagation**
- ✅ Multiple **language SDKs**

**why not just stand on OTEL’s shoulders?**

---
Things like: `prompt`, `completion`, `token_usage`, `model`, `latency`, `cost`, `score`, `tool_calls`

**Here’s the Clever Move:**

1. Use OTEL’s trace model as the foundation : *(It’s already great for tracking distributed systems and flow lifecycles.)*

2. Extend it with LLM-specific metadata    
  - Things like: `prompt`, `completion`, `token_usage`, `model`, `latency`, `cost`, `score`, `tool_calls`
  - All of this fits neatly into the **attributes** section of the trace datamodel (a Span) which is used to transfer data  — no need to break the OTEL model.Examples in the below section
    ```json
    "attributes": {
            "langfuse.observation.input": "{\"sql\": \"SELECT * FROM users WHERE active=1\"}",
            "langfuse.observation.output": "{\"rows\": 42}",
            "langfuse.observation.metadata.db": "users",
            "langfuse.observation.type": "span",
            "langfuse.observation.level": "INFO",
            "langfuse.observation.status_message": "Fetched 42 active users",
            "langfuse.observation.metadata.my_new_metric": "Somevalue"
        }
    ```

3. Build a purpose-built dashboard and backend  
- One that doesn’t just show spans and traces like **Jaeger** or **Grafana**, but instead **understands LLM-specific attributes** and **visualizes them meaningfully**.

><p style="text-align: center; font-size: 1.2em; font-weight: bold;">💥 Boom — that’s Langfuse.</p>
>It’s a specialized telemetry platform, built on the solid foundation of OpenTelemetry, but enhanced with a deep understanding of LLM and AI application needs.
{: .prompt-info}

**🤖 why dont we use OTel ,What’s Missing for LLMs/Agents?**

If you just used **OTel raw**, you’d get:

- ✅ A **trace** → good, but it doesn’t know what a **“prompt”** is.
- ✅ A **span** → good, but it doesn’t know how to **display input/output** clearly.
- ✅ A **metric** → good, but you’d have to invent something like **`tokens_used`** as a metric yourself.
- ✅ A **log** → good, but where do you put something like **`model=GPT-4`** neatly?

👉 You **could** still do it, but it would be like **forcing LLMs into a generic observability box**.  
You’d have to:

- 🛠️ Define **custom conventions** the **schemantics** (naming traces, spans, tags)
- 🖥️ Build your **own dashboard** on top of Grafana/Jaeger
- 🔗 Manually **correlate prompts/responses with metrics**

That’s **heavy work**.

<span id="how_langfuse-solves-it"></span>
**How langfuse solves it**

🔁 Reuse OTel’s Primitives

- `Trace` ↔ **Conversation / Agent Run** and `Span` ↔ **Function / Tool / Step**

✅ Specialize for LLMs

  - **Added `generation`** = a span optimized for LLMs  
    → Knows about `input`, `output`, `model`, `usage.tokens`

  - **Added `score`** = a metric designed for evaluation  
    → You don’t have to figure out *"where to put quality/accuracy"*

> 💡 **Note:**  
> Langfuse only uses the <kbd>trace</kbd> schema from **OpenTelemetry (OTel)** — not the full OTel suite (like logs or metrics).  
> 
> Whenever it wants to send data to its backend, it uses the **OTel SDK for traces**, formats the data to the trace schema, and sends it accordingly.
> It **only uses the <kbd>attributes</kbd> field** in the trace schema to transmit data, applying its own semantics.
>
> 📌 Even custom metrics like **tokens**, **scores**, etc., are sent via the **`attributes` field** as metadata/custom values — not as separate OTel metrics.
{: .prompt-info}

**✅ Dashboard Built for AI**

Instead of Jaeger/Grafana, you get a UI where:

- 📄 You can read **prompts/responses** nicely  
- 🔢 **Token counts and costs** are first-class citizens  
- 📈 **Scores** (accuracy, helpfulness) are plotted over traces  
- 🔍 You can **filter/search** traces by use


---

## Inside Langfuse: What It Tracks and How It Works

As we’ve already established, Langfuse uses the [**OTel's** `trace`]({{ site.posts | where: "slug", "openTelemetry-unified-observability-part1" | first.url | relative_url }}#traces-anchor) schema/data model for **structuring and transporting data** to its backend (Langfuse UI).

**❓ But how is it done?**  **How is the data actually sent?**  **How does the backend understand it?**  
 *Let’s uncover this.*

Langfuse leverages the `trace` schema — **`attributes`** field within each span.The OpenTelemetry trace schema allows **arbitrary key-value pairs** to be embedded inside this field.

For example:

```json
{
  "attributes": [
    { "key": "prompt", "value": "Tell me a joke" },
    { "key": "tokens_used", "value": 42 },
    { "key": "model", "value": "gpt-4" },
    { "key": "x", "value": 100 }
  ]
}
```
However, these generic keys like "prompt" or "x" don’t carry any semantic meaning for the Langfuse backend. Instead of **raw, arbitrary keys, Langfuse defines a custom naming convention using structured keys**. Examples

<p style="color: #4A90E2" align=center><strong>"langfuse.observation.input"</strong>, <strong>"langfuse.observation.model.name"</strong>, <strong>"langfuse.observation.metadata"</strong>, and similar keys have special semantic meaning in the Langfuse backend.The data sent under these keys is interpreted specifically
As Langfuse puts it:“LLMs and agents are their own category of systems, so we need dedicated semantics for them.” These conventions and objects are understood uniquely by the backend.</p>




```json
[
  {"key": "langfuse.observation.input","value": "{\"sql\": \"SELECT * FROM users WHERE active=1\"}"},
  {"key": "langfuse.observation.output","value": "{\"rows\": 42}"},
  {"key": "langfuse.observation.model.name","value": "gpt-4"},
  {"key": "langfuse.observation.metadata.custome.my.value","value": 12345},
  {"key": "langfuse.observation.cost_details","value": "{\"input_cost\": 0.00024, \"output_cost\": 0.00056}"}
]
```

> ⚠️ **Note:**  
> The structured `{ key, value }` format shown above is what actually goes **over the wire** in the OTel trace payload.  
> 
> But for **simplicity**, when you **dump the trace data to your console or logs**, the same data is shown in as below. Console Output Format (Flattened Attributes)
>```json
>"attributes": {
>  "langfuse.observation.input": "What is earth?",
>  "langfuse.observation.model.name": "gpt-4",
>  "langfuse.observation.output": "earth is a planet.",  
>  "langfuse.observation.type": "generation",
>}
>```
{: .prompt-tip}

THe langfuse code can be instrumented  means the story can be toled in the below way  


### Core Concepts in Langfuse (trace ,span, generation)

- [x] **Traces (💡 Root span)**
  - Represents a complete session, request, or workflow. It's the top-level context for everything that happens in a user interaction or model execution. **It is actually a span but at the top level**
  - **OTel equivalent:** Same as a root span in OpenTelemetry.

    ```python 
      with langfuse.start_as_current_span(name="process_request", input={"query": "What is AI?"}) as root_span:
            ...
        # or via observe

      @observe()
      def handle_request(user_input: str):
          return f"Processed: {user_input}"
      ```
  - 📌 Every Langfuse instrumentation begins with a Trace.

- [x] **Spans (a span inside root span i.e trace )**
  - Represents a step within a trace — for example, calling a function, querying a DB, retrieving documents, or performing post-processing.
  - **Langfuse-specific features:**
    - You can use `.update_trace()` or `.update()` to log metadata.
    - You can log structured events or scores via `.score()` or `.log_event()`.

        ```python
        with langfuse.start_as_current_span(name="process_request", input={"query": "What is AI?"}) as root_span:
            with lf.start_as_current_span(
                    name="db_query",
                    metadata={"sql": "SELECT * FROM users"}
                ) as span
        ```

>⚠️ If a span is the first thing created, it becomes the root span → trace.
>
>📌 Spans are used for everything that’s not an LLM generation.
{: .prompt-tip}

- [x] **Generations**
  - A specialized span in Langfuse that represents an LLM call.**Langfuse-only concept**.
  - **Captures:**
    - input , output and  model, provider (e.g., OpenAI, Claude) also tokens, latency, cost  

        ```python
        with langfuse.start_as_current_span(name="process_request", input={"query": "What is AI?"}) as root_span:
            with lf.start_as_current_generation(
                  name="llm_answer",
                  model="gpt-4",
                  input="What is earth?",
                  usage_details={"prompt_tokens": 12}
              ) as gen:
        ```

>📌 Can be nested inside a trace or a span. Shown in the Langfuse UI with prompt/response formatting.
>
>📌 Mostly used in place of span where there is a LLm interaction as it contains more parameters that can be used to descrive the LLm interaction unlick of a **span** 
{: .prompt-tip}

---

## Instrumentation in Langfuse

Langfuse provides **3 primary methods** to instrument your code. Each supports trace/span/generation creation, but with different control levels and complexity.

---

#### 1. `@observe` Decorator — Simple Function Tracing

Wraps a function automatically into a trace/span. Ideal for simple workflows.

```python
from langfuse import observe

@observe(
  name="calculate_sum",
  metadata={"langfuse_user_id": "u123", "tags": ["prod"]}
) # Both name and metadata are is optional if name not given it takes the funtion name
def add(a, b):
    return a + b

result = add(2, 3)
```

🔍 **What it does:**

- Automatically creates a trace (if not already active) and Wraps the function call in a span, **Span name → calculate_sum**
- Input = function arguments **Input → {a: 2, b: 3}** , Output = return value **Output → 5** (its automatic)
- **Injects context so nested spans inherit from it**

---

#### 2. Manual Spans & Generations — Full Control

Use when you need fine-grained instrumentation, such as wrapping specific LLM calls or nesting multiple steps.
When you need more flexibility:Choose whether it’s a span or generation ***or*** Explicitly **set input, output, metadata**, etc.

```python
from langfuse import get_client

langfuse = get_client()

# Manually start a span (or trace if root)
with langfuse.start_as_current_span(name="process_request", input={"query": "What is AI?"}) as root_span:
    span.update_trace(user_id="user-abc", session_id="sess-123")

    # another extra span for a api fetch
    with langfuse.start_as_current_span(name="fetch_data") as span:
        span.update(metadata={"source": "API"})
        span.score(name="success", value=True, data_type="BOOLEAN")

    # Track an LLM generation
    with langfuse.start_as_current_generation(
        name="openai_response", model="gpt-4", input="What is AI?"
    ) as gen:
        # Simulate response
        output = "Artificial Intelligence is..."
        gen.update(output=output)

    span.update_trace(output={"response": output})

langfuse.flush()

```

🧠 **Key APIs:**

- `start_as_current_span(...)`
- `start_as_current_generation(...)`
- `.update_trace()`: adds or updates trace-wide data
- `.update(...)`: updates specific span/gen fields
- `.score(...)`: logs a score
- `.log_event(...)`: logs a structured event

---

#### 3. Drop-in Integrations (LLM Providers)

Langfuse can automatically wrap clients like **OpenAI**, **Anthropic**, and others.

✅ **Captures** inputs, outputs, and token usage — **no boilerplate needed**.

**Example: Instrumenting OpenAI**  : Langfuse automatically records: 🧾 **input** (prompt messages), 📤 **output** (model response), 🔢 **usage** (token counts).


```python
from langfuse.openai import openai

response = openai.ChatCompletion.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Summarize Langfuse"}]
)
```

Each trace/span/generation can be instrumented with:

| **Field**    | **How to Set**                                           | **Notes**                            |
|--------------|-----------------------------------------------------------|--------------------------------------|
| `input`      | `input={"x": "y"}` in context manager or auto from decorator | Tracked for each unit                |
| `output`     | `update_trace(output=...)` or returned value from `@observe` | Useful for prompt responses          |
| `user_id`    | `update_trace(user_id=...)`                               | Ties activity to users               |
| `session_id` | `update_trace(session_id=...)`                            | For grouping                         |
| `metadata`   | `update_trace(metadata={...})` or `@observe(metadata={})` | Attach custom structured data        |
| `tags`       | `metadata={"tags": [...]}`                                | Used in UI and filtering             |

---

## Scoring, Feedback & Events and First-Class Atributes in Langfuse. {#Scoring-events-firstclass}

Langfuse v3 gives you a few semantics (special attributes that the SDK + backend + dashboard understand): The SDK automatically process and sent in the `attribute` filed of `trace`

- 🟡 **Score** → Structured evaluation object via `.score()`
- 🔢 **Tokens** → Tracked as `usage_details` inside a **generation** `usage_details={"prompt_tokens": 10, "completion_tokens": 25}`
- 💰 **Cost** → if you provide model, it looks up token pricing; else you can set manually as metadata
- ⏱️ **Latency** → Measured automatically from span/generation start/stop

🟡 **Score a trace/span**

```python
span.score(name="accuracy", value=0.9, comment="Looks good")
```

🟢 **Log an event (for debugging or analytics)**

```python
span.log_event(name="doc-retrieved", level="info", payload={"doc_id": 123})
```

> Note These metrics are sent to the backend via OTel `trace` and via the `attribute` field
{: .prompt-tip}

### What About Your Custom Fields (info metadata)?

If you want to log arbitrary extra info like:

```python
my_custom_thing = "my_value"
custom.my.value = 12354
```

**You can safely store them in:**

- 🗂️ **metadata** → Structured JSON dict (unlimited depth)  
- 🔖 **tags** → Flat list of strings  

✅ These won’t break anything  
✅ They will appear in the **Langfuse UI** under “Metadata” or “Tags”  
❌ But they won’t be plotted automatically like **scores**, **tokens**, or **latency**

Langfuse Dashboard will render them just as Metadata  

---

## Reminder: Instrumentation is Manual by Design

Langfuse does **not** automatically "see" your inputs, outputs, or model calls.  same as OTel
You are responsible for:

- Starting and stopping spans/generations  
- Logging inputs/outputs  
- Logging token usage, cost, latency (optionally)  
- Scoring and tagging  

---

## Practicals and Examples

>Note You need to **.flush()**  as langfuse traces are async and the flush safly sends all the unsend data in the event loop
{: .prompt-tip}

```python
from langfuse import get_client

lf = get_client()

# Start a trace (root)
with lf.start_as_current_trace(
    name="pipeline",
    metadata={"pipeline_id": "123", "experiment": "A1"},
    tags=["v3", "demo"]
) as trace:

    # Generic span
    with lf.start_as_current_span(
        name="db_query",
        metadata={"sql": "SELECT * FROM users"}
    ) as span:
        # You can update metadata later
        span.update(metadata={"rows_returned": 42})
        
        # Add a score to this span
        span.score(
            name="db_latency_ok",
            value=True,
            data_type="BOOLEAN",
            comment="Returned fast"
        )

    # LLM Generation (specialized span)
    with lf.start_as_current_generation(
        name="chat_step",
        model="gpt-4o",
        input="What is Langfuse?",
        usage_details={"prompt_tokens": 15},  # tokens
        metadata={"agent": "faq-bot", "custome.my.value": 12354}  # 👈 custom field
    ) as gen:
        gen.update(
            output="Langfuse is an observability tool for LLMs",
            usage_details={"completion_tokens": 60},  # more tokens
            cost_details={"input": 0.0015, "output": 0.0030}  # manual cost
        )
        
        # Add evaluation score
        gen.score(
            name="helpfulness",
            value=0.8,
            data_type="NUMERIC",
            comment="Good but not perfect"
        )

# Push all data
lf.flush()
```

<details>
  <summary><strong>examples of real data dumps : [CLICK ME]</strong></summary>

  <div markdown="1">

  ```json
  -> breakpoint()
  (Pdb) c
  // This is A normal span=============================================
  {
      "name": "db_query",
      "context": {
          "trace_id": "0xfa5f4e5915575785b27bbb3f4b1e29a8",
          "span_id": "0x146d16d10dc60db3",
          "trace_state": "[]"
      },
      "kind": "SpanKind.INTERNAL",
      "parent_id": "0xd73a74fa5f51c7df",
      "start_time": "2025-08-24T18:26:28.179889Z",
      "end_time": "2025-08-24T18:26:28.180541Z",
      "status": {
          "status_code": "UNSET"
      },
      "attributes": {
          "langfuse.observation.input": "{\"sql\": \"SELECT * FROM users WHERE active=1\"}",
          "langfuse.observation.output": "{\"rows\": 42}",
          "langfuse.observation.metadata.db": "users",
          "langfuse.observation.type": "span",
          "langfuse.observation.level": "INFO",
          "langfuse.observation.status_message": "Fetched 42 active users",
          "langfuse.observation.metadata.my_new_metric": "Somevalue"
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
  > /home/abhishek/workspace/agent_fabric/testing_main.py(50)<module>()
  -> breakpoint()
  (Pdb) c
  This is Generation Example=============================================

  {
      "name": "llm_answer",
      "context": {
          "trace_id": "0xfa5f4e5915575785b27bbb3f4b1e29a8",
          "span_id": "0xa37d33a889de4110",
          "trace_state": "[]"
      },
      "kind": "SpanKind.INTERNAL",
      "parent_id": "0xd73a74fa5f51c7df",
      "start_time": "2025-08-24T18:26:35.394530Z",
      "end_time": "2025-08-24T18:26:35.395176Z",
      "status": {
          "status_code": "UNSET"
      },
      "attributes": {
          "langfuse.observation.input": "What is earth?",
          "langfuse.observation.model.name": "gpt-4",
          "langfuse.observation.output": "earth is a planet.",
          "langfuse.observation.usage_details": "{\"completion_tokens\": 28}",
          "langfuse.observation.metadata.agent": "fake-custome-agent",
          "langfuse.observation.metadata.custome.my.value": 12345,
          "langfuse.observation.type": "generation",
          "langfuse.observation.cost_details": "{\"input_cost\": 0.00024, \"output_cost\": 0.00056}"
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
  This is root-span completed=============================================

  {
      "name": "root_pipeline",
      "context": {
          "trace_id": "0xfa5f4e5915575785b27bbb3f4b1e29a8",
          "span_id": "0xd73a74fa5f51c7df",
          "trace_state": "[]"
      },
      "kind": "SpanKind.INTERNAL",
      "parent_id": null,
      "start_time": "2025-08-24T18:26:28.179384Z",
      "end_time": "2025-08-24T18:26:35.396454Z",
      "status": {
          "status_code": "UNSET"
      },
      "attributes": {
          "langfuse.observation.input": "{\"intent\": \"user_asks_question\"}",
          "user.id": "user_123",
          "session.id": "sess_abc",
          "langfuse.trace.tags": [
              "demo",
              "pipeline",
              "v3"
          ],
          "langfuse.observation.metadata.pipeline_version": "0.1",
          "langfuse.observation.metadata.team": "aget-team",
          "langfuse.observation.type": "span",
          "langfuse.observation.level": "INFO"
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

## 🚫 What You Cannot Do {#what-you-cannot-do}

- ❌ You **cannot invent new object types** beyond `Span`, `Generation`, or `Event`.
- ❌ You **cannot define a new schema** like `my_custom_metric` outside of `.score()`.
- ❌ You **cannot push OTel metrics/logs** — Langfuse is **trace-only**.
- ✔️ Custom values (e.g., `custome.my.value`) **must go in `metadata`**, not as first-class objects. like **score,token,cost ,latency** etc

