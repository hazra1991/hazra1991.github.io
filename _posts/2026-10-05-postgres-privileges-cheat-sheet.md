---
layout: post
title: "PostgreSQL Privileges: How Access Works, and a Cheat Sheet"
date: 2026-10-05
description: "Why a PostgreSQL user can connect but gets 'permission denied', the three doors every query passes (database, schema, table), a tested setup for an application user, the traps (default privileges, sequences, PUBLIC), a read-only role recipe, and a GRANT cheat sheet."
categories: [Databases, PostgreSQL]
tags: [postgresql, privileges, security, cheatsheet]
---

Everyone meets this one. You create a user, you grant it "all privileges", the app connects, and then:

```
ERROR:  permission denied for table orders
```

The fix isn't another `GRANT ALL`. PostgreSQL checks **several separate doors**, and each has its own key. Once you see the doors, you can set up any user in a minute, and debug any "permission denied" quickly.

> **What we'll cover**
> 1. [The three doors](#doors)
> 2. [Who is who: roles, owners, PUBLIC](#roles)
> 3. [Setting up an application user](#app-user), step by step, and what each step really does
> 4. [Traps that surprise people](#traps)
> 5. [A read-only role](#readonly)
> 6. [Looking at what you have](#inspect)
> 7. [Cheat sheet](#cheat-sheet)
{: .prompt-info}

*(Everything here was run on PostgreSQL 17. This post continues the [PostgreSQL starter kit]({{ site.posts | where: "slug", "postgres-starterkit-and-info" | first.url | relative_url }}).)*

---

## **The three doors** {#doors}

To read one row from `orders`, a user passes three checks in order:

```
database  ──►  schema  ──►  table (and its sequences)
CONNECT        USAGE        SELECT / INSERT / UPDATE / DELETE
```

| Door | Question | Privilege |
|---|---|---|
| **Database** | May this user connect to the database? | `CONNECT` |
| **Schema** | May it look inside the schema (usually `public`)? | `USAGE` (and `CREATE` to make tables) |
| **Table** | May it touch the rows? | `SELECT`, `INSERT`, `UPDATE`, `DELETE` … |

Miss one and you get "permission denied", and the message names the door that stopped you (`for database`, `for schema public`, `for table orders`). That makes the error useful: **read which object it names**.

---

## **Who is who: roles, owners, PUBLIC** {#roles}

- **Role.** In PostgreSQL a "user" is just a role that can log in. `CREATE USER` is `CREATE ROLE ... LOGIN`. Roles can also be groups: you grant a role *to* another role.
- **Owner.** Whoever creates an object owns it, and the owner can do everything to it without any `GRANT`. That is why an app user that runs its own migrations rarely needs table grants.
- **`PUBLIC`.** A built-in pseudo-role meaning "everyone". By default it can `CONNECT` to every database. I checked: a brand-new user with no grants connected to my app database straight away.

---

## **Setting up an application user** {#app-user}

The classic script, with what each step is really for:

```sql
CREATE DATABASE myapp_db;
CREATE USER myapp_user WITH PASSWORD 'change_me';

\c myapp_db

GRANT CONNECT ON DATABASE myapp_db TO myapp_user;                -- door 1
GRANT USAGE, CREATE ON SCHEMA public TO myapp_user;              -- door 2
ALTER SCHEMA public OWNER TO myapp_user;                         -- owner of the schema

GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA public TO myapp_user;   -- door 3, existing tables
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO myapp_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES    TO myapp_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO myapp_user;
```

It works: after it, `myapp_user` creates tables and inserts rows. But several lines are doing less than they look like:

| Step | What I found |
|---|---|
| `GRANT CONNECT` | Changes nothing by itself, because `PUBLIC` could already connect. It only matters after you lock `PUBLIC` out (see [traps](#traps)). |
| `GRANT USAGE, CREATE ON SCHEMA` | Redundant once the user **owns** the schema (next line). |
| `GRANT ALL ON ALL TABLES` | Only affects tables that **already exist** and belong to someone else. Tables the app creates itself are already its own. |
| `ALTER DEFAULT PRIVILEGES` | Applies to objects created **by the role that ran the command**, here `postgres`, not `myapp_user`. `\ddp` shows `Owner: postgres`. |

That last one is the subtle part. Default privileges answer: *"when role X creates a table in the future, who gets what?"* If you run it as the admin, it covers tables the **admin** creates later, which is useful if an admin also creates tables the app must read. For tables the app creates itself, it does nothing. To target another creator, name it: `ALTER DEFAULT PRIVILEGES FOR ROLE some_role ...`.

### **The simpler version** {#simple}

If this database exists for one app, make the app user the **owner** and skip most of the above:

```sql
CREATE USER myapp_user WITH PASSWORD 'change_me';
CREATE DATABASE myapp_db OWNER myapp_user;
```

The owner can create schemas and tables, and run migrations. Then lock the door for everyone else:

```sql
REVOKE CONNECT ON DATABASE myapp_db FROM PUBLIC;
```

I verified the effect: another user then gets `FATAL: User does not have CONNECT privilege`, while a user with its own `CONNECT` grant still connects. The owner is never locked out of its own database.

> Since PostgreSQL 15 the `public` schema no longer lets everyone create tables. On a fresh PG 17 database, a user without grants got `permission denied for schema public` on `CREATE TABLE`. On PG 14 and older, every user could. That's why scripts written years ago contain schema grants.
{: .prompt-tip}

---

## **Traps that surprise people** {#traps}

### **1. `GRANT ALL ON DATABASE` does not give table access** {#trap-all}

```sql
GRANT ALL PRIVILEGES ON DATABASE myapp_db TO other_user;
```

I ran this, then `SELECT * FROM orders` as that user: still `permission denied for table orders`. On a **database**, "all" means just `CREATE`, `CONNECT` and `TEMPORARY`. Privileges don't flow downward. Every object type needs its own grant.

### **2. Inserting into a `serial` table needs the sequence too** {#trap-seq}

A table with `id serial` (or an identity column) has a hidden sequence. With only `GRANT INSERT ON table`, the insert fails:

```
ERROR:  permission denied for sequence seqt_id_seq
```

Add `GRANT USAGE ON SEQUENCE seqt_id_seq TO writer;` and it works. That's why scripts grant on `ALL SEQUENCES` too.

### **3. `RETURNING` needs `SELECT`** {#trap-returning}

With `INSERT` and sequence rights, a plain insert worked, but `INSERT ... RETURNING id` failed with `permission denied for table`. Returning the row is also *reading* it.

### **4. Column-level grants exist** {#trap-column}

```sql
GRANT SELECT (id) ON seqt TO writer;
```

`SELECT id` worked, `SELECT v` was denied. Useful for hiding sensitive columns.

### **5. You can't drop a role that still has privileges** {#trap-drop}

```
ERROR:  role "writer" cannot be dropped because some objects depend on it
```

It lists the grants. Remove them, then drop:

```sql
DROP OWNED BY writer;     -- removes its grants (and drops objects it owns!)
DROP ROLE writer;
```

If it owns data you want to keep, hand it over first: `REASSIGN OWNED BY writer TO newowner;`.

---

## **A read-only role** {#readonly}

A common need: reports, dashboards, an analyst. Make a **group role** with read rights, then grant it to people:

```sql
CREATE ROLE readonly NOLOGIN;
GRANT CONNECT ON DATABASE myapp_db TO readonly;
GRANT USAGE   ON SCHEMA public       TO readonly;
GRANT SELECT  ON ALL TABLES IN SCHEMA public TO readonly;                     -- existing tables

-- tables the app creates LATER (note FOR ROLE: the creator is the app user)
ALTER DEFAULT PRIVILEGES FOR ROLE myapp_user IN SCHEMA public
    GRANT SELECT ON TABLES TO readonly;

GRANT readonly TO analyst;       -- analyst is a normal login role
```

I tested both halves: a table created before the grant and one created by `myapp_user` afterwards were both readable by the analyst, while an `INSERT` was denied.

Since PostgreSQL 14 there's a shortcut for the same job across the whole database:

```sql
GRANT pg_read_all_data TO analyst;      -- read every table, view and sequence
```

(`pg_write_all_data` is the matching write role.) It's broad, so use it for auditors and admins, not for apps.

---

## **Looking at what you have** {#inspect}

```text
\l                    databases and their privileges
\du                   roles
\dn+                  schemas, owners and privileges
\dp orders            table privileges (and column privileges)
\ddp                  default privileges (who they apply to)
```

Reading the access column of `\dp`:

```
myapp_user=arwdDxtm/myapp_user      ← grantee = privileges / granted by
readonly=r/myapp_user
```

The letters: `r` read (SELECT), `a` append (INSERT), `w` write (UPDATE), `d` DELETE, `D` TRUNCATE, `x` REFERENCES, `t` TRIGGER, `m` MAINTAIN (PG 17), `U` USAGE, `C` CREATE or CONNECT depending on object type (`c` is CONNECT on a database), `T` TEMPORARY.

To ask a direct question:

```sql
SELECT has_table_privilege('analyst', 'orders', 'SELECT');          -- t / f
SELECT has_column_privilege('writer', 'seqt', 'v', 'SELECT');
SELECT has_database_privilege('analyst', 'myapp_db', 'CONNECT');
```

---

## **Cheat sheet** {#cheat-sheet}

### **Which privilege on which object**

| Object | Privileges |
|---|---|
| Database | `CONNECT`, `CREATE` (make schemas), `TEMPORARY` |
| Schema | `USAGE`, `CREATE` |
| Table / view | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER` |
| Sequence | `USAGE` (nextval), `SELECT` (read value), `UPDATE` (setval) |
| Column | `SELECT`, `INSERT`, `UPDATE`, `REFERENCES` |
| Function | `EXECUTE` |

### **Granting and revoking**

```sql
GRANT  CONNECT ON DATABASE db TO role;
GRANT  USAGE ON SCHEMA public TO role;
GRANT  SELECT, INSERT, UPDATE, DELETE ON TABLE t TO role;
GRANT  SELECT ON ALL TABLES IN SCHEMA public TO role;        -- existing tables only
GRANT  USAGE ON ALL SEQUENCES IN SCHEMA public TO role;
GRANT  SELECT (col) ON t TO role;                            -- column level
GRANT  role_a TO role_b;                                     -- membership (group role)
GRANT  ... TO role WITH GRANT OPTION;                        -- let them pass it on

REVOKE INSERT ON t FROM role;
REVOKE CONNECT ON DATABASE db FROM PUBLIC;                   -- lock out the world
```

### **Future tables**

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE creator IN SCHEMA public
    GRANT SELECT ON TABLES TO role;
```

### **Ownership and cleanup**

```sql
CREATE DATABASE db OWNER role;
ALTER  DATABASE db OWNER TO role;
ALTER  TABLE t OWNER TO role;
REASSIGN OWNED BY old_role TO new_role;
DROP   OWNED BY old_role;
DROP   ROLE old_role;
```

### **"Permission denied": which door?**

| Message says | Missing |
|---|---|
| `for database "x"` / `no CONNECT privilege` | `GRANT CONNECT ON DATABASE` (or `PUBLIC` was revoked) |
| `for schema public` | `GRANT USAGE` (read) or `CREATE` (make tables) on the schema |
| `for table x` | table grant (`SELECT`, `INSERT`…); for `RETURNING` also `SELECT` |
| `for sequence x_id_seq` | `GRANT USAGE ON SEQUENCE` |
| `must be owner of table x` | `ALTER`/`DROP` need ownership, not just grants |
| `FATAL: password authentication failed` | not privileges at all: password, or `pg_hba.conf` |

---

## **Summary** {#summary}

- A query passes **three doors**: database (`CONNECT`), schema (`USAGE`), table (`SELECT`…, plus the sequence for serial columns). Each needs its own grant, and the error message names the failing one.
- **Owners** need no grants. For a single-app database, `CREATE DATABASE … OWNER app_user` is the simplest setup.
- **`PUBLIC`** can connect by default; revoke it when you want a database locked down.
- `GRANT ALL ON DATABASE` does **not** reach the tables, and `ALTER DEFAULT PRIVILEGES` only covers objects made by the role it names (default: the one running it).
- For read access, use a **group role** (`readonly`) plus `ALTER DEFAULT PRIVILEGES FOR ROLE …`, or `pg_read_all_data` for broad read.
