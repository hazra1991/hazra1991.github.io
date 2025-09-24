---
layout: post  
title: "PostgreSQL Starter Kit & Installation Guide"
date: 2025-09-23
categories: ['Tutorial', 'Database']
tags: ['postgresql', 'database', 'setup', 'installation']
slug: postgres-starterkit-and-info
---

<details>
<summary><strong>📑 Table of Contents</strong></summary>
    
<div markdown="1">
1. [PostgreSQL Installation and working overview in Ubuntu](#postgresql-installation-and-working-overview-in-ubuntu)
2. [Install PostgreSQL and contrib](#install-postgresql-and-contrib)
3. [Why install postgresql-contrib? (optional, but often helpful)](#why-install-postgresql-contrib-optional-but-often-helpful)
4. [Understanding PostgreSQL Users](#understanding-postgresql-users)
5. [What Is the `postgres` System User, and Can You Change It?](#what-is-the-postgres-system-user-and-can-you-change-it)
6. [Does PostgreSQL have a password?](#does-postgresql-have-a-password)
7. [Production level PostgreSQL Security Essentials](#production-level-postgresql-security-essentials)
8. [Additional Information](#additional-information)
9. [What is `pg_hba.conf`?](#what-is-pg_hbaconf)
10. [What does this mean in practice?](#what-does-this-mean-in-practice)
11. [Does this affect shell access or system users?](#does-this-affect-shell-access-or-system-users)
12. [What about the `postgres` user?](#what-about-the-postgres-user)
13. [Connect from Remote Client](#connect-from-remote-client)
14. [PostgreSQL Command Cheat Sheet (via `psql`)](#cheetsheet)
    - [Meta-Commands in `psql` (start with a backslash `\`)](#meta-commands)
    - [SQL Commands (Standard SQL)](#sql-commands)
    - [Viewing Information](#viewing-info)
15. [Export and Import Data](#export-import)
16. [Bonus: Quick DB Inspection Script](#bonus)

</div>
</details>

### PostgreSQL Installation and working overview in Ubuntu

```bash
sudo apt update

sudo apt install postgresql postgresql-contrib

sudo -i -u postgres
psql
```
```sql
CREATE DATABASE myappdb;
CREATE USER myappuser WITH PASSWORD 'Very$trongP@ssw0rd';
GRANT ALL PRIVILEGES ON DATABASE myappdb TO myappuser;
\q
```
> The above and other are explained below.

## Install PostgreSQL and contrib

```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
```

##### Why install postgresql-contrib? (optional, but often helpful)

The `postgresql-contrib` package provides additional useful extensions for PostgreSQL. **Examples include:**

- `uuid-ossp`: Generates UUIDs for unique IDs  
- `pg_stat_statements`: Monitors and logs slow queries  
- `hstore`: Enables key-value storage in a single column  
- `citext`: Supports case-insensitive text

## Understanding PostgreSQL Users 

>`sudo -i -u postgres` When you install PostgreSQL on Ubuntu: `sudo -i`: runs a login shell and `-u postgres`: switches to the `postgres`
>- A user named `postgres` is created which is the system-level administrator of the PostgreSQL server
>Once you're in the `postgres` shell, you can run: `psql`
{: .prompt-info}

**🔑 Two types of users in PostgreSQL setup:**

1. **System User (Linux)**

    - **Examples:** `postgres`, `abhishek`, `ubuntu`
    - Manages PostgreSQL service at the OS level (who can access the service).

2. **PostgreSQL User (Role)**

    - Created *inside* PostgreSQL (e.g., `myappuser`, `readonlyuser`)
        * example `CREATE USER myuser WITH PASSWORD 'mypassword';` inside the db
    - Used to connect to databases, run queries, and own objects.

#### What Is the `postgres` System User, and Can You Change It?

**`postgres` is the default **system-level PostgreSQL admin user**, just like `root` for Linux.**

⚠️ can you change it ? Yes, technically — but in production, no one does this. but Why not?

- `postgres` is the default and **system-level admin user**.
- It is managed by the PostgreSQL installation and used **only for server administration**, not for apps.
- Changing or deleting it can **break things**.

🟡 Instead, in production, we use the `postgres` user *once* to

- Create a database  
- Create custom DB users  

...then **never use it again**

#### Does PostgreSQL have a password?

**Yes** — but only for **database users (roles)**.

🔐 By default:

- The **system user** `postgres` can access the DB **without a password** using **Unix socket authentication**  
  (aka **peer auth** in `pg_hba.conf`)
- But **any remote or non-system users** **must have passwords** to connect.

## Production level PostgreSQL Security Essentials

🔐 1. Avoid `postgres` user in apps

- Never use the default `postgres` user in your Django (or any app's) settings.
- Always create an **app-specific DB user** with **limited privileges**.

🔐 2. Enable SSL (in production)

When running on a remote server, ensure PostgreSQL connections are encrypted using **SSL**.

In your `settings.py`, add:

```python
OPTIONS = {
    'sslmode': 'require',
}
```

🔐 3. Secure `pg_hba.conf`

This file controls who can connect to PostgreSQL and how.

**Default location:**

`/etc/postgresql/<version>/main/pg_hba.conf`

Example secure rule:

```bash
# TYPE  DATABASE        USER            ADDRESS                 METHOD
host    mydb            myuser          192.168.1.0/24          scram-sha-256
```

This allows myuser to connect to mydb from a trusted subnet using secure password hashing.
After editing, reload PostgreSQL: `sudo systemctl reload postgresql`

🔐 6. Don’t Expose PostgreSQL Publicly

- By default, PostgreSQL only listens on localhost — that's good.
- Don’t bind it to 0.0.0.0 unless behind a firewall.
- Use SSH tunneling or private network access if remote access is needed.


## Additional Information

### What is `pg_hba.conf`?

- **`pg_hba.conf`** stands for **PostgreSQL Host-Based Authentication configuration**.
- It controls who can connect, from where, to which database, as which PostgreSQL user, and how they authenticate.
- This is server-level access control for **PostgreSQL connections**.

**Breakdown of a `pg_hba.conf` Rule**

```bash
# TYPE  DATABASE    USER      ADDRESS         METHOD
host    mydb        myuser    192.168.1.0/24  scram-sha-256
```

| Field             | What it means                                     |
|-------------------|--------------------------------------------------|
| `host`            | Connection type — here, TCP/IP host connection   |
| `mydb`            | Database name user is allowed to connect to      |
| `myuser`          | PostgreSQL database user/role allowed to connect |
| `192.168.1.0/24`  | Allowed client IP address range (subnet)         |
| `scram-sha-256`   | Authentication method required (password hashing)|


#### What does this mean in practice?

- Only the user `myuser` can connect to the database named `mydb`.
- Connections must come from an IP within the `192.168.1.0` subnet.
- `myuser` must authenticate with a password hashed using `scram-sha-256`.
- Other users or IPs trying to connect to `mydb` will be denied unless allowed by other rules.
- Users cannot connect to any other database unless rules allow it.

---

#### Does this affect shell access or system users?

- No, it does **NOT** affect Linux system users.
- It controls **PostgreSQL database user connections (roles)**.
- Whether you connect via `psql` locally or remotely, PostgreSQL checks this file to see if your connection is allowed.

---

#### What about the `postgres` user?

- If there's no specific rule allowing the `postgres` user to connect from outside localhost, remote connections as `postgres` will be denied.
- This is often done deliberately for security.

## Connect from Remote Client

On the client machine (could be your laptop or another server), install psql or use a PostgreSQL client.

Example with psql:

```bash
psql -h <server_ip> -U <db_user> -d <db_name>

# Example:

psql -h 203.0.113.20 -U myuser -d mydb
```

## PostgreSQL Command Cheat Sheet (via `psql`) {#cheetsheet}

```bash
sudo -u postgres psql
# Or, if you're using a specific DB/user:
psql -U myuser -d mydb
```

##### 📋 Meta-Commands in `psql` (start with a backslash `\`) {#meta-commands}

These are **not SQL**, they are **`psql`-specific** commands to inspect the database.

| Command         | Meaning                                               |
|----------------|--------------------------------------------------------|
| `\l` or `\list` | List all databases                                     |
| `\c dbname`     | Connect to a database                                  |
| `\dt`           | List all tables in the current schema                  |
| `\d tablename`  | Describe a table (columns, types, constraints)         |
| `\du`           | List users and their roles                             |
| `\dn`           | List all schemas                                       |
| `\df`           | List functions                                         |
| `\dv`           | List views                                             |
| `\x`            | Toggle expanded output (like vertical mode)           |
| `\q`            | Quit `psql`                                            |
| `\?`            | Show help for `psql` commands                          |
| `\h`            | SQL syntax help (e.g., `\h CREATE TABLE`)              |
| `\?`            | Show psql command help              |

---

##### 🗄️ SQL Commands (Standard SQL) {#sql-commands}

You can run these inside `psql` or in SQL scripts.

🔧 Database Management

| Command                          | Purpose                   |
|----------------------------------|---------------------------|
| `CREATE DATABASE mydb;`          | Create a new database     |
| `DROP DATABASE mydb;`            | Delete a database         |
| `\c mydb`                        | Switch to a database      |
| `\conninfo`                      | Show current connection info |

---

👤 User / Role Management

| Command                                                     | Purpose                     |
|-------------------------------------------------------------|-----------------------------|
| `CREATE USER myuser WITH PASSWORD 'mypassword';`            | Create a new user           |
| `DROP USER myuser;`                                         | Delete a user               |
| `ALTER USER myuser WITH PASSWORD 'newpass';`                | Change a user's password    |
| `GRANT ALL PRIVILEGES ON DATABASE mydb TO myuser;`          | Grant access to a DB        |
| `REVOKE ALL PRIVILEGES ON DATABASE mydb FROM myuser;`       | Remove access               |

---

📦 Table Management

| Command                                      | Purpose             |
|----------------------------------------------|---------------------|
| `CREATE TABLE mytable (...);`                | Create a new table  |
| `DROP TABLE mytable;`                        | Delete a table      |
| `ALTER TABLE mytable ADD COLUMN newcol TYPE;`| Add a column        |
| `SELECT * FROM mytable;`                     | Show all data       |
| `\d mytable`                                 | Describe table      |

---

##### 🔍 Viewing Information {#viewing-info}

| Task                    | Command                                  |
|-------------------------|------------------------------------------|
| List all databases      | `\l`                                     |
| List all tables         | `\dt`                                    |
| Show table schema       | `\d tablename`                           |
| Show current user       | `SELECT current_user;` or `\conninfo`    |
| Show privileges         | `\z` or `\dp`                            |
| Show running queries    | `SELECT * FROM pg_stat_activity;`        |


### ⚡ Export and Import Data {#export-import}

**Export a table to CSV:**

```sql
\COPY mytable TO '/tmp/mytable.csv' WITH CSV HEADER;
```
**Import from CSV:**

```sql
\COPY mytable FROM '/tmp/mytable.csv' WITH CSV HEADER;
```

#### 🧪 Bonus: Quick DB Inspection Script {#bonus}
Run this in psql for a quick look at table sizes:

```sql
SELECT relname AS table, 
       pg_size_pretty(pg_total_relation_size(relid)) AS size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```