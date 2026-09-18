---
layout: post
title: "What Is an API? RPC, REST and SOAP, Untangled"
date: 2026-09-18
description: "An API is just an agreement between two programs. From there: RPC (endpoints are functions), REST (endpoints are resources you can navigate), why SOAP is a protocol while REST is only a style, and where GraphQL fits."
categories: [Backend, APIs]
tags: [api, rest, rpc, soap]
---

The word API gets thrown at everything. Your game "uses the DirectX API". Your weather app "calls a REST API". Payment companies "sell APIs". One word, three very different-sounding worlds — and then someone asks you in an interview how REST differs from RPC, and it all turns to fog.

Let's untangle it. The trick is that there are really only **two questions** hiding under all the names.

> **What we'll cover**
> 1. [An API is an agreement](#api) — graphics cards first, web later
> 2. [RPC: calling someone else's function](#rpc)
> 3. [REST: navigating someone else's data](#rest)
> 4. [SOAP: when the agreement is a protocol](#soap) — and why REST isn't one
> 5. [GraphQL in one breath](#graphql)
> 6. [The whole picture](#recap)
{: .prompt-info}

---

## **An API is an agreement** {#api}

Forget the web for a second.

A game studio cannot write its game separately for every graphics card model ever made. So the card drivers and the game agree to speak one shared language — DirectX, or OpenGL. The game says "draw this triangle" in that language; whatever card is installed understands it. That language is an API, and no network is involved anywhere.

```
game  ───────────────────────►  graphics card
          DirectX / OpenGL
          (the agreement)
```

A web API is the same thing with a wire in the middle:

```
client  ───────────────────────►  server
         "what can I ask for,
          how do I ask,                ──►  answer (JSON, XML, ...)
          what comes back?"
```

That's all an API is: **an agreement on how two pieces of software talk**. For web APIs the conversation is data — plain text, serialized as JSON or XML.

Now, every web API has to settle two things, and keeping them separate untangles every name below:

1. **Shape of the API** — what do the endpoints stand for? *(this is where RPC and REST differ)*
2. **Strictness of the messages** — is the format enforced by a specification, or just mutually understood? *(this is where SOAP stands apart)*

---

## **RPC: calling someone else's function** {#rpc}

RPC means **Remote Procedure Call**, and the name is honest: each endpoint is bound directly to a function on the server. Hitting the URL *is* calling the function.

```python
@app.route("/api/v1/get_person_name")
def get_person_name():
    return {"name": "Ravi"}

@app.route("/api/v1/get_person_age")
def get_person_age():
    return {"age": 30}
```

The URLs are **verbs**: `get_person_name`, `get_person_age`. You're not looking at data, you're invoking procedures from a distance.

It works, and it's light — no extra payload describing anything, easy on bandwidth, quick to write. For a handful of small internal operations it's honestly fine.

The trouble shows up as the API grows. Ask yourself: standing at `/api/v1/`, how does a client find out that these two functions exist? **It can't.** Nothing at `/api/v1/` answers; every endpoint name must come from the documentation and be hardcoded into the client. A hundred endpoints later, every rename on the server quietly breaks somebody, and every new client starts its life buried in your docs.

---

## **REST: navigating someone else's data** {#rest}

REST (**Representational State Transfer**) flips the design. Endpoints stop being functions and become **resources** — nouns. The verbs come from HTTP itself:

```
GET    /api/v1/person/42      read it
POST   /api/v1/person         create one
PUT    /api/v1/person/42      update it
DELETE /api/v1/person/42      delete it
```

One noun, four operations, no `get_`/`delete_` prefixes multiplying in your URLs.

And there's a second idea, the one that made it click for me: **a good REST API can be explored like a website.** You land on a page; links take you everywhere; you never open a manual. Ask the collection, and the response itself tells you where to go next:

```json
GET /api/v1/person

{
  "person": [
    { "href": "https://api.example.com/api/v1/person/42/name",
      "describes": "the name of this person" },
    { "href": "https://api.example.com/api/v1/person/42/age",
      "describes": "the age of this person" }
  ]
}
```

Those `href` links are the API describing itself (the fancy name is *hypermedia*; response formats like ION and HAL exist just for this). Contrast it with RPC, where the same request would meet a 404 and a shrug.

Two more REST principles worth keeping:

- **Statelessness** — every request carries everything the server needs; the server remembers nothing between calls.
- **REST is an idea, not a technology.** In theory it doesn't even require HTTP — it's an architectural style that could ride on any transport. In practice it rides on HTTP and borrows its verbs, status codes and headers.

Here's the part that surprises people: **programmatically, RPC and REST are the same thing.** Same framework, same route decorators, same JSON out. The difference is purely how you *design* the endpoints — functions you call, or resources you navigate.

---

## **SOAP: when the agreement is a protocol** {#soap}

SOAP is a different beast, and the difference is exactly question 2 from the start: **strictness**.

A SOAP message is an XML **Envelope** — an optional Header, a mandatory Body carrying the operation and data. The envelope travels *inside* the HTTP body (it can even travel over email). So the HTTP body and the SOAP body are different things: HTTP is just the vehicle, and the envelope's internal structure is defined by the SOAP specification, not by you.

Before anyone talks, client and server share a **WSDL** file — a signed contract declaring what operations exist, the exact XML shape of each request and response, and the types of every field. Send a request that doesn't comply, and it fails with a structured fault. Every time. By spec.

That contrast is the sentence worth memorising:

> **SOAP is a protocol** because its rules live in a specification. The envelope structure, the WSDL contract, the validation — all defined, agreed, non-negotiable. Break the structure and the request *fails by rule*.
{: .prompt-tip}

> **REST is not a protocol** — it's an architectural style. It gives you principles (statelessness, resources, uniform verbs) but **no enforced message format**. Your JSON's structure is whatever the developer decided. If the server can't make sense of a request, you get some 4xx error — thrown by code a human wrote, not by any specification.
{: .prompt-warning}

*"But REST APIs have Swagger!"* — yes, and that's the tell. Swagger/OpenAPI pages are **documentation**: they help a client learn what the server expects and how to read what comes back. Nothing validates your traffic against them at runtime. A WSDL is a contract; a Swagger page is an understanding between developers.

The deeper dive — full envelope example, WSDL details — is in [REST vs SOAP: A Brief Comparison]({{ site.posts | where: "slug", "rest-vs-soap" | first.url | relative_url }}).

---

## **GraphQL in one breath** {#graphql}

The newest of the bunch: **one single endpoint**, and the client sends the *shape* of the data it wants — "give me this person's name and age, nothing else" — and receives exactly that shape back. No over-fetching whole resources, no under-fetching and calling three endpoints. Still not a protocol; one more architectural style, with a schema that sits somewhere between REST's freedom and SOAP's contract.

---

## **The whole picture** {#recap}

| Style | An endpoint is... | The rules live in... |
|---|---|---|
| **RPC** | a function you call | the docs (client hardcodes everything) |
| **REST** | a resource you navigate | principles + mutual understanding |
| **SOAP** | an operation in an envelope | a specification + WSDL contract (enforced) |
| **GraphQL** | one door, you describe the shape | a schema |

- An **API is an agreement** between two programs — DirectX between a game and a card, JSON over HTTP between a client and a server.
- **RPC** and **REST** are written with the same code; the difference is design. Functions vs resources, docs vs discoverability.
- **SOAP is a protocol** (spec-enforced envelope + WSDL), **REST is a style** (principles, developer-decided formats, 4xx instead of faults).
- If a talk is more your thing, the one that shaped this post is Nate Barbettini's *"API Throwdown: RPC vs REST vs GraphQL"* — worth the hour.
