---
layout: post
title: "Redis — Practical Understanding Notes"
date: 2026-01-12
desc: "Practical notes to understand Redis concepts, usage patterns, and real-world applications."
tags: [redis, database, caching, backend]
---

<details>
<summary><strong>📑 Table of Contents</strong></summary>
<div markdown="1">
1. [What Redis Actually Is](#what-redis-actually-is)  
2. [Why Not Just Use a Python Dictionary?](#why-not-just-use-a-python-dictionary)  
3. [Redis Data Structures](#redis-data-structures)  
   - [Important clarification](#important-clarification)  
4. [Redis “databases” (the /0, /1, etc.)](#Redisdatabase)
   - [Connecting using redis-cli](#rediscli)
5. [Installing and Using Redis](#installing-and-using-redis)  
   - [Installing Redis](#installing-redis)  
   - [Redis Get Data Cheatsheet](#resdis-getdata)
   - [Do you need to start it every time?](#do-you-need-to-start-it-every-time)  
   - [Where Redis config is stored](#where-redis-config-is-stored)  
   - [Important beginner mistake](#important-beginner-mistake)  
   - [Does Redis have users/passwords?](#does-redis-have-userspasswords)  
   - [Modern Redis user system (ACL)](#modern-redis-user-system-acl)   
6. [Network Cost vs Database Cost](#network-cost-vs-database-cost-does-calling-redis-adds-nw-overhead)  
7. [Redis as a Shared Cache](#redis-as-a-shared-cache)  
</div>
</details>


## What Redis Actually Is

Redis is an in-memory Key-value data store primarily used for:

- Caching
- Shared state across servers
- Session storage
- Rate limiting
- Queues
- Real-time analytics

It behaves like a very fast key-value database stored in memory.

**Example:**

```text
SET user:42 "John"
GET user:42
```

Internally it is similar to a dictionary / hashmap, but it runs as a separate server process that multiple applications can access.

## Why Not Just Use a Python Dictionary?

A Python dictionary only exists inside one process.

**Example:**

```python
cache = {}

def get_user(user_id):
    if user_id in cache:
        return cache[user_id]

    user = db.get_user(user_id)
    cache[user_id] = user
    return user
```

This works only if:

- There is one server
- The process never restarts
- Memory is sufficient

But real systems look like this:

```
        Load Balancer
        /    |    \
    App1   App2   App3
```

Each server would have its own dictionary cache.

**Example problem:**

```
Request 1 → App1 caches user
Request 2 → App2 doesn't know about App1's cache
```

Result:

- Duplicate caches
- Inconsistent data
- More database queries

## Redis Data Structures (how data is strored) {#redis-data-structures}

Redis is often described as a key–value store, but the value is not limited to a string.  
It can store richer data structures like lists, sets, hashes, and streams, making it useful for many use cases beyond simple caching.

| Type        | Example Use       |
|------------|-----------------|
| String     | Cache objects    |
| Hash       | Store objects    |
| List       | Queues           |
| Set        | Unique items     |
| Sorted Set | Leaderboards     |
| Stream     | Event processing |

#### Important clarification

Technically:

- Keys are always strings
- Values are stored using specific Redis data types

For example:

- **List** → ordered sequence of strings (good for queues)  
- **Set** → unordered collection of unique values  
- **Hash** → field–value pairs (similar to dictionaries)  
- **Sorted Set** → unique values ordered by score  
- **Stream** → append-only log for events

#### Redis: Get Data Cheatsheet {#resdis-getdata}

Check key type first with **`TYPE key`**
> note the key is always a string and the values van be dirrect . string, list . objects/hashes.streams etc.

```
# Strings
GET key

# Hashes
HGET key field
HGETALL key

# Lists
LRANGE key 0 -1
LINDEX key index

# Sets
SMEMBERS key
SISMEMBER key value

# Sorted Sets
ZRANGE key 0 -1
ZREVRANGE key 0 -1 WITHSCORES

# Streams
XRANGE key - +

# Key utilities
KEYS *
EXISTS key
TTL key
```

### Quick rule

| Type | Read Command |
|-----|-------------|
| String | GET |
| Hash | HGET / HGETALL |
| List | LRANGE |
| Set | SMEMBERS |
| Sorted Set | ZRANGE |
| Stream | XRANGE |


---

### Redis “databases” (the /0, /1, etc.) {#Redisdatabase}

Redis is not like PostgreSQL/MySQL with real isolated databases.
Instead, it has logical partitions inside one instance.

>Default: `Redis has 16 databases: 0, 1, 2, ..., 15`
> When you see:
>   * redis://localhost:6379/0 👉 /0 = database index 0
>   * redis://localhost:6379/1 👉 /1 = database index 1
>
>here **Keys are separated (separate namespace)** , **Same Redis server**, **Same memory**, **Same performance**
>**Note::--  this is a redis url standard format  : redis://[:password]@host:port/db_number**
{: .prompt-info}

```markdown
Example:
DB 0:
SET user:1 "Alice"

DB 1:
GET user:1 → (nil)
```

#### Connecting using redis-cli {#rediscli}
🔹 Redis CLI Connections

| Type            | Command                                                      |
|-----------------|--------------------------------------------------------------|
| Basic           | redis-cli                                                    |
| DB 1            | redis-cli -n 1                                               |
| URL (DB 2)      | redis-cli -u redis://localhost:6379/2                        |
| Password        | redis-cli -a mypassword                                      |
| URL + Password  | redis-cli -u redis://:mypassword@localhost:6379/0            |
| Remote Server   | redis-cli -h 192.168.1.10 -p 6379                            |

---

## Installing and using Redis
```bash
sudo apt update
sudo apt install redis-server
sudo systemctl start redis
sudo systemctl enable redis
```

#### Installing Redis

When you run:

```bash
sudo apt update
sudo apt install redis-server

```
This installs Redis and also installs a systemd service file.  
The service is usually called:  **`redis-server.service`**

**`sudo systemctl start redis`**
This means:
➡ Start Redis right now  
It runs Redis immediately in the background.  
You can check:

```bash
systemctl status redis
```

**`sudo systemctl enable redis`**

This means:
➡ Start Redis automatically when the system boots  
It creates a symbolic link in systemd so that every reboot will run Redis automatically.

**Example behavior:**

| Command                | What it does        |
|------------------------|------------------|
| systemctl start redis  | start now         |
| systemctl stop redis   | stop now          |
| systemctl restart redis| restart           |
| systemctl enable redis | start on boot     |
| systemctl disable redis| don't start on boot|

#### Do you need to start it every time?

If you ran:

```bash
sudo systemctl enable redis
```

Then:

✔ Redis starts automatically after reboot  

You don't need to start it manually again.  

But if you never enabled it, then after reboot it will be stopped and you must run: `systemctl start redis`

#### Where Redis config is stored

- Ubuntu path: `/etc/redis/redis.conf`  
- Data directory: `/var/lib/redis`  
- Logs: `/var/log/redis/redis-server.log`  

>Once installed it can be used directly by SDKs or by redis client
>```bash
>redis-cli
>127.0.0.1:6379> keys *
>1) "_kombu.binding.celery"
>127.0.0.1:6379>
>```
{: .prompt-tip}

#### Important beginner mistake

Never expose Redis directly to internet like:

```
0.0.0.0:6379
```

Thousands of Redis servers get hacked because of this.  

Default safe setting in `redis.conf`:

```
bind 127.0.0.1
```

#### Does Redis have users/passwords?

By default Redis is VERY open.  

Default configuration:

- No password
- No authentication
- No user system
- Runs on port 6379

So if exposed publicly, anyone can access it.  

This is why Redis is usually:

- bound to localhost
- used inside private networks

Redis authentication (basic password)
    You can add a password in the config file:
    /etc/redis/redis.conf
    Find:
    `#requirepass foobared`
    Change to:
    requirepass myStrongPassword


#### Modern Redis user system (ACL)

New Redis versions support ACLs (Access Control Lists).  

Example:

```bash
ACL SETUSER appuser on >password123 ~* +@all
```

Meaning:

- user: appuser
- password: password123
- can access all keys
- can run all commands

Then connect:

```bash
redis-cli -u redis://appuser:password123@localhost:6379
```

### How Redis is used in production

Yes — Redis is used heavily in production.  

Examples: Major companies using Redis:

- GitHub
- Twitter
- Pinterest
- Stack Overflow

#### Typical production Redis setup

In production Redis usually has:

1️⃣ **Authentication**  
Password or ACL users.

2️⃣ **Firewall protection**  
Only app servers can access Redis.

3️⃣ **Persistence**  
Redis stores snapshots:  
- RDB  
- AOF

4️⃣ **Replication**  
Master + replicas.

5️⃣ **Clustering**  
Multiple Redis nodes.

#### Typical developer workflow

Run Redis:

```bash
sudo systemctl start redis
```

Check:

```bash
redis-cli ping
```

Output:

```
PONG
```

Now you can run commands:

```bash
SET name "john"
GET name
```

### Network Cost vs Database Cost (does calling redis adds NW overhead)

At first glance it seems:

> "Network call to Redis might be slower than reading memory"

True, but compare real latencies.

| Operation          | Approx Latency      |
|-------------------|------------------|
| Python dictionary  | ~50 nanoseconds   |
| Redis lookup       | ~0.2 – 1 ms      |
| Database query     | 5 – 100 ms       |

So even with network overhead:

Redis is still ~20–50x faster than database queries.

This is why caching dramatically improves performance.

### Redis as a Shared Cache

Redis acts as shared memory for all servers.

```
        Load Balancer
        /    |    \
    App1   App2   App3
            |
          Redis
            |
         Database
```

**Flow:**

```
Request → App2
        → Redis GET user:123
        → Cache hit → return result
```

If cache miss:

```
Request → App1
        → Redis GET user:123
        → MISS
        → Query DB
        → Redis SET user:123
```

Now all servers benefit.
