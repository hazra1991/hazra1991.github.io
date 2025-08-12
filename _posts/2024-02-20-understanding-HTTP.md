---
layout: post
title: "Understanding HTTP: Requests, Responses"
date: 2024-02-20
desc: "A beginner-friendly guide to understanding the HTTP protocol, covering how requests and responses work in web communication."
tags: [http, networking, web, tutorial, protocol, requests, responses]
---

- **[Http or any protocol is not a socket it works on a socket, enter to know more]({{ site.posts | where: "slug", "sockets-explained-in-python" | first.url | relative_url }})**

- What is HTTP?
- Structure of an HTTP Message
- Common HTTP Verbs (Methods)
- The OPTIONS Method
- HTTP Headers — More Details
- Standardized Headers
- Custom Headers
- Small Flask App Example
- Example Interaction
- Key Takeaways
- Security Considerations


The **HTTP (HyperText Transfer Protocol)** is the foundation of communication on the web. It defines the rules for how data is transferred between a client (like your browser) and a server (like a website).

For decades, **HTTP/1.1** has been the dominant version in use, although **HTTP/2** is now available and gaining adoption.

---

## What is HTTP?

Think of HTTP as a **language** both browsers and servers speak — a set of *structured rules* that defines how data is sent and received over the internet.

- **Default Port:** HTTP commonly uses **port 80** on the server.
- **Plain Text:** HTTP messages are **plain text** (human-readable), though they can carry binary data in the body.

HTTP works through two main types of messages:

1. **HTTP Request** → Sent by a client to the server.
2. **HTTP Response** → Sent by the server back to the client.

---

## Structure of an HTTP Message

Both **requests** and **responses** share a similar structure:

```
 _____________________
|  Request/Response    |
|----------------------|
|  Start Line          |
|----------------------|
|  Headers             |
|  (key:value pairs)   |
|----------------------|
|  Blank Line          |
|----------------------|
|  Body (optional)     |
|______________________|
```

### 1. Start Line
- **Requests:** Contain the HTTP **verb**, the path, and the version.  
  Example:  
  ```
  GET / HTTP/1.1
  ```
- If there are query parameters:  
  ```
  GET /?value=12 HTTP/1.1
  ```
- **Responses:** Contain the HTTP version, status code, and reason phrase.  
  Example:  
  ```
  HTTP/1.0 200 OK
  ```

---

### 2. Headers
Headers are **key-value pairs** that give extra information about the request or response.

Example:
```
Content-Type: text/plain
Cache-Control: no-cache
User-Agent: PostmanRuntime/7.25.0
```

Headers can:
- Control caching (`Cache-Control`)
- Indicate the content type (`Content-Type`)
- Carry cookies (`Cookie`)
- Provide authentication (`Authorization`)
- Pass **custom** information

**Custom headers** are allowed. For example:
```
name: Joy
jwt: <jwt-token-string>
```

---

### 3. Blank Line
A single **blank line** separates headers from the body.

---

### 4. Body (Payload)
- **Optional** — not all HTTP messages have a body.
- Usually present in methods like `POST` or `PUT`.
- Can contain JSON, HTML, XML, binary files, etc.

Example:
```json
{
  "name": "joy",
  "occupation": "dontknow"
}
```

---

## Common HTTP Verbs (Methods)

| Verb     | Action                  |
|----------|------------------------|
| GET      | Read from server       |
| POST     | Create in server       |
| PUT      | Update or create       |
| DELETE   | Remove from server     |
| OPTIONS  | Describe communication options for the target resource (see below) |

---

## The OPTIONS Method

The **OPTIONS** method asks the server which HTTP methods and other options are supported for a target resource. It is commonly used in two ways:

- **Discovery:** Clients can discover which methods (GET, POST, PUT, DELETE, etc.) are allowed on a resource.
- **CORS Preflight:** Browsers send an OPTIONS request (a "preflight") before certain cross-origin requests to check permissions. The server responds with headers that indicate what is allowed (e.g., `Access-Control-Allow-Methods`, `Access-Control-Allow-Origin`).

**Typical behavior:**
- Respond with an `Allow` header that lists allowed methods, e.g. `Allow: GET, POST, OPTIONS`.
- May include CORS headers like `Access-Control-Allow-Origin`, `Access-Control-Allow-Methods`, and `Access-Control-Allow-Headers`.
- Often returns an empty body.

**Example OPTIONS request:**
```
OPTIONS /api/items HTTP/1.1
Host: example.com
Origin: https://myapp.example
Access-Control-Request-Method: POST
Access-Control-Request-Headers: Content-Type, Authorization

```

**Example OPTIONS response (CORS preflight):**
```
HTTP/1.1 204 No Content
Allow: GET, POST, OPTIONS
Access-Control-Allow-Origin: https://myapp.example
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Max-Age: 86400

```

Note: `204 No Content` is often used to indicate the server successfully processed the request but there is no response body.

---

## Example HTTP Request

```
GET / HTTP/1.1
name: joy
age: 23
Content-Type: text/plain
User-Agent: PostmanRuntime/7.25.0
Accept: */*
Cache-Control: no-cache
Postman-Token: 9e29fdf0-9d47-4e5f-8772-0ac958d56d93
Host: 127.0.0.1:5000
Accept-Encoding: gzip, deflate, br
Connection: keep-alive
Content-Length: 43

{
    "name": "joy",
    "occupation": "dontknow"
}
```

---

## Example HTTP Response

```
HTTP/1.0 200 OK
Content-Type: text/html; charset=utf-8
Content-Length: 20
Server: Werkzeug/0.16.0 Python/3.7.4
Date: Mon, 01 Jun 2020 17:35:37 GMT

body of the response
```

---

## HTTP Headers — More Details

HTTP headers are **overhead metadata**. They **notify** the other side about important information.

**Classifications of Headers:**
- **General fields** — Apply to both requests and responses.
- **Server fields** — Provide info from server to client.
- **Client fields** — Provide info from client to server.

Servers and clients can choose to **read or ignore** headers.

---

### Standardized Headers
Some headers have **standard meanings**, e.g.:

```
Authorization: Basic ZGFkOmRhcw==    # Base64 encoded "dad:das"
```

- `Authorization` header supports:
  - Basic authentication
  - Bearer tokens
  - Other schemes

But you can still:
- Put JWT token in `Authorization: Bearer <token>`
- OR define your own header:
```
jwt: <jwt-token-string>
```

---

### Custom Headers
You can add any **custom** header:
```
mykey: hgfghfh
```
These can be used for:
- Passing internal data between services
- Debugging or tracking
- Feature flags

---

## Small Flask App Example

Here’s a minimal Flask app that captures different parts of an HTTP request:

```python
from flask import Flask, request

app = Flask(__name__)

@app.route("/")
def func():
    data = request.data                 # Request body data
    headers = request.headers           # Headers data
    arguments = request.args            # URL query parameters (as dict)
    return arguments

if __name__ == "__main__":
    app.run(debug=True)
```

---

### Example Interaction

**Request:**
```
GET /?value=12 HTTP/1.1
name: joy
age: 23
Content-Type: text/plain
User-Agent: PostmanRuntime/7.25.0
Accept: */*
Cache-Control: no-cache
Postman-Token: 739b0305-817a-4735-a646-50ef4c406f78
Host: 127.0.0.1:5000
Accept-Encoding: gzip, deflate, br
Connection: keep-alive
Content-Length: 43

{
    "name": "joy",
    "occupation": "dontknow"
}
```

**Response:**
```json
{
  "value": "12"
}
```

---

## Key Takeaways
- HTTP is a **request-response** protocol, primarily over port 80.
- Messages have **start line**, **headers**, an optional **body**.
- Headers can be **standardized** or **custom**.
- HTTP methods define **what action** the request wants the server to perform.
- `OPTIONS` is useful for discovery and CORS preflight checks.
- Flask makes it easy to capture request body, headers, and query parameters.

---

Pro Tip: Always be mindful of **security** when handling HTTP requests:
- Sanitize inputs
- Use HTTPS instead of HTTP
- Validate authentication tokens
- Avoid exposing sensitive headers

---

Note: Once you understand the anatomy of HTTP, you can debug API calls, design better web services, and even create custom protocols on top of it.
