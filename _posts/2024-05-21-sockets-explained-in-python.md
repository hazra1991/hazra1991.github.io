---
layout: post
title: "Sockets: The Building Blocks of Network Communication "
date: 2024-05-21
desc: "Explore the fundamentals of sockets in network programming. Learn how sockets act as communication endpoints, understand TCP/IP and Unix domain sockets, and see how client-server communication is established and managed in Python."
tags: [networking, sockets, python, tcp/ip, communication, tutorial]
---

- [What Are Sockets?](#what-are-sockets)
- [Technically, What Is a Socket?](#technically-what-is-a-socket)
- [What Does a Socket Use?](#what-does-a-socket-use)
- [Server and Client — Not Built-In, Just Roles](#server-and-client--not-built-in-just-roles)
- [How It All Connects (Visual)](#how-it-all-connects-visual)
- [Understanding Sockets Through a Simple Analogy](#understanding-sockets-through-a-simple-analogy)
- [Building Protocols (HTTP, SSH, etc.)](#building-protocols-http-ssh-etc)
- [Now Let’s See Step-by-Step: What Happens When a Server Creates a TCP Socket and What FD Are Created and How](#now-lets-see-step-by-step-what-happens-when-a-server-creates-a-tcp-socket-and-what-fd-are-created-and-how)
- [What About Selectors / Epoll?](#what-about-selectors--epoll)
- [What's a File Descriptor (FD)?](#whats-a-file-descriptor-fd)
- [Basic Socket Utility Functions](#basic-socket-utility-functions)
  - `fileno()` — Access the File Descriptor (FD)
  - `makefile()` — Turn a Socket into a File-like Object
  - `detach()` — Detach the FD from the Socket Object
- [TCP CLOSE_WAIT — The Deadly Zombie Socket](#tcp-close_wait--the-deadly-zombie-socket)


## What Are Sockets?

A **socket** is a two-way communication channel between two programs running over a network.

Think of it as a *virtual wire* between two devices — they could be on the same computer or on opposite ends of the internet.

#### Technically, What Is a Socket?

A **socket** is essentially a **file descriptor (FD)** — yes, just like a file — that the operating system uses to send or receive data over the network.

When you create a socket in code (e.g., using Python), you're telling the OS:

> "Hey, I want a communication pipe. Here's the protocol and address format."

The OS gives you back an **FD**, which you can read from or write to — just like a file, but over a network.

Just like how files work in Linux: You can **read from it** or **write to it** — but instead of the disk, it communicates over the **network**.

- Using sockets, we can create either a **server endpoint** (like an HTTP, FTP, or SSH server) or a **client endpoint** (like a web browser or SSH client).

- There is no inherent “server” or “client” in a socket itself; these roles are defined by how the socket is programmed and used.

- Sockets allow two network endpoints to establish a connection and communicate by sending and receiving data, behaving according to their programming as either client or server.

In short, a socket is the interface that enables network communication between two endpoints/programs/devices one the same machine or over a wire.

**Proof that sockets are file desriptor objetes**
They have file number can be found by below
```python
import socket
s = socket.socket()
print(s.fileno())   # → e.g., 3
```
>❗Every socket is backed by a file descriptor, which is like a handle to a communication pipe — similar to how open("file.txt") gives you an FD to a file.

#### What Does a Socket Use?
- **IP Address** → to know *where* to connect  
- **Port Number** → to know *what service* to connect to (e.g., HTTP: `80`, SSH: `22`, etc.)  
- **Protocol** → usually **TCP** or **UDP** or **Unix Sockets**
  - **TCP**: reliable, connection-based  
  - **UDP**: faster, connectionless

⚠️ **Sockets don’t always use IP addresses and ports.**

Unix domain sockets, on the other hand, use file system paths instead of IP and ports, and they work only locally on the same machine.
-**Unix Sockets (Unix Domain Sockets)**
  - Unix sockets provide communication between processes on the **same machine**.
  - Unlike TCP/UDP sockets, Unix sockets **don’t use the network stack** — instead, they use the **local file system** as their address namespace (represented as a file).
  - They offer **fast, reliable, and efficient inter-process communication (IPC)** without the overhead of network protocols.

Examples of Sockets
- **TCP socket:** `10.1.1.1:80` — a network socket using TCP (e.g., HTTP server)  
- **UDP socket:** `8.8.8.8:53` — a network socket using UDP (e.g., DNS query)  
- **Unix domain socket:** `/tmp/mysql.sock` — a local socket file used for IPC between processes on the same machine (e.g., MySQL server)

***Basic Code Example***

```python
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
```
- AF_INET: IPv4 addressing
- SOCK_STREAM: TCP (stream-based)

This line tells the OS:

- "Give me a TCP socket using IPv4."

The OS sets up the socket, and you get a reference to it in the variables.


> **Note:**  
> Server and client applications are **application-layer programs** that understand specific protocols, such as HTTP servers, FTP servers, and their corresponding clients.  
>
> Application protocols like **Telnet**, **HTTPS**, **HTTP**, **FTP**, and **SSH** all operate on top of **sockets** — whether TCP, UDP, Unix domain sockets, or others — to manage their communication efficiently and reliably.

## Server and Client — Not Built-In, Just Roles

There’s no such thing as a "server" or "client" type of socket.These are simply **roles** defined in your code using logic like:

- `.bind()` – binds the socket to an address and port  
- `.listen()` – makes the socket wait for incoming connections  
- `.connect()` – used by the client to initiate a connection

#### How It All Connects (Visual)

```md
+-----------+        TCP Socket         +-----------+
|  Client   |  <--------------------->  |  Server   |
|  10.0.0.1 |            or             |  10.0.0.2 |
|  :55001   |       udp socket          |   :80     |
|           |  <--------------------->  |           |
+-----------+                           +-----------+
```
- The **client** opens a socket and connects to the **server's IP and port**.  
- The **server** is listening on port `80` using `.bind()` and `.listen()`.  
- Once connected, **both sides** can use `.send()` and `.recv()` to exchange data.

### Understanding Sockets Through a Simple Analogy

Imagine two programs — **App1** and **App2** — each running their own software. Now, suppose **App1 wants to talk to App2**. This communication could happen: Over a **network** (e.g., internet or LAN), On the **same machine** using `localhost`, or Via a **Unix domain socket** (local file-based communication).

#### 🗣️ How the Conversation is Set Up

1. **App1** defines the rules of communication  
- **App1** says: *"If you want to talk to me, you must speak English."*  
(This represents the use of a **protocol**, like **HTTP** — an application-layer protocol.)

2. **App1** sets up a telephone line  
- **App1** says: *"I have a phone line installed (a TCP socket), so to talk to me, you must also use one."*  
(This is the **socket**, the underlying communication channel.)

3. **App1** waits for calls — doesn't dial  
- **App1** says: *"I won’t call you; I’ll wait for you to call me."*  
(**App1** is acting as a **server**, listening for incoming connections.)


Now, **App2** must agree to this setup:

-  Understand English (i.e., the **same protocol**),
-  Use a phone (i.e., set up a **matching socket**),
-  Initiate the call (i.e., act as a **client**).

 **Key Takeaways**
- A **socket** is just a communication channel — it doesn't care what data is sent.
  - It could be structured data following a protocol (like **HTTP**),
  - Or raw, meaningless bytes.
- The **protocol** defines the **structure and meaning** of the data exchanged (e.g., **HTTP**, **FTP**, **SSH**).
- **TCP**, **UDP**, and **Unix domain sockets** are transport mechanisms used to create this communication channel.
- It’s up to the **applications** to decide ,What data to send and How to interpret it.

##### **Building Protocols (HTTP, SSH, etc.)**
Now that we know we can have **raw send/recv over sockets**, we build protocols on top of this. A protocol is just:

**“What do we send and in what format?”**

Example: HTTP 
```http
GET / HTTP/1.1\r\n
Host: example.com\r\n
\r\n
```
Server response:
```http
HTTP/1.1 200 OK\r\n
Content-Type: text/html\r\n
\r\n
<html>Hello</html>
```
Python Code (Client)
```python
c.send(b"GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
data = c.recv(4096)
print(data.decode())
```
-🔹 HTTP just sends a bunch of formatted strings over TCP sockets.

So based on this we an now say **application Protocols Are Built on Sockets**
- Raw sockets only send and receive bytes.  
- The meaning of the bytes is defined by application protocols like HTTP, SSH, etc.

---

#### **Now Let see Step-by-Step: What Happens When a Server Creates a TCP Socket and what FD are created and how**
**1. Server creates a TCP socket:**
```python
server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
```
- This creates a file descriptor (FD) — a kernel-level object that represents an endpoint for communication.
- It is NOT yet listening or connected. It’s just a raw socket FD (say, FD = 3).

**2. Server binds to IP + port:**
```python
server_socket.bind(("127.0.0.1", 8080))
```
This tells the OS:

- “Hey! I want this socket FD to listen for incoming connections on IP `127.0.0.1`, port `8080`.”

Still, no connections yet.

**3. Server calls .listen():**
```python
server_socket.listen()
```
Now the OS marks the FD as a listening socket.
Internally, this FD is registered with the TCP stack and is ready to handle new TCP connection requests.

- 💡 At this point, 1 FD is open on the server — it is a listening socket FD.


**4. Client starts the TCP 3-way handshake:**
```python

client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
client_socket.connect(("127.0.0.1", 8080))
```
This initiates a TCP 3-way handshake with the OS's TCP stack:

```txt
Client --> Server : SYN
Server --> Client : SYN-ACK
Client --> Server : ACK
```
The OS does the handshake itself — your Python code waits for it to complete.

- **Important:** Until the handshake completes, no new socket is created on the server side — the listening FD is watching for handshakes using epoll/select/kqueue.

**5. Server calls .accept()**
```python
conn, addr = server_socket.accept()
```

Now the Magic Happens:

- Once a client's handshake is complete,  
- The OS spawns a new socket FD just for this client (say FD = 4).  
- The original listening FD (FD = 3) stays open to accept other connections.

This new socket FD is what the server uses to **`.recv()`** and **`.send()`** data to this client only.

**Final Picture:**
```md

[Server]
+---------------------+
| FD 3 (Listening)    | ← Stays open forever to accept more connections
+---------------------+
| FD 4 (Client A)     | ← Specific to client A after accept()
| FD 5 (Client B)     | ← Specific to client B after accept()
+---------------------+

[Client A]
FD 3 ← Opened after .connect()
```

### What About Selectors / Epoll?

Good question. Let's clarify.

A **selector**, **epoll**, or **kqueue** is an efficient mechanism the OS uses to monitor many file descriptors and see who's ready to read/write/accept without blocking.

When your server calls `.listen()` and then enters a loop like:

```python
import select

readable, _, _ = select.select([server_socket], [], [])

It’s saying:

- “Let me know when this listening socket has a client trying to connect.”

And later:
```python
conn, addr = server_socket.accept()
```
The accept() call does not block forever because select() told us the FD is ready.

---

#### What's a File Descriptor (FD)?

In Unix, **everything is a file** — including:

- Open files  
- Network sockets  
- Pipes  
- Serial ports, etc.

Example: FD Table

     FD = 0 → stdin
     FD = 1 → stdout
     FD = 2 → stderr
     FD = 3 → socket to 127.0.0.1:8080

## Basic Socket Utility Functions

**-> `fileno()`** — Access the File Descriptor (FD)

```python
fd = s.fileno()
print("Underlying FD is", fd)
```
Useful for:
- Passing the FD to select(), poll(), or epoll()
- Low-level socket manipulation and Debugging

**-> `makefile()`** — Turn a Socket into a File-like Object
```python
f = s.makefile('rwb')
```
`makefile()` — Wrap Socket as File-like Object

This wraps the socket to behave like a file (supports `.read()`, `.write()`, `.flush()`).

📦 Often used in protocols like **HTTP**, where file-like streaming is more convenient.

##### **Behind the Scenes:**

- Still uses the **same file descriptor (FD)**
- You don’t get a new socket — it’s just a **wrapper**


**-> `detach()`** — Detach the FD from the Socket Object
```python
fd = s.detach()
```
Advanced Usage Only: `detach()`
The `detach()` method removes the socket object's control over the file descriptor (FD) and gives you **raw access** to it.
Why use `detach()`?

- To hand over control of the socket to another part of the code or a **subprocess**
- For **zero-copy techniques** or sharing sockets across **process boundaries**

**After `detach()`**, the original socket object becomes **unusable** — no more `.send()` or `.recv()`.


### TCP CLOSE_WAIT — The Deadly Zombie Socket

**What is CLOSE_WAIT?**

It’s a TCP connection state that happens when:

- Peer (client) has closed its socket (**FIN** sent).
- Server hasn't called `.close()` yet.

```
Client          |         Server
----------------+-------------------------
FIN ------------> Server enters CLOSE_WAIT
                 (waiting for app to close)
```

---

**Problem: Not closing socket → CLOSE_WAIT hangs forever**

If your app keeps the connection open (e.g., in a `while True: recv()` loop) and never closes,  
that FD remains open, and the OS sees it as still alive.

Eventually, you’ll exhaust file descriptors:

```bash
OSError: [Errno 24] Too many open files
```

---

**Correct Flow: Always `.close()` after done**

```python
data = conn.recv(1024)
if not data:
    conn.close()
```

If `.recv()` returns empty bytes (`b''`), it means the client closed the connection —  
time to `.close()` on the server.
